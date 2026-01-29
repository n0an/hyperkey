import Foundation
import CoreGraphics
import AppKit
import IOKit
import IOKit.hid
import os.log

private let logger = Logger(subsystem: "com.antonnovoselov.HyperKey", category: "KeyEventManager")

class KeyEventManager {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var hidManager: IOHIDManager?
    private var capsLockPressed = false

    private let hyperModifiers: CGEventFlags = [.maskCommand, .maskControl, .maskAlternate, .maskShift]

    func start() {
        guard eventTap == nil else { return }

        // Set up event tap for intercepting key events
        let eventMask = (1 << CGEventType.flagsChanged.rawValue) |
                        (1 << CGEventType.keyDown.rawValue) |
                        (1 << CGEventType.keyUp.rawValue)

        let callback: CGEventTapCallBack = { proxy, type, event, refcon in
            guard let refcon = refcon else { return Unmanaged.passRetained(event) }
            let manager = Unmanaged<KeyEventManager>.fromOpaque(refcon).takeUnretainedValue()
            return manager.handleEvent(proxy: proxy, type: type, event: event)
        }

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            logger.error("Failed to create event tap. Please check accessibility permissions.")
            promptForAccessibility()
            return
        }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        // Set up IOKit HID manager to detect physical key press/release
        setupHIDManager()

        logger.info("HyperKey event tap started successfully")
    }

    func stop() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            if let source = runLoopSource {
                CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
            }
            eventTap = nil
            runLoopSource = nil
        }

        if let manager = hidManager {
            IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
            hidManager = nil
        }

        capsLockPressed = false
        logger.info("HyperKey event tap stopped")
    }

    private func setupHIDManager() {
        hidManager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        guard let manager = hidManager else {
            logger.error("Failed to create HID manager")
            return
        }

        // Match keyboard devices
        let matchingDict: [String: Any] = [
            kIOHIDDeviceUsagePageKey: kHIDPage_GenericDesktop,
            kIOHIDDeviceUsageKey: kHIDUsage_GD_Keyboard
        ]
        IOHIDManagerSetDeviceMatching(manager, matchingDict as CFDictionary)

        // Set up callback for HID input values
        let context = Unmanaged.passUnretained(self).toOpaque()
        IOHIDManagerRegisterInputValueCallback(manager, { context, result, sender, value in
            guard let context = context else { return }
            let manager = Unmanaged<KeyEventManager>.fromOpaque(context).takeUnretainedValue()
            manager.handleHIDValue(value)
        }, context)

        IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetCurrent(), CFRunLoopMode.commonModes.rawValue)
        IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))

        logger.info("HID manager set up successfully")
    }

    private func handleHIDValue(_ value: IOHIDValue) {
        let element = IOHIDValueGetElement(value)
        let usagePage = IOHIDElementGetUsagePage(element)
        let usage = IOHIDElementGetUsage(element)

        // Check if this is Caps Lock (Usage Page 7 = Keyboard, Usage 57 = Caps Lock)
        // Actually Caps Lock in HID is usage 0x39 (57 decimal) on usage page 0x07
        guard usagePage == kHIDPage_KeyboardOrKeypad && usage == 0x39 else { return }

        let pressed = IOHIDValueGetIntegerValue(value)

        DispatchQueue.main.async { [weak self] in
            if pressed != 0 {
                self?.capsLockDidPress()
            } else {
                self?.capsLockDidRelease()
            }
        }
    }

    private func capsLockDidPress() {
        guard !capsLockPressed else { return }

        logger.debug("Caps Lock PRESSED (HID) - activating Hyper mode")
        capsLockPressed = true
        postHyperModifiers(down: true)
    }

    private func capsLockDidRelease() {
        guard capsLockPressed else { return }

        logger.debug("Caps Lock RELEASED (HID) - deactivating Hyper mode")
        capsLockPressed = false
        postHyperModifiers(down: false)
    }

    private func handleEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            logger.warning("Event tap was disabled, re-enabling...")
            if let tap = eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return Unmanaged.passRetained(event)
        }

        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)

        // Caps Lock key code is 57 - suppress it to prevent LED toggle
        if type == .flagsChanged && keyCode == 57 {
            logger.debug("Suppressing Caps Lock event to prevent LED toggle")
            return nil
        }

        // Add hyper modifiers to key events while Caps Lock is held
        if capsLockPressed && type == .keyDown {
            logger.debug("Key pressed while Caps Lock held (keyCode: \(keyCode))")
            var newFlags = event.flags
            newFlags.insert(hyperModifiers)
            event.flags = newFlags
        }

        return Unmanaged.passRetained(event)
    }

    private func postHyperModifiers(down: Bool) {
        guard let source = CGEventSource(stateID: .hidSystemState) else { return }

        var flags: CGEventFlags = []
        if down {
            flags = hyperModifiers
        }

        if let event = CGEvent(source: source) {
            event.type = .flagsChanged
            event.flags = flags
            event.post(tap: .cgSessionEventTap)
        }
    }

    private func promptForAccessibility() {
        DispatchQueue.main.async {
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
            AXIsProcessTrustedWithOptions(options as CFDictionary)
        }
    }
}
