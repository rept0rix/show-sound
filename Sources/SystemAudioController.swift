import Foundation
import CoreAudio
import AudioToolbox
import AppKit

public final class SystemAudioController: ObservableObject {
    public static let shared = SystemAudioController()

    @Published public private(set) var hardwareVolume: Float = 0.70
    @Published public private(set) var isMuted: Bool = false

    private var defaultOutputDeviceID: AudioObjectID = 0
    private var isSettingLocally = false
    private var systemListenerBlock: AudioObjectPropertyListenerBlock?
    private var deviceListenerBlock: AudioObjectPropertyListenerBlock?
    private var monitoredDeviceID: AudioObjectID = 0
    
    private let scriptQueue = DispatchQueue(label: "com.showsound.applescript", qos: .userInitiated)
    private var lastScriptWorkItem: DispatchWorkItem?
    private var pollTimer: Timer?

    public init() {
        refreshDefaultDevice()
        readHardwareVolume()
        setupSystemDeviceListener()
        startPeriodicPoll()
    }

    deinit {
        pollTimer?.invalidate()
        removeSystemDeviceListener()
        detachDeviceListener()
    }

    public func refreshDefaultDevice() {
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &addr,
            0,
            nil,
            &size,
            &defaultOutputDeviceID
        )
        if status != noErr {
            defaultOutputDeviceID = 0
        }
        
        // Attach listener to the new default device
        attachDeviceListener(to: defaultOutputDeviceID)
    }

    // MARK: - Reading Hardware Volume
    public func readHardwareVolume() {
        guard !isSettingLocally else { return }

        guard defaultOutputDeviceID != 0 else {
            readVolumeAppleScript()
            return
        }

        var vol: Float32 = 0
        var size = UInt32(MemoryLayout<Float32>.size)
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )

        var status = AudioObjectGetPropertyData(defaultOutputDeviceID, &addr, 0, nil, &size, &vol)
        if status != noErr {
            // Try channel 1
            addr.mElement = 1
            status = AudioObjectGetPropertyData(defaultOutputDeviceID, &addr, 0, nil, &size, &vol)
        }

        if status == noErr {
            let clamped = max(0.0, min(1.0, Float(vol)))
            DispatchQueue.main.async {
                self.hardwareVolume = clamped
            }
        } else {
            readVolumeAppleScript()
        }

        // Check Mute
        var muteVal: UInt32 = 0
        var muteSize = UInt32(MemoryLayout<UInt32>.size)
        var muteAddr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        if AudioObjectGetPropertyData(defaultOutputDeviceID, &muteAddr, 0, nil, &muteSize, &muteVal) == noErr {
            let muted = (muteVal != 0)
            DispatchQueue.main.async {
                self.isMuted = muted
            }
        }
    }

    private func readVolumeAppleScript() {
        let script = "output volume of (get volume settings)"
        if let appleScript = NSAppleScript(source: script) {
            let result = appleScript.executeAndReturnError(nil)
            let val = Float(result.int32Value) / 100.0
            DispatchQueue.main.async {
                self.hardwareVolume = max(0.0, min(1.0, val))
            }
        }
    }

    // MARK: - Setting Hardware Volume (0.0 to 1.0)
    public func setHardwareVolume(_ level: Float) {
        let clamped = max(0.0, min(1.0, level))
        isSettingLocally = true

        DispatchQueue.main.async {
            self.hardwareVolume = clamped
            if clamped > 0 && self.isMuted {
                self.isMuted = false
            }
        }

        // 1. Direct CoreAudio HAL Volume Scalar (instantaneous DAC control)
        if defaultOutputDeviceID != 0 {
            var vol = Float32(clamped)
            let size = UInt32(MemoryLayout<Float32>.size)

            var mainAddr = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyVolumeScalar,
                mScope: kAudioDevicePropertyScopeOutput,
                mElement: kAudioObjectPropertyElementMain
            )
            _ = AudioObjectSetPropertyData(defaultOutputDeviceID, &mainAddr, 0, nil, size, &vol)

            // Also set channels 1 and 2 for stereo hardware
            for ch: UInt32 in [1, 2] {
                var chAddr = AudioObjectPropertyAddress(
                    mSelector: kAudioDevicePropertyVolumeScalar,
                    mScope: kAudioDevicePropertyScopeOutput,
                    mElement: ch
                )
                _ = AudioObjectSetPropertyData(defaultOutputDeviceID, &chAddr, 0, nil, size, &vol)
            }
        }

        // 2. Debounced AppleScript (fires 50ms after slider movement for system UI sync)
        lastScriptWorkItem?.cancel()
        let percent = Int(round(clamped * 100))
        let workItem = DispatchWorkItem { [weak self] in
            let script = "set volume output volume \(percent)"
            NSAppleScript(source: script)?.executeAndReturnError(nil)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                self?.isSettingLocally = false
            }
        }
        lastScriptWorkItem = workItem
        scriptQueue.asyncAfter(deadline: .now() + 0.05, execute: workItem)
    }

    public func setMute(_ muted: Bool) {
        isMuted = muted
        if defaultOutputDeviceID != 0 {
            var muteVal: UInt32 = muted ? 1 : 0
            var muteAddr = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyMute,
                mScope: kAudioDevicePropertyScopeOutput,
                mElement: kAudioObjectPropertyElementMain
            )
            _ = AudioObjectSetPropertyData(defaultOutputDeviceID, &muteAddr, 0, nil, UInt32(MemoryLayout<UInt32>.size), &muteVal)
        }
        let script = "set volume output muted \(muted ? "true" : "false")"
        scriptQueue.async {
            NSAppleScript(source: script)?.executeAndReturnError(nil)
        }
    }

    // MARK: - Per-App Volume Dispatcher
    public func setAppVolume(bundleID: String, volume: Float) {
        guard !NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).isEmpty else { return }
        let volPercent = min(100, max(0, Int(volume * 100)))

        scriptQueue.async {
            switch bundleID {
            case "com.spotify.client":
                let script = "tell application id \"com.spotify.client\" to set sound volume to \(volPercent)"
                NSAppleScript(source: script)?.executeAndReturnError(nil)
            case "com.apple.Music":
                let script = "tell application id \"com.apple.Music\" to set sound volume to \(volPercent)"
                NSAppleScript(source: script)?.executeAndReturnError(nil)
            case "org.videolan.vlc":
                let vlcVol = Int(volume * 256)
                let script = "tell application id \"org.videolan.vlc\" to set volume to \(vlcVol)"
                NSAppleScript(source: script)?.executeAndReturnError(nil)
            case "com.colliderli.iina":
                let script = "tell application id \"com.colliderli.iina\" to set sound volume to \(volPercent)"
                NSAppleScript(source: script)?.executeAndReturnError(nil)
            default:
                break
            }
        }
    }

    public func setAppMuted(bundleID: String, isMuted: Bool) {
        if isMuted {
            setAppVolume(bundleID: bundleID, volume: 0.0)
        } else {
            setAppVolume(bundleID: bundleID, volume: 1.0)
        }
    }

    // MARK: - Listeners
    private func setupSystemDeviceListener() {
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            guard let self = self else { return }
            self.refreshDefaultDevice()
            self.readHardwareVolume()
        }
        self.systemListenerBlock = block

        AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &addr,
            DispatchQueue.main,
            block
        )
    }

    private func removeSystemDeviceListener() {
        guard let block = systemListenerBlock else { return }
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectRemovePropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &addr,
            DispatchQueue.main,
            block
        )
    }

    private func attachDeviceListener(to deviceID: AudioObjectID) {
        detachDeviceListener()
        guard deviceID != 0 else { return }
        monitoredDeviceID = deviceID

        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )

        let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            guard let self = self, !self.isSettingLocally else { return }
            self.readHardwareVolume()
        }
        self.deviceListenerBlock = block

        AudioObjectAddPropertyListenerBlock(
            deviceID,
            &addr,
            DispatchQueue.main,
            block
        )
    }

    private func detachDeviceListener() {
        guard let block = deviceListenerBlock, monitoredDeviceID != 0 else { return }
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectRemovePropertyListenerBlock(
            monitoredDeviceID,
            &addr,
            DispatchQueue.main,
            block
        )
        deviceListenerBlock = nil
        monitoredDeviceID = 0
    }

    private func startPeriodicPoll() {
        pollTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.readHardwareVolume()
        }
    }
}
