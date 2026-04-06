import SwiftUI

struct ThemeMenuView: View {
    @ObservedObject var stopwatch: StopwatchManager
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        Text("SELECT EXPERIENCE")
                            .font(.system(size: 8, weight: .black, design: .monospaced))
                            .foregroundColor(.white.opacity(0.3))
                            .kerning(1.5)
                            .padding(.horizontal)
                        
                        VStack(spacing: 16) {
                            ForEach(ThemeType.allCases) { theme in
                                ThemePreviewCard(theme: theme, isSelected: stopwatch.themeManager.currentTheme == theme) {
                                    withAnimation {
                                        stopwatch.themeManager.currentTheme = theme
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                        
                        Spacer()
                    }
                    .padding(.top, 20)
                }
            }
            .navigationTitle("THEMES")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("DONE") { dismiss() }
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(.blue)
                }
            }
        }
    }
}

struct ThemePreviewCard: View {
    let theme: ThemeType
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 20) {
                // Mini Preview Circle
                ZStack {
                    Circle()
                        .fill(previewBg)
                        .frame(width: 50, height: 50)
                        .overlay(Circle().stroke(Color.white.opacity(0.1), lineWidth: 1))
                    
                    previewIcon
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(theme.rawValue)
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                    
                    Text(themeDescription)
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(.white.opacity(0.4))
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.blue)
                }
            }
            .padding()
            .background(isSelected ? Color.white.opacity(0.1) : Color.white.opacity(0.03))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.blue.opacity(0.5) : Color.clear, lineWidth: 1)
            )
        }
    }
    
    private var previewBg: Color {
        switch theme {
        case .ascii, .minimal, .torus: return .black
        case .asciiLight, .minimalLight: return .white
        case .nature: return Color(red: 0.9, green: 0.95, blue: 1.0)
        }
    }
    
    @ViewBuilder
    private var previewIcon: some View {
        switch theme {
        case .ascii, .asciiLight:
            Text("@").font(.system(size: 20, weight: .bold, design: .monospaced)).foregroundColor(theme.isLight ? .black : .white)
        case .minimal, .minimalLight:
            Circle().stroke(theme.isLight ? Color.black : Color.white, lineWidth: 2).frame(width: 20, height: 20)
        case .nature:
            Image(systemName: "leaf.fill").foregroundColor(.green)
        case .torus:
            Text("O").font(.system(size: 24, weight: .bold, design: .serif)).foregroundColor(.blue)
        }
    }
    
    private var themeDescription: String {
        switch theme {
        case .ascii: return "Lo-fi hacker aesthetic"
        case .asciiLight: return "Clean paper-like code"
        case .minimal: return "Pure focus, no noise"
        case .minimalLight: return "Bright & airy simplicity"
        case .nature: return "Flowing rivers & mountains"
        case .torus: return "Deep 3D ASCII geometry"
        }
    }
}
