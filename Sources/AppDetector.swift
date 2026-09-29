import Foundation
import AppKit
import Combine

public struct DiscoveredAudioApp: Identifiable, Equatable {
    public let id: String // bundleIdentifier or process name
    public let name: String
    public let icon: NSImage?
    public var volume: Float        // 0.0 to 2.0 (0% to 200%)
    public var pan: Float           // -1.0 (Left) to 1.0 (Right)
    public var isMuted: Bool
    public var isSharedToCall: Bool
    public var isRunning: Bool
    
    public init(
        id: String,
        name: String,
        icon: NSImage? = nil,
        volume: Float = 1.0,
        pan: Float = 0.0,
        isMuted: Bool = false,
        isSharedToCall: Bool = false,
        isRunning: Bool = true
    ) {
        self.id = id
        self.name = name
        self.icon = icon
        self.volume = volume
        self.pan = pan
        self.isMuted = isMuted
        self.isSharedToCall = isSharedToCall
        self.isRunning = isRunning
    }
}

public final class AppDetector: ObservableObject {
    public static let shared = AppDetector()
    
    @Published public private(set) var apps: [DiscoveredAudioApp] = []
    
    // Known media and communication bundle identifier prefixes or names
    private let knownAudioBundleIDs: Set<String> = [
        "com.spotify.client",
        "com.apple.Music",
        "com.google.Chrome",
        "com.apple.Safari",
        "net.whatsapp.WhatsApp",
        "us.zoom.xos",
        "com.tinyspeck.slackmacgap",
        "com.hnc.Discord",
        "company.thebrowser.Browser", // Arc
        "ru.keepcoder.Telegram",
        "com.brave.Browser",
        "org.mozilla.firefox",
        "com.microsoft.teams2",
        "com.apple.FaceTime",
        "com.apple.podcasts",
        "org.videolan.vlc",
        "com.colliderli.iina"
    ]
    
    // Store saved user preferences (volume, pan, call-share) by bundle ID
    private var appPreferences: [String: (volume: Float, pan: Float, isMuted: Bool, isSharedToCall: Bool)] = [
        "com.spotify.client": (volume: 1.0, pan: 0.5, isMuted: false, isSharedToCall: true),
        "com.apple.Music": (volume: 1.0, pan: 0.5, isMuted: false, isSharedToCall: true),
        "net.whatsapp.WhatsApp": (volume: 1.0, pan: -0.6, isMuted: false, isSharedToCall: false),
        "us.zoom.xos": (volume: 1.0, pan: -0.5, isMuted: false, isSharedToCall: false)
    ]
    
    private var cancellables = Set<AnyCancellable>()
    
    public init() {
        refreshRunningApps()
        setupWorkspaceObservers()
    }
    
    public func refreshRunningApps() {
        let runningApps = NSWorkspace.shared.runningApplications
        var detected: [DiscoveredAudioApp] = []
        
        for app in runningApps where app.activationPolicy == .regular {
            guard let bundleID = app.bundleIdentifier else { continue }
            let name = app.localizedName ?? bundleID
            
            // Check if it's a known audio/media app or matches common audio keywords
            let lowerBid = bundleID.lowercased()
            let lowerName = name.lowercased()
            let isMedia = knownAudioBundleIDs.contains(bundleID)
                || lowerBid.contains("music")
                || lowerBid.contains("audio")
                || lowerBid.contains("sound")
                || lowerBid.contains("player")
                || lowerBid.contains("browser")
                || lowerBid.contains("chrome")
                || lowerBid.contains("call")
                || lowerBid.contains("chat")
                || lowerName.contains("spotify")
                || lowerName.contains("chrome")
                || lowerName.contains("safari")
                || lowerName.contains("whatsapp")
                || lowerName.contains("zoom")
                || lowerName.contains("slack")
                || lowerName.contains("discord")
                || lowerName.contains("telegram")
            
            if isMedia {
                let saved = appPreferences[bundleID]
                let vol = saved?.volume ?? 1.0
                let pan = saved?.pan ?? 0.0
                let muted = saved?.isMuted ?? false
                let call = saved?.isSharedToCall ?? false
                
                detected.append(
                    DiscoveredAudioApp(
                        id: bundleID,
                        name: name,
                        icon: app.icon,
                        volume: vol,
                        pan: pan,
                        isMuted: muted,
                        isSharedToCall: call,
                        isRunning: true
                    )
                )
            }
        }
        
        // If empty (e.g. fresh environment), include standard defaults
        if detected.isEmpty {
            detected = [
                DiscoveredAudioApp(id: "com.spotify.client", name: "Spotify", icon: nil, volume: 1.0, pan: 0.5, isSharedToCall: true),
                DiscoveredAudioApp(id: "com.google.Chrome", name: "Google Chrome", icon: nil, volume: 1.2, pan: 0.0, isSharedToCall: false),
                DiscoveredAudioApp(id: "net.whatsapp.WhatsApp", name: "WhatsApp", icon: nil, volume: 1.0, pan: -0.6, isSharedToCall: false),
                DiscoveredAudioApp(id: "com.apple.Safari", name: "Safari", icon: nil, volume: 0.8, pan: 0.0, isSharedToCall: false)
            ]
        }
        
        DispatchQueue.main.async {
            self.apps = detected
        }
    }
    
    public func setVolume(for id: String, volume: Float) {
        if let idx = apps.firstIndex(where: { $0.id == id }) {
            apps[idx].volume = volume
            savePreference(for: id, volume: volume, pan: apps[idx].pan, isMuted: apps[idx].isMuted, isSharedToCall: apps[idx].isSharedToCall)
            SystemAudioController.shared.setAppVolume(bundleID: id, volume: volume)
        }
    }
    
    public func setPan(for id: String, pan: Float) {
        if let idx = apps.firstIndex(where: { $0.id == id }) {
            apps[idx].pan = pan
            savePreference(for: id, volume: apps[idx].volume, pan: pan, isMuted: apps[idx].isMuted, isSharedToCall: apps[idx].isSharedToCall)
        }
    }
    
    public func toggleMute(for id: String) {
        if let idx = apps.firstIndex(where: { $0.id == id }) {
            apps[idx].isMuted.toggle()
            let isMuted = apps[idx].isMuted
            savePreference(for: id, volume: apps[idx].volume, pan: apps[idx].pan, isMuted: isMuted, isSharedToCall: apps[idx].isSharedToCall)
            SystemAudioController.shared.setAppMuted(bundleID: id, isMuted: isMuted)
        }
    }
    
    public func toggleCallShare(for id: String) {
        if let idx = apps.firstIndex(where: { $0.id == id }) {
            apps[idx].isSharedToCall.toggle()
            savePreference(for: id, volume: apps[idx].volume, pan: apps[idx].pan, isMuted: apps[idx].isMuted, isSharedToCall: apps[idx].isSharedToCall)
        }
    }
    
    private func savePreference(for id: String, volume: Float, pan: Float, isMuted: Bool, isSharedToCall: Bool) {
        appPreferences[id] = (volume, pan, isMuted, isSharedToCall)
    }
    
    private func setupWorkspaceObservers() {
        let center = NSWorkspace.shared.notificationCenter
        
        center.addObserver(forName: NSWorkspace.didLaunchApplicationNotification, object: nil, queue: .main) { [weak self] _ in
            self?.refreshRunningApps()
        }
        
        center.addObserver(forName: NSWorkspace.didTerminateApplicationNotification, object: nil, queue: .main) { [weak self] _ in
            self?.refreshRunningApps()
        }
    }
}
