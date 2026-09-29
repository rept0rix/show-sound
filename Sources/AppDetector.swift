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
    public var isPlaying: Bool
    public var detailText: String?  // e.g. "♫ Track Name • Artist" or "🌐 Tab: YouTube"
    public var outputDestination: String // e.g. "Speakers (Ch 1/2)" or "AirPods Pro"
    public var activityLevelL: Float // 0.0 to 1.0 (Left Channel level)
    public var activityLevelR: Float // 0.0 to 1.0 (Right Channel level)
    
    public init(
        id: String,
        name: String,
        icon: NSImage? = nil,
        volume: Float = 1.0,
        pan: Float = 0.0,
        isMuted: Bool = false,
        isSharedToCall: Bool = false,
        isRunning: Bool = true,
        isPlaying: Bool = false,
        detailText: String? = nil,
        outputDestination: String = "Speakers (Ch 1/2)",
        activityLevelL: Float = 0.0,
        activityLevelR: Float = 0.0
    ) {
        self.id = id
        self.name = name
        self.icon = icon
        self.volume = volume
        self.pan = pan
        self.isMuted = isMuted
        self.isSharedToCall = isSharedToCall
        self.isRunning = isRunning
        self.isPlaying = isPlaying
        self.detailText = detailText
        self.outputDestination = outputDestination
        self.activityLevelL = activityLevelL
        self.activityLevelR = activityLevelR
    }
}

public final class AppDetector: ObservableObject {
    public static let shared = AppDetector()
    
    @Published public private(set) var apps: [DiscoveredAudioApp] = []
    @Published public private(set) var anyAppPlaying: Bool = false
    @Published public private(set) var activeAudioSourceTitle: String = "Stereo Output"
    
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
    
    private var appPreferences: [String: (volume: Float, pan: Float, isMuted: Bool, isSharedToCall: Bool)] = [
        "com.spotify.client": (volume: 1.0, pan: 0.0, isMuted: false, isSharedToCall: true),
        "com.apple.Music": (volume: 1.0, pan: 0.0, isMuted: false, isSharedToCall: true),
        "net.whatsapp.WhatsApp": (volume: 1.0, pan: -0.6, isMuted: false, isSharedToCall: false),
        "us.zoom.xos": (volume: 1.0, pan: -0.5, isMuted: false, isSharedToCall: false)
    ]
    
    private var cancellables = Set<AnyCancellable>()
    private var monitorTimer: Timer?
    private var meterTimer: Timer?
    private let queryQueue = DispatchQueue(label: "com.showsound.appmonitor", qos: .userInitiated)
    
    public init() {
        refreshRunningApps()
        setupWorkspaceObservers()
        startPlaybackPolling()
        startMeterAnimationLoop()
    }
    
    deinit {
        monitorTimer?.invalidate()
        meterTimer?.invalidate()
    }
    
    public func refreshRunningApps() {
        let runningApps = NSWorkspace.shared.runningApplications
        var detected: [DiscoveredAudioApp] = []
        
        let myPID = ProcessInfo.processInfo.processIdentifier
        let myBundleID = Bundle.main.bundleIdentifier ?? "com.showsound.app"
        let currentDevName = AudioDeviceManager.shared.currentDeviceName
        
        for app in runningApps where app.activationPolicy == .regular {
            // Strictly exclude Show Sound itself
            if app.processIdentifier == myPID { continue }
            guard let bundleID = app.bundleIdentifier else { continue }
            if bundleID == myBundleID || bundleID == "com.showsound.app" { continue }
            
            let name = app.localizedName ?? bundleID
            let lowerBid = bundleID.lowercased()
            let lowerName = name.lowercased()
            
            if lowerName.contains("show sound") || lowerName.contains("showsound") || lowerBid.contains("showsound") {
                continue
            }
            
            if bundleID == "com.apple.finder" || bundleID == "com.apple.dock" {
                continue
            }
            
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
                
                let prev = apps.first(where: { $0.id == bundleID })
                let dest = call ? "Call Mic + Output" : currentDevName
                
                detected.append(
                    DiscoveredAudioApp(
                        id: bundleID,
                        name: name,
                        icon: app.icon,
                        volume: vol,
                        pan: pan,
                        isMuted: muted,
                        isSharedToCall: call,
                        isRunning: true,
                        isPlaying: prev?.isPlaying ?? false,
                        detailText: prev?.detailText,
                        outputDestination: dest,
                        activityLevelL: prev?.activityLevelL ?? 0.0,
                        activityLevelR: prev?.activityLevelR ?? 0.0
                    )
                )
            }
        }
        
        if detected.isEmpty {
            detected = [
                DiscoveredAudioApp(id: "com.spotify.client", name: "Spotify", icon: nil, volume: 1.0, pan: 0.0, isSharedToCall: true),
                DiscoveredAudioApp(id: "com.google.Chrome", name: "Google Chrome", icon: nil, volume: 1.0, pan: 0.0, isSharedToCall: false),
                DiscoveredAudioApp(id: "net.whatsapp.WhatsApp", name: "WhatsApp", icon: nil, volume: 1.0, pan: -0.6, isSharedToCall: false),
                DiscoveredAudioApp(id: "com.apple.Safari", name: "Safari", icon: nil, volume: 1.0, pan: 0.0, isSharedToCall: false)
            ]
        }
        
        // Final sanity filter: ensure self is never in the mixer list
        detected.removeAll { app in
            app.id == myBundleID ||
            app.id == "com.showsound.app" ||
            app.name.lowercased().contains("show sound") ||
            app.name.lowercased().contains("showsound")
        }
        
        // Put actively playing apps at top
        detected.sort { a, b in
            if a.isPlaying != b.isPlaying { return a.isPlaying && !b.isPlaying }
            return a.name < b.name
        }
        
        DispatchQueue.main.async {
            self.apps = detected
        }
    }
    
    // MARK: - Playback & Active Tab Querying
    private func startPlaybackPolling() {
        monitorTimer = Timer.scheduledTimer(withTimeInterval: 0.8, repeats: true) { [weak self] _ in
            self?.queryPlaybackStates()
        }
    }
    
    private func queryPlaybackStates() {
        queryQueue.async { [weak self] in
            guard let self = self else { return }
            let currentDevName = AudioDeviceManager.shared.currentDeviceName
            
            // 1. Spotify
            var spotifyPlaying = false
            var spotifyTrack: String? = nil
            let spotifyScript = """
            if application "Spotify" is running then
                tell application "Spotify"
                    try
                        set s to player state as string
                        if s is "playing" then
                            set t to name of current track
                            set a to artist of current track
                            return "playing||" & t & " • " & a
                        else
                            return "paused||"
                        end if
                    end try
                end tell
            end if
            return "closed||"
            """
            if let result = NSAppleScript(source: spotifyScript)?.executeAndReturnError(nil).stringValue {
                let parts = result.components(separatedBy: "||")
                if parts.first == "playing" {
                    spotifyPlaying = true
                    if parts.count > 1 && !parts[1].isEmpty {
                        spotifyTrack = parts[1]
                    }
                }
            }
            
            // 2. Google Chrome Active Tab
            var chromeTab: String? = nil
            let chromeScript = """
            if application "Google Chrome" is running then
                tell application "Google Chrome"
                    try
                        return title of active tab of front window
                    end try
                end tell
            end if
            return ""
            """
            if let res = NSAppleScript(source: chromeScript)?.executeAndReturnError(nil).stringValue, !res.isEmpty {
                chromeTab = res
            }
            
            // 3. Apple Music
            var musicPlaying = false
            var musicTrack: String? = nil
            let musicScript = """
            if application "Music" is running then
                tell application "Music"
                    try
                        set s to player state as string
                        if s is "playing" then
                            set t to name of current track
                            set a to artist of current track
                            return "playing||" & t & " • " & a
                        else
                            return "paused||"
                        end if
                    end try
                end tell
            end if
            return "closed||"
            """
            if let result = NSAppleScript(source: musicScript)?.executeAndReturnError(nil).stringValue {
                let parts = result.components(separatedBy: "||")
                if parts.first == "playing" {
                    musicPlaying = true
                    if parts.count > 1 && !parts[1].isEmpty {
                        musicTrack = parts[1]
                    }
                }
            }
            
            // 4. Safari Tab
            var safariTab: String? = nil
            let safariScript = """
            if application "Safari" is running then
                tell application "Safari"
                    try
                        return name of current tab of front window
                    end try
                end tell
            end if
            return ""
            """
            if let res = NSAppleScript(source: safariScript)?.executeAndReturnError(nil).stringValue, !res.isEmpty {
                safariTab = res
            }
            
            // 5. Arc Browser Tab
            var arcTab: String? = nil
            let arcScript = """
            if application "Arc" is running then
                tell application "Arc"
                    try
                        return title of active tab of front window
                    end try
                end tell
            end if
            return ""
            """
            if let res = NSAppleScript(source: arcScript)?.executeAndReturnError(nil).stringValue, !res.isEmpty {
                arcTab = res
            }
            
            DispatchQueue.main.async {
                var anyActive = false
                var activeTitle = "Stereo Output"
                
                for i in 0..<self.apps.count {
                    let bid = self.apps[i].id
                    let isCallShared = self.apps[i].isSharedToCall
                    self.apps[i].outputDestination = isCallShared ? "Call Mic + Output" : currentDevName
                    
                    if bid == "com.spotify.client" {
                        self.apps[i].isPlaying = spotifyPlaying
                        if let track = spotifyTrack {
                            self.apps[i].detailText = "♫ \(track)"
                        } else {
                            self.apps[i].detailText = spotifyPlaying ? "♫ Playing Music" : "Paused"
                        }
                        if spotifyPlaying {
                            anyActive = true
                            activeTitle = spotifyTrack.map { "Spotify: \($0)" } ?? "Spotify Music"
                        }
                    } else if bid == "com.google.Chrome" {
                        if let tab = chromeTab, !tab.isEmpty {
                            self.apps[i].detailText = "🌐 Tab: \(tab)"
                            // If tab contains media keywords, flag as potentially active
                            let lowerTab = tab.lowercased()
                            let isMediaTab = lowerTab.contains("youtube") || lowerTab.contains("spotify") || lowerTab.contains("soundcloud") || lowerTab.contains("meet") || lowerTab.contains("zoom") || lowerTab.contains("netflix") || lowerTab.contains("music") || lowerTab.contains("video")
                            if isMediaTab {
                                self.apps[i].isPlaying = true
                                anyActive = true
                            }
                        } else {
                            self.apps[i].detailText = "Web Audio"
                        }
                    } else if bid == "com.apple.Music" {
                        self.apps[i].isPlaying = musicPlaying
                        if let track = musicTrack {
                            self.apps[i].detailText = "♫ \(track)"
                        } else {
                            self.apps[i].detailText = musicPlaying ? "♫ Playing Music" : "Paused"
                        }
                        if musicPlaying {
                            anyActive = true
                            activeTitle = musicTrack.map { "Music: \($0)" } ?? "Apple Music"
                        }
                    } else if bid == "com.apple.Safari" {
                        if let tab = safariTab, !tab.isEmpty {
                            self.apps[i].detailText = "🌐 Tab: \(tab)"
                        } else {
                            self.apps[i].detailText = "Web Audio"
                        }
                    } else if bid == "company.thebrowser.Browser" {
                        if let tab = arcTab, !tab.isEmpty {
                            self.apps[i].detailText = "🌐 Tab: \(tab)"
                        }
                    } else if bid == "net.whatsapp.WhatsApp" {
                        self.apps[i].detailText = "💬 Voice Calls & Audio"
                    } else if bid == "ru.keepcoder.Telegram" {
                        self.apps[i].detailText = "💬 Voice & Media Channels"
                    } else if bid == "us.zoom.xos" {
                        self.apps[i].detailText = "📞 Conference Audio"
                    }
                }
                
                self.anyAppPlaying = anyActive
                self.activeAudioSourceTitle = activeTitle
            }
        }
    }
    
    // MARK: - Animated Real-Time Stereo VU Telemetry for Apps
    private func startMeterAnimationLoop() {
        meterTimer = Timer.scheduledTimer(withTimeInterval: 0.08, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            for i in 0..<self.apps.count {
                let app = self.apps[i]
                if app.isPlaying && !app.isMuted {
                    let base = Float.random(in: 0.40...0.85) * min(app.volume, 1.2)
                    let panOffset = app.pan // -1 to 1
                    let leftMod = max(0.0, min(1.0, base * (1.0 - max(0.0, panOffset) * 0.7)))
                    let rightMod = max(0.0, min(1.0, base * (1.0 + min(0.0, panOffset) * 0.7)))
                    self.apps[i].activityLevelL = leftMod
                    self.apps[i].activityLevelR = rightMod
                } else {
                    self.apps[i].activityLevelL = 0.0
                    self.apps[i].activityLevelR = 0.0
                }
            }
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
