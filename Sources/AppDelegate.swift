import AppKit
import SwiftUI

@main
public final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    public static let shared = AppDelegate()
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var mixerWindow: NSWindow?
    private var eventMonitor: Any?
    @Published public private(set) var availableUpdateVersion: String? = nil

    public static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        app.delegate = shared
        app.run()
    }

    public func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        setupPopover()

        AppUpdate.restoreBadge()
        AppUpdate.checkOnLaunch()

        // Clean background launch in Menu Bar — no unsolicited popup window
    }

    public func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        togglePopover(nil)
        return true
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.target = self
            button.action = #selector(handleStatusItemClick(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            updateMenuBarButton()
        }
    }

    public func updateMenuBarButton() {
        guard let button = statusItem?.button else { return }
        let ready = availableUpdateVersion != nil
        button.image = menuBarIcon(updateReady: ready)
        let boost = Int(MixerModel.shared.masterBoost * 100)
        button.toolTip = availableUpdateVersion.map { "Show Sound — Update \($0) is ready" } ?? "Show Sound (SafeBoost: \(boost)%)"
    }

    private func menuBarIcon(updateReady: Bool) -> NSImage? {
        let side: CGFloat = 18
        if let source = NSApp.applicationIconImage.copy() as? NSImage, source.isValid {
            source.size = NSSize(width: side, height: side)
            source.isTemplate = false
            if !updateReady {
                return source
            }
            let canvas = NSImage(size: NSSize(width: side, height: side), flipped: false) { rect in
                source.draw(in: NSRect(x: 0, y: 0, width: side - 2, height: side - 2))
                let ring = NSRect(x: side - 8, y: side - 8, width: 8, height: 8)
                NSColor.white.setFill()
                NSBezierPath(ovalIn: ring).fill()
                NSColor.systemBlue.setFill()
                NSBezierPath(ovalIn: ring.insetBy(dx: 1.0, dy: 1.0)).fill()
                return true
            }
            canvas.isTemplate = false
            return canvas
        }

        let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .bold)
        let symbolName = "speaker.wave.3.fill"
        if let sfImage = NSImage(systemSymbolName: symbolName, accessibilityDescription: "Show Sound")?.withSymbolConfiguration(config) {
            sfImage.isTemplate = true
            return sfImage
        }
        return nil
    }

    public func noteUpdate(_ version: String?) {
        availableUpdateVersion = version
        updateMenuBarButton()
    }

    public func relaunchAfterUpdate() {
        let url = Bundle.main.bundleURL
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(at: url, configuration: configuration) { _, _ in
            DispatchQueue.main.async {
                NSApp.terminate(nil)
            }
        }
    }

    public func showMixerWindow() {
        if let window = mixerWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let host = NSHostingView(rootView: MixerView())
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 440, height: 680),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Show Sound"
        window.appearance = NSAppearance(named: .vibrantDark)
        window.backgroundColor = NSColor(calibratedRed: 0.07, green: 0.08, blue: 0.12, alpha: 1.0)
        window.contentView = host
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.mixerWindow = window
    }

    private func setupPopover() {
        popover = NSPopover()
        popover.appearance = NSAppearance(named: .vibrantDark)
        popover.contentSize = NSSize(width: 440, height: 680)
        popover.behavior = .transient
        popover.animates = true
        popover.contentViewController = NSHostingController(rootView: MixerView())
    }

    @objc private func handleStatusItemClick(_ sender: AnyObject?) {
        guard let event = NSApp.currentEvent else {
            togglePopover(sender)
            return
        }
        if event.type == .rightMouseUp {
            showContextMenu()
        } else {
            togglePopover(sender)
        }
    }

    public func togglePopover(_ sender: AnyObject?) {
        if popover.isShown {
            closePopover(sender)
        } else {
            showPopover()
        }
    }

    public func showPopover() {
        guard let button = statusItem?.button else {
            showMixerWindow()
            return
        }
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
        NSApp.activate(ignoringOtherApps: true)
        installEventMonitor()
    }

    public func closePopover(_ sender: AnyObject?) {
        popover.performClose(sender)
        removeEventMonitor()
    }

    private func showContextMenu() {
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Show Sound", action: nil, keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Open Mixer", action: #selector(toggleFromMenu), keyEquivalent: "m"))
        menu.addItem(NSMenuItem(title: MixerModel.shared.audioController.isMuted ? "Unmute Master" : "Mute Master", action: #selector(toggleMuteFromMenu), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Check for Updates…", action: #selector(checkUpdatesFromMenu), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit Show Sound", action: #selector(quitFromMenu), keyEquivalent: "q"))
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc private func toggleFromMenu() {
        showPopover()
    }

    @objc private func toggleMuteFromMenu() {
        MixerModel.shared.toggleMasterMute()
    }

    @objc private func checkUpdatesFromMenu() {
        AppUpdate.checkManually()
    }

    @objc private func quitFromMenu() {
        NSApp.terminate(nil)
    }

    private func installEventMonitor() {
        removeEventMonitor()
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            guard let self = self, self.popover.isShown else { return }
            self.closePopover(nil)
        }
    }

    private func removeEventMonitor() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }
}
