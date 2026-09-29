import SwiftUI
import AppKit

public struct MixerView: View {
    @ObservedObject var model = MixerModel.shared
    @ObservedObject var equalizer = EqualizerEngine.shared
    @ObservedObject var vad = VoiceActivityDetector.shared
    @ObservedObject var deviceManager = AudioDeviceManager.shared
    @ObservedObject var appDetector = AppDetector.shared
    @State private var selectedTab: Int = 0

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            // Header Bar
            headerSection
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 10)

            // Navigation Segmented Control
            navigationTabs
                .padding(.horizontal, 16)
                .padding(.bottom, 12)

            Divider()
                .background(Color.white.opacity(0.1))

            // Main Content Area
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 16) {
                    if selectedTab == 0 {
                        // TAB 1: Mixer & Master SafeBoost
                        masterBoostCard
                        perAppMixerCard
                    } else if selectedTab == 1 {
                        // TAB 2: 10-Band Equalizer & Noise Isolation
                        equalizerCard
                        presetsCard
                        noiseGateCard
                    } else {
                        // TAB 3: Output Devices & Call Music Injection
                        outputDevicesCard
                        callStreamerCard
                    }
                }
                .padding(16)
            }
            .frame(maxHeight: 520)

            Divider()
                .background(Color.white.opacity(0.1))

            // Footer Bar
            footerSection
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
        }
        .frame(width: 390)
        .background(
            ZStack {
                Color(nsColor: .windowBackgroundColor)
                LinearGradient(
                    colors: [Color.cyan.opacity(0.04), Color.blue.opacity(0.06), Color.clear],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        )
    }

    // MARK: - Header
    private var headerSection: some View {
        HStack(alignment: .center) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        LinearGradient(
                            colors: [Color.cyan, Color.blue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 30, height: 30)

                Image(systemName: "speaker.wave.3.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text("Show Sound")
                        .font(.system(size: 14, weight: .bold))
                    Text(ShowSoundSupport.version)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Capsule().fill(Color.white.opacity(0.1)))
                }
                Text("Safe Volume & Per-App Audio Engine")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Hardware Guard Status Pill
            HStack(spacing: 4) {
                Image(systemName: model.speakerProtection ? "shield.checkmark.fill" : "shield.slash")
                    .font(.system(size: 11))
                    .foregroundColor(model.speakerProtection ? .green : .yellow)
                Text(model.speakerProtection ? "GainGuard Active" : "Unprotected")
                    .font(.system(size: 10, weight: .medium))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(Color.white.opacity(0.08)))
        }
    }

    // MARK: - Navigation Tabs
    private var navigationTabs: some View {
        HStack(spacing: 4) {
            tabButton(title: "Mixer", icon: "slider.vertical.3", index: 0)
            tabButton(title: "10-Band EQ", icon: "waveform", index: 1)
            tabButton(title: "Devices & Calls", icon: "airpodsmax", index: 2)
        }
        .padding(3)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.06)))
    }

    private func tabButton(title: String, icon: String, index: Int) -> some View {
        Button(action: { selectedTab = index }) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .medium))
                Text(title)
                    .font(.system(size: 11, weight: selectedTab == index ? .bold : .medium))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(selectedTab == index ? Color.white.opacity(0.15) : Color.clear)
            )
            .foregroundColor(selectedTab == index ? .primary : .secondary)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Tab 1: Master SafeBoost Card
    private var masterBoostCard: some View {
        VStack(spacing: 12) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Master SafeBoost")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.primary)
                    Text("Direct macOS hardware volume & dynamic limiter")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                Spacer()

                // Quick Reset Pill & Percentage Readout
                HStack(spacing: 6) {
                    if abs(model.masterBoost - 1.0) > 0.02 {
                        Button(action: { model.resetTo100() }) {
                            HStack(spacing: 3) {
                                Image(systemName: "arrow.counterclockwise")
                                    .font(.system(size: 9, weight: .bold))
                                Text("Reset")
                                    .font(.system(size: 10, weight: .bold))
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(Color.white.opacity(0.12)))
                            .foregroundColor(.cyan)
                        }
                        .buttonStyle(.plain)
                        .help("Reset volume to standard 100%")
                    }

                    Text("\(Int(round(model.masterBoost * 100)))%")
                        .font(.system(size: 22, weight: .heavy, design: .rounded))
                        .foregroundColor(boostColor(for: model.masterBoost))
                }
            }

            // Big Slider
            Slider(value: Binding(
                get: { model.masterBoost },
                set: { model.setBoost(to: $0) }
            ), in: 0.0...3.0, step: 0.01)
            .accentColor(boostColor(for: model.masterBoost))

            // Quick Volume Presets & Stepper Buttons Row:
            // [-] 30% 50% 70% [100% Reset] 120% 150% 200% [+]
            HStack(spacing: 4) {
                // Stepper [-]
                Button(action: { model.stepVolume(delta: -0.10) }) {
                    Image(systemName: "minus")
                        .font(.system(size: 10, weight: .bold))
                        .frame(width: 26, height: 26)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.08)))
                        .foregroundColor(.primary)
                }
                .buttonStyle(.plain)
                .help("Decrease volume by 10%")

                // 30%
                presetButton(value: 0.30, label: "30%")

                // 50%
                presetButton(value: 0.50, label: "50%")

                // 70%
                presetButton(value: 0.70, label: "70%")

                // 100% Reset Button
                Button(action: { model.resetTo100() }) {
                    HStack(spacing: 2) {
                        Text("100%")
                            .font(.system(size: 10, weight: .bold))
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 8, weight: .bold))
                    }
                    .frame(height: 26)
                    .padding(.horizontal, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(isCurrentPreset(1.0) ? Color.cyan : Color.white.opacity(0.12))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.cyan.opacity(0.7), lineWidth: 1)
                    )
                    .foregroundColor(isCurrentPreset(1.0) ? .black : .cyan)
                }
                .buttonStyle(.plain)
                .help("Reset to 100% (Standard Mac Volume)")

                // 120%
                presetButton(value: 1.20, label: "120%", isBoost: true)

                // 150%
                presetButton(value: 1.50, label: "150%", isBoost: true)

                // 200%
                presetButton(value: 2.00, label: "200%", isBoost: true)

                // Stepper [+]
                Button(action: { model.stepVolume(delta: 0.10) }) {
                    Image(systemName: "plus")
                        .font(.system(size: 10, weight: .bold))
                        .frame(width: 26, height: 26)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.08)))
                        .foregroundColor(.primary)
                }
                .buttonStyle(.plain)
                .help("Increase volume by 10%")
            }

            // Dual Channel Real-Time VU Meters
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 3) {
                    vuBar(label: "L", value: model.peakLeft)
                    vuBar(label: "R", value: model.peakRight)
                }

                // Safety Badge
                safetyBadgeView
            }

            // High-Pass Filter Toggle
            Toggle(isOn: $model.speakerProtection) {
                HStack(spacing: 4) {
                    Text("55Hz Speaker Protection (Cuts destructive sub-bass)")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }
            .toggleStyle(.checkbox)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }

    // MARK: - Tab 1: Per-App Mixer Card
    private var perAppMixerCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Per-App Audio Mixer")
                    .font(.system(size: 12, weight: .bold))
                Spacer()
                Text("\(appDetector.apps.count) Apps Active")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }

            VStack(spacing: 12) {
                ForEach(appDetector.apps) { track in
                    appRow(track: track)
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }

    private func appRow(track: DiscoveredAudioApp) -> some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                if let icon = track.icon {
                    Image(nsImage: icon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 18, height: 18)
                        .cornerRadius(4)
                } else {
                    Image(systemName: "music.note")
                        .font(.system(size: 12))
                        .frame(width: 18)
                        .foregroundColor(.cyan)
                }

                Text(track.name)
                    .font(.system(size: 11, weight: .medium))
                    .lineLimit(1)

                Spacer()

                // Call Stream Pill
                if model.shareMusicInCall {
                    Button(action: { appDetector.toggleCallShare(for: track.id) }) {
                        Text(track.isSharedToCall ? "In Call" : "+ Call")
                            .font(.system(size: 9, weight: .bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(track.isSharedToCall ? Color.cyan.opacity(0.3) : Color.white.opacity(0.08))
                            )
                            .foregroundColor(track.isSharedToCall ? .cyan : .secondary)
                    }
                    .buttonStyle(.plain)
                }

                // Mute
                Button(action: { appDetector.toggleMute(for: track.id) }) {
                    Image(systemName: track.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                        .font(.system(size: 10))
                        .foregroundColor(track.isMuted ? .red : .secondary)
                }
                .buttonStyle(.plain)

                // Volume %
                Text("\(Int(track.volume * 100))%")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .frame(width: 36, alignment: .trailing)
            }

            // Volume Slider + L/R Pan
            HStack(spacing: 10) {
                Slider(value: Binding(
                    get: { track.volume },
                    set: { appDetector.setVolume(for: track.id, volume: $0) }
                ), in: 0.0...2.0)
                .opacity(track.isMuted ? 0.3 : 1.0)

                // Panning Indicator / Slider
                HStack(spacing: 3) {
                    Text("L")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.secondary)
                    Slider(value: Binding(
                        get: { track.pan },
                        set: { appDetector.setPan(for: track.id, pan: $0) }
                    ), in: -1.0...1.0)
                    .frame(width: 50)
                    Text("R")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Tab 2: 10-Band Equalizer Card
    private var equalizerCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("10-Band Graphic Equalizer")
                    .font(.system(size: 12, weight: .bold))
                Spacer()
                Button("Reset Flat") {
                    equalizer.resetToFlat()
                }
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.cyan)
                .buttonStyle(.plain)
            }

            // 10 Vertical Sliders
            HStack(spacing: 4) {
                ForEach(equalizer.bands) { band in
                    VStack(spacing: 4) {
                        Text(String(format: "%+.0f", band.gainDb))
                            .font(.system(size: 8, weight: .bold, design: .monospaced))
                            .foregroundColor(band.gainDb == 0 ? .secondary : (band.gainDb > 0 ? .cyan : .orange))

                        // Custom Vertical Slider
                        VerticalEQSlider(
                            value: Binding(
                                get: { band.gainDb },
                                set: { equalizer.setBandGain(id: band.id, gainDb: $0) }
                            ),
                            range: -12...12
                        )
                        .frame(width: 28, height: 110)

                        Text(band.label)
                            .font(.system(size: 8, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }

    // MARK: - Tab 2: Acoustic Presets Card
    private var presetsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Acoustic Presets")
                .font(.system(size: 12, weight: .bold))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(AudioPreset.allCases) { preset in
                        Button(action: { model.activePreset = preset }) {
                            Text(preset.rawValue)
                                .font(.system(size: 10, weight: .semibold))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(model.activePreset == preset ? Color.cyan : Color.white.opacity(0.08))
                                )
                                .foregroundColor(model.activePreset == preset ? .black : .primary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Text(model.activePreset.description)
                .font(.system(size: 9))
                .foregroundColor(.secondary)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }

    // MARK: - Tab 2: Noise Gate Card
    private var noiseGateCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "waveform.badge.mic")
                    .font(.system(size: 12))
                    .foregroundColor(.cyan)
                Text("Background Noise Isolation (Downward Gate)")
                    .font(.system(size: 12, weight: .bold))
                Spacer()
                Toggle("", isOn: $equalizer.noiseGateEnabled)
                    .toggleStyle(.switch)
                    .controlSize(.small)
            }

            Text("Silences low-level fan hum, room hiss, and AC noise during audio pauses.")
                .font(.system(size: 10))
                .foregroundColor(.secondary)

            if equalizer.noiseGateEnabled {
                HStack(spacing: 8) {
                    Text("Threshold:")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    Slider(value: $equalizer.noiseGateThresholdDb, in: -60.0...(-24.0), step: 1.0)
                    Text("\(Int(equalizer.noiseGateThresholdDb)) dB")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .frame(width: 44, alignment: .trailing)
                }
                .padding(.top, 4)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }

    // MARK: - Tab 3: Output Devices Card
    private var outputDevicesCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("System Audio Output Routing")
                    .font(.system(size: 12, weight: .bold))
                Spacer()
                Button(action: { deviceManager.refreshDevices() }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }

            VStack(spacing: 8) {
                ForEach(deviceManager.outputDevices) { dev in
                    Button(action: {
                        deviceManager.setDefaultOutputDevice(id: dev.id)
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: deviceIcon(for: dev))
                                .font(.system(size: 13))
                                .foregroundColor(dev.isDefault ? .cyan : .secondary)
                                .frame(width: 20)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(dev.name)
                                    .font(.system(size: 11, weight: dev.isDefault ? .bold : .medium))
                                    .foregroundColor(dev.isDefault ? .primary : .secondary)
                                if dev.isDefault {
                                    Text("Active System Output")
                                        .font(.system(size: 9))
                                        .foregroundColor(.cyan)
                                }
                            }

                            Spacer()

                            if dev.isDefault {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(.cyan)
                            }
                        }
                        .padding(8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(dev.isDefault ? Color.cyan.opacity(0.1) : Color.white.opacity(0.04))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }

    private func deviceIcon(for dev: AudioOutputDevice) -> String {
        if dev.isHeadphonesOrAirPods {
            return "airpodspro"
        } else if dev.isBuiltInSpeaker {
            return "laptopcomputer"
        } else {
            return "speaker.wave.2.fill"
        }
    }

    // MARK: - Tab 3: Call Streamer Card
    private var callStreamerCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "phone.badge.waveform.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.cyan)
                Text("Share Music in Calls (Loopback)")
                    .font(.system(size: 12, weight: .bold))
                Spacer()
                Toggle("", isOn: $model.shareMusicInCall)
                    .toggleStyle(.switch)
                    .controlSize(.small)
            }

            Text("Streams background music directly into your call mic (WhatsApp, Zoom, Meet) in pristine digital stereo. Voice Activity Detector ducks music by -18dB whenever you speak.")
                .font(.system(size: 10))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if model.shareMusicInCall {
                VStack(spacing: 8) {
                    HStack {
                        Toggle(isOn: $model.autoDuckingEnabled) {
                            Text("Auto-Ducking (-18dB on Speech)")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .toggleStyle(.checkbox)

                        Spacer()

                        // Speaking status indicator
                        HStack(spacing: 4) {
                            Circle()
                                .fill(vad.isSpeaking ? Color.green : Color.secondary.opacity(0.5))
                                .frame(width: 6, height: 6)
                            Text(vad.isSpeaking ? "Speaking (Ducked)" : "Mic Ready")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(vad.isSpeaking ? .green : .secondary)
                        }
                    }

                    // Live Mic VU Meter Bar
                    HStack(spacing: 6) {
                        Image(systemName: "mic.fill")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color.white.opacity(0.1))
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(vad.isSpeaking ? Color.green : Color.cyan)
                                    .frame(width: geo.size.width * CGFloat(vad.micLevelLinear))
                            }
                        }
                        .frame(height: 6)
                        Text(String(format: "%.0f dB", vad.micLevelDb))
                            .font(.system(size: 8, weight: .bold, design: .monospaced))
                            .foregroundColor(.secondary)
                            .frame(width: 38, alignment: .trailing)
                    }
                }
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.cyan.opacity(0.08)))
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(model.shareMusicInCall ? Color.cyan.opacity(0.08) : Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(model.shareMusicInCall ? Color.cyan.opacity(0.3) : Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }

    // MARK: - VU Meter Bar
    private func vuBar(label: String, value: Float) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 8)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.white.opacity(0.1))

                    RoundedRectangle(cornerRadius: 2)
                        .fill(
                            LinearGradient(
                                colors: [.green, .yellow, .orange],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * CGFloat(min(max(value, 0.0), 1.0)))
                }
            }
            .frame(height: 6)
        }
    }

    // MARK: - Safety Badge
    private var safetyBadgeView: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(safetyColor)
                .frame(width: 6, height: 6)
            Text(safetyText)
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(safetyColor)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(Capsule().fill(safetyColor.opacity(0.15)))
    }

    private var safetyColor: Color {
        switch model.safetyState {
        case .safe: return .green
        case .compressing: return .yellow
        case .limiting: return .orange
        }
    }

    private var safetyText: String {
        switch model.safetyState {
        case .safe: return "SAFE"
        case .compressing: return "COMP"
        case .limiting: return "LIMITER"
        }
    }

    private func boostColor(for val: Float) -> Color {
        if val <= 1.0 { return .cyan }
        if val <= 2.5 { return .green }
        if val <= 4.0 { return .yellow }
        return .orange
    }

    private func isCurrentPreset(_ val: Float) -> Bool {
        return abs(model.masterBoost - val) < 0.03
    }

    private func presetButton(value: Float, label: String, isBoost: Bool = false) -> some View {
        let active = isCurrentPreset(value)
        return Button(action: { model.setBoost(to: value) }) {
            Text(label)
                .font(.system(size: 10, weight: active ? .bold : .medium))
                .frame(maxWidth: .infinity)
                .frame(height: 26)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(
                            active ? (isBoost ? Color.orange : Color.cyan.opacity(0.85)) :
                            (isBoost ? Color.orange.opacity(0.12) : Color.white.opacity(0.07))
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(
                            active ? (isBoost ? Color.orange : Color.cyan) :
                            (isBoost ? Color.orange.opacity(0.3) : Color.white.opacity(0.1)),
                            lineWidth: 1
                        )
                )
                .foregroundColor(
                    active ? (isBoost ? .white : .black) :
                    (isBoost ? .orange : .primary)
                )
        }
        .buttonStyle(.plain)
        .help("Set volume to \(label)")
    }

    // MARK: - Footer
    private var footerSection: some View {
        HStack(spacing: 8) {
            Button(action: {
                if let url = URL(string: "https://rept0rix.github.io/show-sound/") {
                    NSWorkspace.shared.open(url)
                }
            }) {
                Text("Show Sound Website")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)

            Spacer()

            if let updateVer = AppDelegate.shared.availableUpdateVersion {
                Button("Update to v\(updateVer)") {
                    AppUpdate.askAgain()
                }
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.black)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Capsule().fill(Color.yellow))
                .buttonStyle(.plain)
            } else {
                Button("Check for Updates") {
                    AppUpdate.checkManually()
                }
                .font(.system(size: 10))
                .foregroundColor(.secondary)
                .buttonStyle(.plain)
            }

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .font(.system(size: 10))
            .foregroundColor(.secondary)
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Vertical EQ Slider Component
public struct VerticalEQSlider: View {
    @Binding var value: Float
    var range: ClosedRange<Float>

    public var body: some View {
        GeometryReader { geo in
            let totalHeight = geo.size.height
            let normalized = CGFloat((value - range.lowerBound) / (range.upperBound - range.lowerBound))
            let thumbY = totalHeight * (1.0 - normalized)

            ZStack(alignment: .top) {
                // Background Track
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.white.opacity(0.12))
                    .frame(width: 4, height: totalHeight)
                    .position(x: geo.size.width / 2, y: totalHeight / 2)

                // 0dB Center Marker
                Rectangle()
                    .fill(Color.white.opacity(0.3))
                    .frame(width: 10, height: 1)
                    .position(x: geo.size.width / 2, y: totalHeight / 2)

                // Thumb Handle
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.cyan)
                    .frame(width: 18, height: 10)
                    .shadow(color: Color.black.opacity(0.4), radius: 2)
                    .position(x: geo.size.width / 2, y: min(max(thumbY, 5), totalHeight - 5))
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        let locationY = gesture.location.y
                        let clampedY = min(max(locationY, 0), totalHeight)
                        let newNorm = 1.0 - (clampedY / totalHeight)
                        let newVal = Float(newNorm) * (range.upperBound - range.lowerBound) + range.lowerBound
                        self.value = min(max(newVal, range.lowerBound), range.upperBound)
                    }
            )
        }
    }
}
