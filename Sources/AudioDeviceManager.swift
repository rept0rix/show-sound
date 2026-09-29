import Foundation
import CoreAudio
import AudioToolbox
import Combine

public struct AudioOutputDevice: Identifiable, Equatable, Hashable {
    public let id: AudioObjectID
    public let uid: String
    public let name: String
    public let isDefault: Bool
    public let isBuiltInSpeaker: Bool
    public let isHeadphonesOrAirPods: Bool
    
    public init(id: AudioObjectID, uid: String, name: String, isDefault: Bool) {
        self.id = id
        self.uid = uid
        self.name = name
        self.isDefault = isDefault
        
        let lower = name.lowercased()
        self.isBuiltInSpeaker = lower.contains("speaker") || lower.contains("internal") || lower.contains("built-in")
        self.isHeadphonesOrAirPods = lower.contains("airpod") || lower.contains("headphone") || lower.contains("ear")
    }
}

public final class AudioDeviceManager: ObservableObject {
    public static let shared = AudioDeviceManager()
    
    @Published public private(set) var outputDevices: [AudioOutputDevice] = []
    @Published public private(set) var currentDefaultDeviceID: AudioObjectID = 0
    @Published public private(set) var currentDeviceName: String = "Default Audio Device"
    @Published public private(set) var isCurrentSpeaker: Bool = true
    
    private var listenerBlock: AudioObjectPropertyListenerBlock?
    
    public init() {
        refreshDevices()
        setupDeviceChangeListener()
    }
    
    deinit {
        removeDeviceChangeListener()
    }
    
    public func refreshDevices() {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        var dataSize: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &propertyAddress, 0, nil, &dataSize) == noErr else {
            return
        }
        
        let deviceCount = Int(dataSize) / MemoryLayout<AudioObjectID>.size
        var deviceIDs = [AudioObjectID](repeating: 0, count: deviceCount)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &propertyAddress, 0, nil, &dataSize, &deviceIDs) == noErr else {
            return
        }
        
        let defaultID = fetchDefaultOutputDeviceID()
        
        var list: [AudioOutputDevice] = []
        for devID in deviceIDs {
            if hasOutputChannels(devID) {
                let name = fetchDeviceName(devID)
                let uid = fetchDeviceUID(devID)
                let isDef = (devID == defaultID)
                list.append(AudioOutputDevice(id: devID, uid: uid, name: name, isDefault: isDef))
            }
        }
        
        DispatchQueue.main.async {
            self.outputDevices = list
            self.currentDefaultDeviceID = defaultID
            if let defDevice = list.first(where: { $0.id == defaultID }) {
                self.currentDeviceName = defDevice.name
                self.isCurrentSpeaker = defDevice.isBuiltInSpeaker
            } else if let first = list.first {
                self.currentDeviceName = first.name
                self.isCurrentSpeaker = first.isBuiltInSpeaker
            }
        }
    }
    
    public func setDefaultOutputDevice(id: AudioObjectID) {
        var newDeviceID = id
        var defaultOutputAddr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        let status = AudioObjectSetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &defaultOutputAddr,
            0,
            nil,
            UInt32(MemoryLayout<AudioObjectID>.size),
            &newDeviceID
        )
        
        if status == noErr {
            refreshDevices()
        }
    }
    
    private func fetchDefaultOutputDeviceID() -> AudioObjectID {
        var defaultID: AudioObjectID = 0
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        _ = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &propertyAddress, 0, nil, &size, &defaultID)
        return defaultID
    }
    
    private func hasOutputChannels(_ devID: AudioObjectID) -> Bool {
        var streamAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreams,
            mScope: kAudioObjectPropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        var size: UInt32 = 0
        let err = AudioObjectGetPropertyDataSize(devID, &streamAddress, 0, nil, &size)
        return err == noErr && size > 0
    }
    
    private func fetchDeviceName(_ devID: AudioObjectID) -> String {
        var nameAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceNameCFString,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var cfName: CFString? = nil
        var size = UInt32(MemoryLayout<CFString?>.size)
        let err = withUnsafeMutablePointer(to: &cfName) { ptr in
            AudioObjectGetPropertyData(devID, &nameAddress, 0, nil, &size, ptr)
        }
        if err == noErr, let name = cfName as String? {
            return name
        }
        return "Audio Output \(devID)"
    }
    
    private func fetchDeviceUID(_ devID: AudioObjectID) -> String {
        var uidAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceUID,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var cfUID: CFString? = nil
        var size = UInt32(MemoryLayout<CFString?>.size)
        let err = withUnsafeMutablePointer(to: &cfUID) { ptr in
            AudioObjectGetPropertyData(devID, &uidAddress, 0, nil, &size, ptr)
        }
        if err == noErr, let uid = cfUID as String? {
            return uid
        }
        return UUID().uuidString
    }
    
    private func setupDeviceChangeListener() {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            self?.refreshDevices()
        }
        self.listenerBlock = block
        
        AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            DispatchQueue.main,
            block
        )
    }
    
    private func removeDeviceChangeListener() {
        guard let block = listenerBlock else { return }
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectRemovePropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            DispatchQueue.main,
            block
        )
    }
}
