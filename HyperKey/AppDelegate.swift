import AppKit
import SwiftUI
import ServiceManagement

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var keyEventManager: KeyEventManager!

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        setupKeyEventManager()
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "keyboard", accessibilityDescription: "HyperKey")
        }

        let menu = NSMenu()

        let enabledItem = NSMenuItem(title: "Enabled", action: #selector(toggleEnabled), keyEquivalent: "")
        enabledItem.state = UserDefaults.standard.bool(forKey: "hyperKeyEnabled") ? .on : .off
        menu.addItem(enabledItem)

        menu.addItem(NSMenuItem.separator())

        let capsLockToEscapeItem = NSMenuItem(title: "Caps Lock → Escape (when tapped alone)", action: #selector(toggleCapsLockToEscape), keyEquivalent: "")
        capsLockToEscapeItem.state = UserDefaults.standard.bool(forKey: "capsLockToEscape") ? .on : .off
        menu.addItem(capsLockToEscapeItem)

        menu.addItem(NSMenuItem.separator())

        menu.addItem(NSMenuItem(title: "Check Accessibility...", action: #selector(checkAccessibility), keyEquivalent: ""))

        menu.addItem(NSMenuItem.separator())

        let launchAtLoginItem = NSMenuItem(title: "Launch at Login", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        launchAtLoginItem.state = isLaunchAtLoginEnabled() ? .on : .off
        menu.addItem(launchAtLoginItem)

        menu.addItem(NSMenuItem.separator())

        menu.addItem(NSMenuItem(title: "Quit HyperKey", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        statusItem.menu = menu
    }

    private func setupKeyEventManager() {
        keyEventManager = KeyEventManager()

        if UserDefaults.standard.object(forKey: "hyperKeyEnabled") == nil {
            UserDefaults.standard.set(true, forKey: "hyperKeyEnabled")
        }

        if UserDefaults.standard.bool(forKey: "hyperKeyEnabled") {
            keyEventManager.start()
        }
    }

    @objc private func toggleEnabled(_ sender: NSMenuItem) {
        let newState = sender.state == .off
        sender.state = newState ? .on : .off
        UserDefaults.standard.set(newState, forKey: "hyperKeyEnabled")

        if newState {
            keyEventManager.start()
        } else {
            keyEventManager.stop()
        }
    }

    @objc private func toggleCapsLockToEscape(_ sender: NSMenuItem) {
        let newState = sender.state == .off
        sender.state = newState ? .on : .off
        UserDefaults.standard.set(newState, forKey: "capsLockToEscape")
        keyEventManager.capsLockToEscape = newState
    }

    @objc private func checkAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        let trusted = AXIsProcessTrustedWithOptions(options as CFDictionary)

        if trusted {
            let alert = NSAlert()
            alert.messageText = "Accessibility Enabled"
            alert.informativeText = "HyperKey has accessibility permissions and is ready to use."
            alert.alertStyle = .informational
            alert.runModal()
        }
    }

    @objc private func toggleLaunchAtLogin(_ sender: NSMenuItem) {
        let newState = sender.state == .off

        do {
            if newState {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            sender.state = newState ? .on : .off
        } catch {
            let alert = NSAlert()
            alert.messageText = "Error"
            alert.informativeText = "Failed to update launch at login setting: \(error.localizedDescription)"
            alert.alertStyle = .warning
            alert.runModal()
        }
    }

    private func isLaunchAtLoginEnabled() -> Bool {
        return SMAppService.mainApp.status == .enabled
    }
}
