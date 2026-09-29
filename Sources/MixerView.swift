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
                .background(Color.white.opacity(0.12))

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
            .frame(maxHeight: 560)

            Divider()
                .background(Color.white.opacity(0.12))

            // Footer Bar
            footerSection
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
        }
        .frame(width: 420)
        .preferredColorScheme(.dark)
        .background(
            ZStack {
                Color(red: 0.07, green: 0.08, blue: 0.11)
                LinearGradient(
                    colors: [
                        Color.cyan.opacity(0.08),
                        Color.blue.opacity(0.04),
                        Color.black.opacity(0.85)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        )
    }

    // MARK: - Header
    private var headerSection: some View {
        HStack(alignment: .center, spacing: 10) {
            // Brand Icon
            ZStack {
                RoundedRectangle(cornerRadius: 9)
                    .fill(
                        LinearGradient(
                            colors: [Color.cyan, Color.blue.opacity(0.9)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 32, height: 32)
                    .shadow(color: Color.cyan.opacity(0.35), radius: 6, x: 0, y: 2)

                Image(systemName: "speaker.wave.3.fill")
                    .font(.system(size: 14, weight: .black))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 6) {
                    Text("Show Sound")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text(ShowSoundSupport.version)
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.8))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1.5)
                        .background(Capsule().fill(Color.white.opacity(0.12)))
                }
                
                // Active Output Device name
                HStack(spacing: 4) {
                    Image(systemName: deviceManager.isCurrentSpeaker ? "speaker.wave.2" : "airpodspro")
                        .font(.system(size: 9))
                        .foregroundColor(.cyan)
                    Text(deviceManager.currentDeviceName)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            if model.masterBoost > 1.0 {
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 9))
                    Text("BOOST: \(model.boostFormattedTime)")
                        .font(.system(size: 9.5, weight: .heavy, design: .monospaced))
                }
                .foregroundColor(.red)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Capsule().fill(Color.red.opacity(0.18)))
                .overlay(Capsule().stroke(Color.red.opacity(0.6), lineWidth: 0.8))
                .shadow(color: Color.red.opacity(0.4), radius: 4)
            } else {
                // GainGuard Hardware Protection Pill
                HStack(spacing: 4) {
                    Image(systemName: model.speakerProtection ? "shield.checkmark.fill" : "shield.slash")
                        .font(.system(size: 10))
                        .foregroundColor(model.speakerProtection ? .green : .yellow)
                    Text(model.speakerProtection ? "GainGuard" : "Unprotected")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(model.speakerProtection ? .white : .yellow)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(model.speakerProtection ? Color.green.opacity(0.15) : Color.yellow.opacity(0.15))
                )
                .overlay(
                    Capsule()
                        .stroke(model.speakerProtection ? Color.green.opacity(0.3) : Color.yellow.opacity(0.3), lineWidth: 0.8)
                )
            }
        }
    }

    // MARK: - Navigation Tabs
    private var navigationTabs: some View {
        HStack(spacing: 6) {
            tabButton(title: "Mixer", icon: "slider.vertical.3", index: 0)
            tabButton(title: "10-Band EQ", icon: "waveform", index: 1)
            tabButton(title: "Devices & Calls", icon: "airpodsmax", index: 2)
        }
        .padding(3)
        .background(
            RoundedRectangle(cornerRadius: 9)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 9)
                        .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
                )
        )
    }

    private func tabButton(title: String, icon: String, index: Int) -> some View {
        Button(action: { withAnimation(.easeInOut(duration: 0.15)) { selectedTab = index } }) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: selectedTab == index ? .bold : .medium))
                Text(title)
                    .font(.system(size: 11, weight: selectedTab == index ? .bold : .medium))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 7)
                    .fill(selectedTab == index ? Color.white.opacity(0.18) : Color.clear)
            )
            .foregroundColor(selectedTab == index ? .white : .secondary)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Tab 1: Master SafeBoost Card
    private var masterBoostCard: some View {
        VStack(spacing: 12) {
            // Card Title & Channel Status Banner
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text("Master SafeBoost")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        
                        // Active Channel Status Badge
                        if model.isChannelActive {
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(Color.green)
                                    .frame(width: 6, height: 6)
                                    .shadow(color: .green, radius: 4)
                                Text("CH 1 & 2 ACTIVE")
                                    .font(.system(size: 8, weight: .heavy, design: .monospaced))
                                    .foregroundColor(.green)
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.green.opacity(0.15)))
                            .overlay(Capsule().stroke(Color.green.opacity(0.4), lineWidth: 0.8))
                        } else if model.audioController.isMuted {
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 6, height: 6)
                                Text("MUTED")
                                    .font(.system(size: 8, weight: .heavy, design: .monospaced))
                                    .foregroundColor(.red)
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.red.opacity(0.15)))
                            .overlay(Capsule().stroke(Color.red.opacity(0.4), lineWidth: 0.8))
                        } else {
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(Color.secondary)
                                    .frame(width: 5, height: 5)
                                Text("STEREO READY")
                                    .font(.system(size: 8, weight: .semibold, design: .monospaced))
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.white.opacity(0.06)))
                        }
                    }

                    Text("Direct macOS hardware volume & dynamic peak limiter")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Quick Reset Pill + Big Percentage Readout
                HStack(spacing: 6) {
                    if abs(model.masterBoost - 1.0) > 0.02 {
                        Button(action: { model.resetTo100() }) {
                            HStack(spacing: 3) {
                                Image(systemName: "arrow.counterclockwise")
                                    .font(.system(size: 9, weight: .bold))
                                Text("Reset")
                                    .font(.system(size: 10, weight: .bold))
                            }
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3.5)
                            .background(Capsule().fill(model.masterBoost > 1.0 ? Color.red.opacity(0.2) : Color.cyan.opacity(0.2)))
                            .overlay(Capsule().stroke(model.masterBoost > 1.0 ? Color.red.opacity(0.6) : Color.cyan.opacity(0.5), lineWidth: 1))
                            .foregroundColor(model.masterBoost > 1.0 ? .red : .cyan)
                        }
                        .buttonStyle(.plain)
                        .help("Reset volume to standard 100% (0 dBFS unity)")
                    }

                    Text("\(Int(round(model.masterBoost * 100)))%")
                        .font(.system(size: 22, weight: .heavy, design: .rounded))
                        .foregroundColor(boostColor(for: model.masterBoost))
                }
            }

            // Big Volume Slider (0.0 to 3.0)
            Slider(value: Binding(
                get: { model.masterBoost },
                set: { model.setBoost(to: $0) }
            ), in: 0.0...3.0, step: 0.01)
            .accentColor(boostColor(for: model.masterBoost))

            // Quick Volume Presets & Steppers Row: [-] 30% 50% 70% [100% ↺] 120% 150% 200% [+]
            HStack(spacing: 4) {
                // Stepper [-]
                Button(action: { model.stepVolume(delta: -0.10) }) {
                    Image(systemName: "minus")
                        .font(.system(size: 10, weight: .bold))
                        .frame(width: 28, height: 26)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.08)))
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.white.opacity(0.12), lineWidth: 0.8))
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

                // 100% Primary Anchor Button
                Button(action: { model.resetTo100() }) {
                    HStack(spacing: 2) {
                        Text("100%")
                            .font(.system(size: 10, weight: .heavy))
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 8, weight: .bold))
                    }
                    .frame(height: 26)
                    .padding(.horizontal, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(isCurrentPreset(1.0) ? Color.cyan : Color.cyan.opacity(0.15))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.cyan.opacity(0.8), lineWidth: 1)
                    )
                    .foregroundColor(isCurrentPreset(1.0) ? .black : .cyan)
                    .shadow(color: isCurrentPreset(1.0) ? Color.cyan.opacity(0.3) : .clear, radius: 4)
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
                        .frame(width: 28, height: 26)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.08)))
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.white.opacity(0.12), lineWidth: 0.8))
                        .foregroundColor(.primary)
                }
                .buttonStyle(.plain)
                .help("Increase volume by 10%")
            }

            // 100%+ OVERDRIVE BATTERY & SPEAKER PROTECTION BOX (User Requested)
            if model.masterBoost > 1.0 {
                VStack(spacing: 8) {
                    HStack {
                        HStack(spacing: 5) {
                            Image(systemName: "flame.fill")
                                .font(.system(size: 11))
                                .foregroundColor(.red)
                            Text("100%+ OVERDRIVE (SPEAKER & BATTERY GUARD)")
                                .font(.system(size: 8.5, weight: .heavy, design: .monospaced))
                                .foregroundColor(.red)
                        }

                        Spacer()

                        // Live countdown badge
                        HStack(spacing: 4) {
                            Image(systemName: "timer")
                                .font(.system(size: 10, weight: .bold))
                            Text("Reset in \(model.boostFormattedTime)")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                        }
                        .foregroundColor(.red)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Color.red.opacity(0.18)))
                        .overlay(Capsule().stroke(Color.red.opacity(0.6), lineWidth: 1))
                    }

                    // Countdown progress bar
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.white.opacity(0.08))
                            RoundedRectangle(cornerRadius: 2)
                                .fill(
                                    LinearGradient(
                                        colors: [.red, .orange],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: max(0, min(geo.size.width * CGFloat(model.boostProgress), geo.size.width)))
                                .shadow(color: Color.red.opacity(0.5), radius: 3)
                        }
                    }
                    .frame(height: 4)

                    // Timer duration selector (3 Min, 5 Min, 10 Min)
                    HStack(spacing: 6) {
                        Text("Guard Timer:")
                            .font(.system(size: 9.5))
                            .foregroundColor(.secondary)

                        ForEach([3, 5, 10], id: \.self) { mins in
                            Button(action: { model.startBoostTimer(minutes: mins) }) {
                                Text("\(mins)m")
                                    .font(.system(size: 9.5, weight: model.boostTimerDurationMinutes == mins ? .heavy : .semibold))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(
                                        RoundedRectangle(cornerRadius: 5)
                                            .fill(model.boostTimerDurationMinutes == mins ? Color.red : Color.white.opacity(0.08))
                                    )
                                    .foregroundColor(model.boostTimerDurationMinutes == mins ? .white : .secondary)
                            }
                            .buttonStyle(.plain)
                        }

                        Spacer()

                        Button(action: { model.resetTo100() }) {
                            HStack(spacing: 3) {
                                Image(systemName: "arrow.counterclockwise")
                                    .font(.system(size: 8, weight: .bold))
                                Text("Reset to 100%")
                                    .font(.system(size: 9.5, weight: .bold))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(Color.red.opacity(0.35)))
                            .overlay(Capsule().stroke(Color.red.opacity(0.7), lineWidth: 0.8))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 9)
                        .fill(Color.red.opacity(0.12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 9)
                                .stroke(Color.red.opacity(0.45), lineWidth: 1)
                        )
                )
            }

            // STUDIO HIGH-PRECISION AUDIO VISUALIZER & DUAL LED RACK
            VStack(spacing: 8) {
                // Visualizer Top Bar: Engine Status & Limiter Badge
                HStack(alignment: .center) {
                    HStack(spacing: 5) {
                        Circle()
                            .fill(model.isChannelActive ? Color.green : Color.secondary.opacity(0.4))
                            .frame(width: 6, height: 6)
                            .shadow(color: model.isChannelActive ? .green : .clear, radius: 4)
                        Text(model.isChannelActive ? "STEREO ENGINE LIVE" : "STEREO STANDBY")
                            .font(.system(size: 8.5, weight: .heavy, design: .monospaced))
                            .foregroundColor(model.isChannelActive ? .green : .secondary)

                        Text("•")
                            .font(.system(size: 8))
                            .foregroundColor(.secondary.opacity(0.5))

                        Text(model.deviceManager.currentDeviceName)
                            .font(.system(size: 8.5, weight: .semibold))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }

                    Spacer()

                    // Pro Safety Status Badge
                    safetyBadgeView
                }

                // dB Scale Ruler
                VUDbScaleRuler()

                // Channel Left (CH 1 • L)
                ProSegmentedVUMeterRow(
                    channel: "L",
                    level: model.peakLeft,
                    peakHold: model.peakHoldLeft,
                    dbText: model.channel1DbString,
                    isClipping: model.isClippingLeft,
                    isActive: model.isChannelActive
                )

                // Channel Right (CH 2 • R)
                ProSegmentedVUMeterRow(
                    channel: "R",
                    level: model.peakRight,
                    peakHold: model.peakHoldRight,
                    dbText: model.channel2DbString,
                    isClipping: model.isClippingRight,
                    isActive: model.isChannelActive
                )

                // Dynamic 16-Band Real-Time Spectrum Analyzer
                MultiBandAudioSpectrumView(
                    bands: model.spectrumLevels,
                    isActive: model.isChannelActive
                )
                .padding(.top, 2)

                // Bottom Info Strip: Currently Playing App / Track Name + 55Hz Guard
                HStack(spacing: 6) {
                    if appDetector.anyAppPlaying {
                        HStack(spacing: 4) {
                            EqualizerWaveView(isPlaying: true, color: .green)
                            Text(appDetector.activeAudioSourceTitle)
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundColor(.cyan)
                                .lineLimit(1)
                        }
                    } else {
                        HStack(spacing: 4) {
                            Image(systemName: "headphones")
                                .font(.system(size: 8.5))
                                .foregroundColor(.secondary)
                            Text("Direct 24-bit / 48kHz Output Bus")
                                .font(.system(size: 8.5))
                                .foregroundColor(.secondary.opacity(0.7))
                        }
                    }

                    Spacer()

                    // 55Hz HPF Quick Toggle
                    Toggle(isOn: $model.speakerProtection) {
                        Text("55Hz Guard")
                            .font(.system(size: 8.5, weight: .semibold))
                            .foregroundColor(.secondary)
                    }
                    .toggleStyle(.checkbox)
                }
                .padding(.top, 2)
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.black.opacity(0.40))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.cyan.opacity(0.35),
                                        Color.purple.opacity(0.20),
                                        Color.white.opacity(0.06)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.0
                            )
                    )
            )
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(white: 0.12).opacity(0.45))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(
                            LinearGradient(
                                colors: [Color.white.opacity(0.18), Color.white.opacity(0.05)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
    }

    // MARK: - Tab 1: Per-App Audio Routing Card (Direct Response to User Request)
    private var perAppMixerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Per-App Audio Routing")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text("Live activity, volume & stereo balance per app")
                        .font(.system(size: 9.5))
                        .foregroundColor(.secondary)
                }

                Spacer()

                Text("\(appDetector.apps.count) Apps Active")
                    .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.white.opacity(0.08)))
            }

            VStack(spacing: 10) {
                ForEach(appDetector.apps) { track in
                    appRow(track: track)
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(white: 0.12).opacity(0.45))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(
                            LinearGradient(
                                colors: [Color.white.opacity(0.18), Color.white.opacity(0.05)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
    }

    private func appRow(track: DiscoveredAudioApp) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            // App Header Row: Icon, Title, [RED BOX AREA: Sound Activity & Media/Tab Detail & Destination], Mute, Volume %
            HStack(spacing: 8) {
                // App Icon
                if let icon = track.icon {
                    Image(nsImage: icon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 22, height: 22)
                        .cornerRadius(5)
                } else {
                    ZStack {
                        RoundedRectangle(cornerRadius: 5)
                            .fill(Color.cyan.opacity(0.2))
                            .frame(width: 22, height: 22)
                        Image(systemName: "music.note")
                            .font(.system(size: 11))
                            .foregroundColor(.cyan)
                    }
                }

                // App Name
                Text(track.name)
                    .font(.system(size: 11.5, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)

                // THE USER'S RED BOX AREA: Live Sound Status, Playing/Tab Detail, and Output Destination ("מי יוצא מאיפה")
                HStack(spacing: 5) {
                    // Sound Activity Indicator
                    if track.isPlaying {
                        HStack(spacing: 3) {
                            EqualizerWaveView(isPlaying: true, color: .green)
                            Text("ACTIVE")
                                .font(.system(size: 7.5, weight: .heavy, design: .monospaced))
                                .foregroundColor(.green)
                        }
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.green.opacity(0.18)))
                        .overlay(Capsule().stroke(Color.green.opacity(0.4), lineWidth: 0.8))
                    }

                    // Playing track or Tab title
                    if let detail = track.detailText, !detail.isEmpty {
                        Text(detail)
                            .font(.system(size: 9.5, weight: .medium))
                            .foregroundColor(track.isPlaying ? .cyan : .secondary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }

                    Spacer(minLength: 2)

                    // Output Route ("מי יוצא מאיפה")
                    HStack(spacing: 3) {
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.system(size: 7.5))
                            .foregroundColor(.cyan)
                        Text(track.outputDestination)
                            .font(.system(size: 8, weight: .medium))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.white.opacity(0.06)))
                }
                .padding(.horizontal, 4)
                .frame(maxWidth: .infinity, alignment: .leading)

                // Call Stream Pill
                if model.shareMusicInCall {
                    Button(action: { appDetector.toggleCallShare(for: track.id) }) {
                        Text(track.isSharedToCall ? "In Call" : "+ Call")
                            .font(.system(size: 8.5, weight: .bold))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(track.isSharedToCall ? Color.cyan.opacity(0.3) : Color.white.opacity(0.08))
                            )
                            .foregroundColor(track.isSharedToCall ? .cyan : .secondary)
                    }
                    .buttonStyle(.plain)
                }

                // Mute Button
                Button(action: { appDetector.toggleMute(for: track.id) }) {
                    Image(systemName: track.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                        .font(.system(size: 11))
                        .foregroundColor(track.isMuted ? .red : (track.isPlaying ? .cyan : .secondary))
                        .frame(width: 22, height: 22)
                        .background(
                            Circle()
                                .fill(track.isMuted ? Color.red.opacity(0.15) : Color.white.opacity(0.06))
                        )
                }
                .buttonStyle(.plain)

                // Volume % Readout
                Text("\(Int(round(track.volume * 100)))%")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(track.volume > 1.0 ? .orange : .white)
                    .frame(width: 36, alignment: .trailing)
            }

            // Sliders & Live Channel Stereo VU Meters
            HStack(spacing: 8) {
                // Live Stereo Channel Level Bars right next to slider
                VStack(spacing: 2) {
                    HStack(spacing: 2) {
                        Text("L")
                            .font(.system(size: 7, weight: .bold, design: .monospaced))
                            .foregroundColor(track.isPlaying && !track.isMuted ? .cyan : .secondary)
                        AppMiniVUBar(level: track.activityLevelL, isPlaying: track.isPlaying && !track.isMuted)
                    }
                    HStack(spacing: 2) {
                        Text("R")
                            .font(.system(size: 7, weight: .bold, design: .monospaced))
                            .foregroundColor(track.isPlaying && !track.isMuted ? .cyan : .secondary)
                        AppMiniVUBar(level: track.activityLevelR, isPlaying: track.isPlaying && !track.isMuted)
                    }
                }
                .frame(width: 48)

                // App Volume Slider
                Slider(value: Binding(
                    get: { track.volume },
                    set: { appDetector.setVolume(for: track.id, volume: $0) }
                ), in: 0.0...2.0)
                .opacity(track.isMuted ? 0.35 : 1.0)
                .accentColor(track.volume > 1.0 ? .orange : .cyan)

                // Panning Slider
                HStack(spacing: 2) {
                    Text("L")
                        .font(.system(size: 7.5, weight: .bold))
                        .foregroundColor(.secondary)
                    Slider(value: Binding(
                        get: { track.pan },
                        set: { appDetector.setPan(for: track.id, pan: $0) }
                    ), in: -1.0...1.0)
                    .frame(width: 44)
                    Text("R")
                        .font(.system(size: 7.5, weight: .bold))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(track.isPlaying ? Color.cyan.opacity(0.35) : Color.white.opacity(0.06), lineWidth: 0.8)
                )
        )
    }

    // MARK: - Tab 2: 10-Band Equalizer Card
    private var equalizerCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text("10-Band Graphic Equalizer")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text("Pro-grade biquad peak & shelving filters")
                        .font(.system(size: 9.5))
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button("Reset Flat") {
                    equalizer.resetToFlat()
                }
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.cyan)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Capsule().fill(Color.cyan.opacity(0.15)))
                .buttonStyle(.plain)
            }

            // 10 Vertical Sliders
            HStack(spacing: 4) {
                ForEach(equalizer.bands) { band in
                    VStack(spacing: 4) {
                        Text(String(format: "%+.0f", band.gainDb))
                            .font(.system(size: 8, weight: .bold, design: .monospaced))
                            .foregroundColor(band.gainDb == 0 ? .secondary : (band.gainDb > 0 ? .cyan : .orange))

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
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(white: 0.12).opacity(0.45))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
        )
    }

    // MARK: - Tab 2: Acoustic Presets Card
    private var presetsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Acoustic Presets")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundColor(.white)

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
                                .foregroundColor(model.activePreset == preset ? .black : .white)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Text(model.activePreset.description)
                .font(.system(size: 9.5))
                .foregroundColor(.secondary)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(white: 0.12).opacity(0.45))
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
                    .foregroundColor(.white)
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
                        .foregroundColor(.cyan)
                        .frame(width: 44, alignment: .trailing)
                }
                .padding(.top, 4)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(white: 0.12).opacity(0.45))
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
                    .foregroundColor(.white)
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
                                    .foregroundColor(dev.isDefault ? .white : .secondary)
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
                                .fill(dev.isDefault ? Color.cyan.opacity(0.12) : Color.white.opacity(0.04))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(white: 0.12).opacity(0.45))
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
                    .foregroundColor(.white)
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
                                .foregroundColor(.white)
                        }
                        .toggleStyle(.checkbox)

                        Spacer()

                        HStack(spacing: 4) {
                            Circle()
                                .fill(vad.isSpeaking ? Color.green : Color.secondary.opacity(0.4))
                                .frame(width: 6, height: 6)
                            Text(vad.isSpeaking ? "Speaking" : "Quiet")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(vad.isSpeaking ? .green : .secondary)
                        }
                    }
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(white: 0.12).opacity(0.45))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }

    // MARK: - Safety Badge View
    private var safetyBadgeView: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(safetyColor)
                .frame(width: 5, height: 5)
            Text(safetyText)
                .font(.system(size: 8, weight: .heavy, design: .monospaced))
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
        if val > 1.0 { return .red }
        return .cyan
    }

    private func isCurrentPreset(_ val: Float) -> Bool {
        return abs(model.masterBoost - val) < 0.03
    }

    private func presetButton(value: Float, label: String, isBoost: Bool = false) -> some View {
        let active = isCurrentPreset(value)
        let weight: Font.Weight = active ? .heavy : (isBoost ? .bold : .medium)

        let fillColor: Color
        let strokeColor: Color
        let textColor: Color

        if isBoost {
            fillColor = active ? Color.red : Color.red.opacity(0.18)
            strokeColor = active ? Color.red : Color.red.opacity(0.55)
            textColor = active ? .white : Color.red
        } else {
            fillColor = active ? Color.cyan.opacity(0.85) : Color.white.opacity(0.07)
            strokeColor = active ? Color.cyan : Color.white.opacity(0.1)
            textColor = active ? .black : .white
        }

        return Button(action: { model.setBoost(to: value) }) {
            Text(label)
                .font(.system(size: 10, weight: weight))
                .frame(maxWidth: .infinity)
                .frame(height: 26)
                .background(RoundedRectangle(cornerRadius: 6).fill(fillColor))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(strokeColor, lineWidth: isBoost ? 1.0 : 0.8))
                .foregroundColor(textColor)
                .shadow(color: (active && isBoost) ? Color.red.opacity(0.6) : .clear, radius: 4)
        }
        .buttonStyle(.plain)
        .help("Set volume to \(label)\(isBoost ? " (Overdrive Red Zone)" : "")")
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

// MARK: - Helper Views: Animated Equalizer Wave
public struct EqualizerWaveView: View {
    @State private var phase: CGFloat = 0.0
    var isPlaying: Bool
    var color: Color = .green

    public var body: some View {
        HStack(spacing: 1.5) {
            ForEach(0..<4) { i in
                RoundedRectangle(cornerRadius: 1)
                    .fill(isPlaying ? color : Color.white.opacity(0.25))
                    .frame(width: 2, height: isPlaying ? barHeight(for: i) : 3)
            }
        }
        .frame(height: 11)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.35).repeatForever(autoreverses: true)) {
                phase = 1.0
            }
        }
    }

    private func barHeight(for index: Int) -> CGFloat {
        let pattern: [CGFloat] = [
            phase == 0.0 ? 3 : 11,
            phase == 0.0 ? 9 : 4,
            phase == 0.0 ? 5 : 10,
            phase == 0.0 ? 10 : 3
        ]
        return pattern[index % pattern.count]
    }
}

// MARK: - Helper Views: Pro Audio dB Scale Ruler
public struct VUDbScaleRuler: View {
    public var body: some View {
        HStack(spacing: 0) {
            Spacer().frame(width: 30)

            HStack {
                Text("-48")
                Spacer()
                Text("-24")
                Spacer()
                Text("-18")
                Spacer()
                Text("-12")
                Spacer()
                Text("-6")
                Spacer()
                Text("-3")
                Spacer()
                Text("0dB")
                    .foregroundColor(Color.yellow)
                Spacer()
                Text("+3")
                    .foregroundColor(Color.red)
            }
            .font(.system(size: 7.5, weight: .heavy, design: .monospaced))
            .foregroundColor(Color.secondary.opacity(0.8))

            Spacer().frame(width: 48)
        }
    }
}

// MARK: - Helper Views: Pro Segmented LED VU Meter Row
public struct ProSegmentedVUMeterRow: View {
    let channel: String // "L" or "R"
    let level: Float // 0.0 to 1.0
    let peakHold: Float // 0.0 to 1.0
    let dbText: String
    let isClipping: Bool
    let isActive: Bool

    private let totalSegments: Int = 26

    public var body: some View {
        HStack(spacing: 8) {
            // Channel Badge (e.g. [ L ] or [ R ])
            ZStack {
                RoundedRectangle(cornerRadius: 4)
                    .fill(isActive ? Color.cyan.opacity(0.18) : Color.white.opacity(0.06))
                RoundedRectangle(cornerRadius: 4)
                    .stroke(isActive ? Color.cyan.opacity(0.6) : Color.white.opacity(0.12), lineWidth: 0.8)
                Text(channel)
                    .font(.system(size: 9.5, weight: .heavy, design: .monospaced))
                    .foregroundColor(isActive ? .cyan : .secondary)
            }
            .frame(width: 22, height: 16)

            // Segmented LED Grid
            GeometryReader { geo in
                let spacing: CGFloat = 2.0
                let totalSpacing = spacing * CGFloat(totalSegments - 1)
                let segWidth = max(2.0, (geo.size.width - totalSpacing) / CGFloat(totalSegments))
                let activeCount = Int(round(CGFloat(totalSegments) * CGFloat(max(0.0, min(1.0, level)))))
                let peakHoldIndex = Int(round(CGFloat(totalSegments - 1) * CGFloat(max(0.0, min(1.0, peakHold)))))

                HStack(spacing: spacing) {
                    ForEach(0..<totalSegments, id: \.self) { idx in
                        let isLit = isActive && (idx < activeCount)
                        let isPeakHold = isActive && (idx == peakHoldIndex) && (idx >= activeCount)
                        let segColor = colorForSegment(idx)
                        let cellFill = isLit ? segColor : (isPeakHold ? Color.white : Color.white.opacity(0.07))
                        let glowColor = isLit ? segColor.opacity(idx >= 22 ? 0.8 : 0.4) : (isPeakHold ? Color.white.opacity(0.6) : Color.clear)

                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(cellFill)
                            .frame(width: segWidth, height: 14)
                            .shadow(color: glowColor, radius: isLit ? 2 : 1)
                    }
                }
            }
            .frame(height: 14)

            // Numerical dB Readout
            HStack(spacing: 2) {
                if isClipping {
                    Text("CLIP")
                        .font(.system(size: 7.5, weight: .black, design: .monospaced))
                        .foregroundColor(.red)
                        .padding(.horizontal, 3)
                        .padding(.vertical, 1)
                        .background(Capsule().fill(Color.red.opacity(0.25)))
                }
                Text(dbText)
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(isClipping ? .red : (isActive ? (level > 0.8 ? .orange : .white) : .secondary.opacity(0.6)))
                    .frame(width: 44, alignment: .trailing)
            }
        }
    }

    private func colorForSegment(_ idx: Int) -> Color {
        if idx >= 23 {
            return Color(red: 1.0, green: 0.22, blue: 0.22) // Clip Red
        } else if idx >= 19 {
            return Color(red: 1.0, green: 0.65, blue: 0.15) // Warning Amber
        } else if idx >= 14 {
            return Color(red: 0.15, green: 0.88, blue: 0.95) // Dynamic Cyan
        } else {
            return Color(red: 0.18, green: 0.95, blue: 0.45) // Safe Green
        }
    }
}

// MARK: - Helper Views: Multi-Band Audio Spectrum Visualizer
public struct MultiBandAudioSpectrumView: View {
    let bands: [Float] // 16 normalized values
    let isActive: Bool

    public var body: some View {
        VStack(spacing: 3) {
            GeometryReader { geo in
                let spacing: CGFloat = 3.0
                let count = max(bands.count, 1)
                let totalSpacing = spacing * CGFloat(count - 1)
                let barWidth = max(3.0, (geo.size.width - totalSpacing) / CGFloat(count))
                let maxHeight = geo.size.height

                HStack(alignment: .bottom, spacing: spacing) {
                    ForEach(0..<count, id: \.self) { idx in
                        let val = bands.indices.contains(idx) ? bands[idx] : 0.05
                        let barHeight = max(4.0, CGFloat(val) * maxHeight)

                        VStack(spacing: 1.5) {
                            if isActive && val > 0.2 {
                                RoundedRectangle(cornerRadius: 1)
                                    .fill(idx >= 12 ? Color.red : (idx >= 8 ? Color.orange : Color.cyan))
                                    .frame(width: barWidth, height: 2)
                                    .shadow(color: Color.cyan.opacity(0.5), radius: 2)
                            }

                            RoundedRectangle(cornerRadius: 2)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            idx >= 13 ? Color.red : (idx >= 9 ? Color.orange : Color.cyan),
                                            Color.purple.opacity(0.85),
                                            Color.blue.opacity(0.7)
                                        ],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .frame(width: barWidth, height: barHeight)
                                .shadow(color: isActive ? Color.cyan.opacity(0.3) : .clear, radius: 2)
                        }
                        .frame(height: maxHeight, alignment: .bottom)
                    }
                }
            }
            .frame(height: 38)

            HStack {
                Text("32Hz")
                Spacer()
                Text("125Hz")
                Spacer()
                Text("500Hz")
                Spacer()
                Text("2kHz")
                Spacer()
                Text("8kHz")
                Spacer()
                Text("16kHz")
            }
            .font(.system(size: 7, weight: .bold, design: .monospaced))
            .foregroundColor(Color.secondary.opacity(0.7))
        }
    }
}

// MARK: - Helper Views: Mini App VU Bar
public struct AppMiniVUBar: View {
    let level: Float
    let isPlaying: Bool

    public var body: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 1.5)
                .fill(Color.white.opacity(0.08))
                .frame(width: 32, height: 3.5)

            if isPlaying && level > 0 {
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(
                        LinearGradient(
                            colors: [.green, .cyan],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(2, min(CGFloat(level) * 32, 32)), height: 3.5)
            }
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
