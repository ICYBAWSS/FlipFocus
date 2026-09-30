import SwiftUI

struct ContentView: View {
    @StateObject private var stopwatch = StopwatchManager()
    @State private var showingThemeMenu = false
    @State private var showingIntelMenu = false
    @State private var showingStreakMenu = false
    @State private var showingSettingsMenu = false
    @State private var debugHidden = false

    var body: some View {
        VStack(spacing: 0) {
            // 1. TOP TOOLBAR (Inside Safe Area)
            HStack {
                Spacer()
                Menu {
                    Button(action: { showingThemeMenu = true }) {
                        Label("Theme", systemImage: "paintpalette.fill")
                    }
                    Button(action: { showingIntelMenu = true }) {
                        Label("Stats", systemImage: "chart.bar.fill")
                    }
                    Button(action: { showingStreakMenu = true }) {
                        Label("Streaks", systemImage: "flame.fill")
                    }
                    Divider()
                    Button(action: { showingSettingsMenu = true }) {
                        Label("Settings", systemImage: "gearshape.fill")
                    }
                } label: {
                    Image(systemName: "line.3.horizontal")
                        .font(helvetica(18, .semibold))
                        .foregroundColor(isLightMode ? .black.opacity(0.8) : .white.opacity(0.9))
                        .frame(width: 44, height: 44)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(.ultraThinMaterial)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .strokeBorder(
                                            isLightMode ? Color.black.opacity(0.1) : Color.white.opacity(0.2),
                                            lineWidth: 0.75
                                        )
                                )
                        )
                        .contentShape(Rectangle())
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)

            // 2. MAIN CONTENT LAYER
            Group {
                if let customID = stopwatch.themeManager.selectedCustomThemeID,
                   let customTheme = stopwatch.themeManager.customThemes.first(where: { $0.id == customID }) {
                    CustomThemeView(stopwatch: stopwatch, theme: customTheme)
                } else {
                    switch stopwatch.themeManager.currentTheme ?? .ascii {
                    case .ascii, .asciiLight:
                        AsciiThemeView(stopwatch: stopwatch)
                    case .minimal, .minimalLight:
                        MinimalThemeView(stopwatch: stopwatch)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // 3. FOOTER HINTS
            VStack(spacing: 16) {
                if !stopwatch.showBreakSelection {
                    if !stopwatch.isRunning && !stopwatch.isBreakActive && stopwatch.elapsedTime > 0 {
                        VStack(spacing: 12) {
                            hintLabel("Shake to start a break")
                            Button(action: { stopwatch.reset() }) {
                                Text("Reset session")
                                    .font(helvetica(12, .regular))
                                    .foregroundColor(isLightMode ? .gray : Color(white: 0.35))
                            }
                        }
                    } else if stopwatch.isBreakActive {
                        hintLabel("Flip face down to end break")
                    } else if !stopwatch.isRunning {
                        hintLabel("Place face down to start focus")
                    }
                }
            }
            .frame(height: 60)
            .padding(.bottom, 30)

            #if targetEnvironment(simulator)
            if !debugHidden { simulatorDebugStrip }
            #endif
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            // BACKGROUND LAYER
            ZStack {
                themeBackgroundColor.ignoresSafeArea()
                
                if let settings = stopwatch.themeManager.activeSettings,
                   let fileName = settings.backgroundImageFileName,
                   let uiImage = loadCustomImage(named: fileName) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .ignoresSafeArea()
                        .clipped()
                        .overlay(Color.black.opacity(isLightMode ? 0.05 : 0.4))
                }
            }
            .ignoresSafeArea()
        }
        .onAppear { stopwatch.activate() }
        .sheet(isPresented: $showingThemeMenu) {
            ThemeMenuView(stopwatch: stopwatch)
                .presentationDetents([.large])
                .presentationBackground(.ultraThinMaterial)
                .presentationCornerRadius(28)
        }
        .sheet(isPresented: $showingIntelMenu) {
            IntelMenuView(stopwatch: stopwatch)
                .presentationDetents([.large])
                .presentationBackground(.ultraThinMaterial)
                .presentationCornerRadius(28)
        }
        .sheet(isPresented: $showingStreakMenu) {
            StreakMenuView(stopwatch: stopwatch)
                .presentationDetents([.large])
                .presentationBackground(.ultraThinMaterial)
                .presentationCornerRadius(28)
        }
        .sheet(isPresented: $showingSettingsMenu) {
            SettingsMenuView(stopwatch: stopwatch)
                .presentationDetents([.large])
                .presentationBackground(.ultraThinMaterial)
                .presentationCornerRadius(28)
        }
        .overlay {
            // Battery Save Mode Overlay
            if stopwatch.isBatterySaveModeEnabled && stopwatch.gravityZ > 0.8 {
                Color.black
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }
        }
    }

    #if targetEnvironment(simulator)
    // No CoreMotion in the Simulator — this stands in for a physical flip/shake so
    // the face-down and shake gated flows are reachable for testing. Never compiled on device.
    private var simulatorDebugStrip: some View {
        HStack(spacing: 6) {
            Button(stopwatch.isRunning ? "Pause" : "Flip") {
                stopwatch.isRunning ? stopwatch.pause() : stopwatch.start()
            }
            Button("Shake") {
                if stopwatch.elapsedTime > 0 && !stopwatch.isRunning && !stopwatch.isBreakActive {
                    withAnimation(.spring()) {
                        stopwatch.showBreakSelection = true
                        stopwatch.dialedBreakMinutes = round(stopwatch.minEarnedMinutes)
                    }
                }
            }
            Button(stopwatch.gravityZ > 0.8 ? "Up" : "Down") {
                stopwatch.gravityZ = stopwatch.gravityZ > 0.8 ? 0.0 : 0.9
            }
            Button("Data") { stopwatch.debugLoadDemoData() }
            Button("+45m") { stopwatch.debugFastForward(45 * 60) }
            // 01:27:43 — every ring lands on a distinct, clearly visible arc.
            Button("Freeze") { stopwatch.debugFreeze(at: 5263) }
            Button("Hide") { debugHidden = true }
        }
        .font(helvetica(10, .semibold))
        .buttonStyle(.bordered)
        .tint(.pink)
        .padding(.bottom, 6)
    }
    #endif

    private func loadCustomImage(named name: String) -> UIImage? {
        let fileManager = FileManager.default
        let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let url = docs.appendingPathComponent(name)
        
        if let data = try? Data(contentsOf: url) {
            return UIImage(data: data)
        }
        return nil
    }

    private var isLightMode: Bool {
        if let settings = stopwatch.themeManager.activeSettings {
            return settings.isLightMode
        }
        return stopwatch.themeManager.currentTheme?.isLight ?? false
    }

    private var themeBackgroundColor: Color {
        if let settings = stopwatch.themeManager.activeSettings {
            return settings.isLightMode ? Color(red: 253/255, green: 251/255, blue: 212/255) : .black
        }
        
        switch stopwatch.themeManager.currentTheme ?? .ascii {
        case .ascii, .minimal:      return .black
        case .asciiLight, .minimalLight: return Color(red: 253/255, green: 251/255, blue: 212/255)
        }
    }

    private func hintLabel(_ text: String) -> some View {
        Text(text)
            .font(helvetica(12, .medium))
            .foregroundColor(isLightMode
                ? .black.opacity(0.3)
                : .white.opacity(0.3))
            .tracking(0.5)
    }
}

#Preview {
    ContentView()
}
