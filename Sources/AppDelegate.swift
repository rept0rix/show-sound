import AppKit
import SwiftUI

@main
public final class AppDelegate: NSObject, NSApplicationDelegate {
    public static let shared = AppDelegate()
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var eventMonitor: Any?
    @Published public private(set) var availableUpdateVersion: String? = nil

    public func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.accessory)
        setupStatusItem()
        setupPopover()
        
        AppUpdate.restoreBadge()
        AppUpdate.checkOnLaunch()
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            updateMenuBarButton()
            button.target = self
            button.action = #selector(togglePopover(_:))
        }
    }

    private func updateMenuBarButton() {
        guard let button = statusItem.button else { return }
        let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .medium)
        let symbolName = (availableUpdateVersion != nil) ? "speaker.wave.3.bubble.fill" : "speaker.wave.3.fill"
        if let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: "Show Sound")?.withSymbolConfiguration(config) {
            image.isTemplate = true
            button.image = image
        } else {
            button.title = (availableUpdateVersion != nil) ? "🔊•" : "🔊"
        }
        button.toolTip = availableUpdateVersion.map { "Show Sound — Update \($0) is ready" } ?? "Show Sound"
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

    private func setupPopover() {
        popover = NSPopover()
        popover.contentSize = NSSize(width: 390, height: 580)
        popover.behavior = .transient
        popover.animates = true
        popover.contentViewController = NSHostingController(rootView: MixerView())
    }

    @objc private func togglePopover(_ sender: AnyObject?) {
        guard let button = statusItem.button else { return }

        if popover.isShown {
            popover.performClose(sender)
            removeEventMonitor()
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
            installEventMonitor()
        }
    }

    private func installEventMonitor() {
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            guard let self = self, self.popover.isShown else { return }
            self.popover.performClose(nil)
            self.removeEventMonitor()
        }
    }

    private func removeEventMonitor() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }
}
