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
        app.setActivationPolicy(.regular)
        app.delegate = shared
        app.run()
    }

    public func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        setupPopover()

        AppUpdate.restoreBadge()
        AppUpdate.checkOnLaunch()

        // Open the main mixer window on launch
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            self?.showMixerWindow()
        }
    }

    public func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showMixerWindow()
        return true
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.target = self
            button.action = #selector(handleStatusItemClick(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            updateMenuBarButton()
        }
    }

    public func updateMenuBarButton() {
        guard let button = statusItem?.button else { return }

        let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .bold)
        let symbolName = "speaker.wave.3.fill"
        if let sfImage = NSImage(systemSymbolName: symbolName, accessibilityDescription: "Show Sound")?.withSymbolConfiguration(config) {
            sfImage.isTemplate = true
            button.image = sfImage
            button.imagePosition = .imageLeft
        } else {
            button.title = "🔊"
        }

        let boost = Int(MixerModel.shared.masterBoost * 100)
        button.title = (boost > 100) ? " \(boost)%" : ""
        button.toolTip = availableUpdateVersion.map { "Show Sound — Update \($0) is ready" } ?? "Show Sound (SafeBoost: \(boost)%)"
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
            contentRect: NSRect(x: 0, y: 0, width: 390, height: 600),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Show Sound"
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
        popover.contentSize = NSSize(width: 390, height: 580)
        popover.behavior = .transient
        popover.animates = true
        popover.contentViewController = NSHostingController(rootView: MixerView())
    }

    @objc private func handleStatusItemClick(_ sender: AnyObject?) {
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
