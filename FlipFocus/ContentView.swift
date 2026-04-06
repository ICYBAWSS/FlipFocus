import SwiftUI

struct ContentView: View {
    @StateObject private var stopwatch = StopwatchManager()
    @State private var showingThemeMenu = false
    @State private var showingIntelMenu = false
    @State private var showingStreakMenu = false
    
    private let primaryGradient = LinearGradient(
        colors: [Color(red: 168/255, green: 85/255, blue: 247/255), Color(red: 236/255, green: 72/255, blue: 153/255)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    var body: some View {
        ZStack {
            // Theme-aware background
            themeBackgroundColor
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Top Toolbar
                HStack(spacing: 16) {
                    Spacer()
                    MenuButton(icon: "paintpalette", theme: stopwatch.themeManager.currentTheme, action: { showingThemeMenu = true })
                    MenuButton(icon: "chart.bar.xaxis", theme: stopwatch.themeManager.currentTheme, action: { showingIntelMenu = true })
                    MenuButton(icon: "flame", theme: stopwatch.themeManager.currentTheme, action: { showingStreakMenu = true })
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)

                Spacer()
                
                // Theme Content
                Group {
                    switch stopwatch.themeManager.currentTheme {
                    case .ascii, .asciiLight:
                        AsciiThemeView(stopwatch: stopwatch)
                    case .minimal, .minimalLight:
                        MinimalThemeView(stopwatch: stopwatch)
                    case .nature:
                        NatureThemeView(stopwatch: stopwatch)
                    case .torus:
                        TorusThemeView(stopwatch: stopwatch)
                    }
                }
                
                Spacer()
                
                // Bottom Controls/Options
                VStack(spacing: 24) {
                    if !stopwatch.showBreakSelection {
                        if !stopwatch.isRunning && !stopwatch.isBreakActive && stopwatch.elapsedTime > 0 {
                            VStack(spacing: 16) {
                                Text("SHAKE TO START BREAK")
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                    .foregroundColor(stopwatch.themeManager.currentTheme == .torus ? .blue : (stopwatch.themeManager.currentTheme.isLight ? .blue : Color.blue.opacity(0.5)))
                                
                                Button(action: {
                                    stopwatch.reset()
                                }) {
                                    Text("RESET SESSION")
                                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                                        .foregroundColor(stopwatch.themeManager.currentTheme.isLight ? .gray : Color(white: 0.3))
                                }
                            }
                        } else if !stopwatch.isRunning && !stopwatch.isBreakActive {
                            Text("PUT FACE DOWN TO START FOCUS")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundColor(stopwatch.themeManager.currentTheme.isLight ? .gray.opacity(0.5) : Color(white: 0.25))
                        }
                    }
                }
                .padding(.bottom, 60)
                
                // DEBUG CONTROLS
                HStack(spacing: 20) {
                    Button(action: {
                        stopwatch.elapsedTime += 600 // +10 mins
                    }) {
                        Text("DEBUG: +10M")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(stopwatch.themeManager.currentTheme.isLight ? .black.opacity(0.2) : .white.opacity(0.2))
                    }
                    
                    Button(action: {
                        NotificationCenter.default.post(name: .deviceDidShake, object: nil)
                    }) {
                        Text("DEBUG: SHAKE")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(stopwatch.themeManager.currentTheme.isLight ? .black.opacity(0.2) : .white.opacity(0.2))
                    }
                }
                .padding(.bottom, 20)
            }
        }
        .onAppear {
            stopwatch.activate()
        }
        .sheet(isPresented: $showingThemeMenu) {
            ThemeMenuView(stopwatch: stopwatch)
        }
        .sheet(isPresented: $showingIntelMenu) {
            IntelMenuView(stopwatch: stopwatch)
        }
        .sheet(isPresented: $showingStreakMenu) {
            StreakMenuView(stopwatch: stopwatch)
        }
    }

    private var themeBackgroundColor: Color {
        switch stopwatch.themeManager.currentTheme {
        case .ascii, .minimal, .torus: return .black
        case .asciiLight, .minimalLight: return .white
        case .nature: return Color(red: 0.95, green: 0.98, blue: 1.0)
        }
    }

    
    private func formatMinutesSeconds(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    private func formatTenths(_ time: TimeInterval) -> String {
        let tenths = Int((time.truncatingRemainder(dividingBy: 1)) * 10)
        return String(format: ".%d", tenths)
    }

    private func colorForMinutes(_ mins: Double) -> Color {
        let minEarned = round(stopwatch.minEarnedMinutes)
        let maxEarned = round(stopwatch.maxEarnedMinutes)
        
        if mins < minEarned { return .orange }
        if mins <= maxEarned { return .green }
        return .red
    }
}

struct MenuButton: View {
    let icon: String
    let theme: ThemeType
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(theme.isLight ? .black.opacity(0.4) : .white.opacity(0.4))
                .frame(width: 36, height: 36)
                .background(theme.isLight ? Color.black.opacity(0.05) : Color.white.opacity(0.08))
                .cornerRadius(8)
        }
    }
}

#Preview {
    ContentView()
}
