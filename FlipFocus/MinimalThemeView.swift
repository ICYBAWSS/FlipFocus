import SwiftUI

struct MinimalThemeView: View {
    @ObservedObject var stopwatch: StopwatchManager
    
    private var textColor: Color {
        stopwatch.themeManager.currentTheme.isLight ? .black : .white
    }
    
    var body: some View {
        VStack(spacing: 60) {
            if stopwatch.showBreakSelection {
                minimalSliderView
            } else {
                minimalTimerView
            }
        }
    }
    
    private var minimalTimerView: some View {
        VStack(spacing: 40) {
            let activeElapsed = stopwatch.isBreakActive ? stopwatch.breakTime : stopwatch.elapsedTime
            let h = Int(activeElapsed / 3600)
            let m = Int(activeElapsed / 60) % 60
            let s = Int(activeElapsed) % 60
            
            ZStack {
                // Circular Ring
                Circle()
                    .stroke(textColor.opacity(0.05), lineWidth: 4)
                    .frame(width: 280, height: 280)
                
                Circle()
                    .trim(from: 0, to: CGFloat((activeElapsed.truncatingRemainder(dividingBy: 60)) / 60.0))
                    .stroke(stopwatch.isBreakActive ? .blue : .green, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 280, height: 280)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1.0), value: activeElapsed)
                
                VStack(spacing: -10) {
                    Text(String(format: "%02d:%02d", h, m))
                        .font(.system(size: 80, weight: .thin, design: .rounded))
                    Text(String(format: ":%02d", s))
                        .font(.system(size: 30, weight: .light, design: .rounded))
                        .foregroundColor(textColor.opacity(0.3))
                }
                .foregroundColor(textColor)
            }
            
            Text(stopwatch.isBreakActive ? "BREAKING" : (stopwatch.isRunning ? "FOCUSING" : "PAUSED"))
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundColor(stopwatch.isBreakActive ? .blue : (stopwatch.isRunning ? .green : .orange))
                .kerning(4)
        }
    }
    
    private var minimalSliderView: some View {
        VStack(spacing: 40) {
            VStack(spacing: 8) {
                Text("\(Int(stopwatch.dialedBreakMinutes))")
                    .font(.system(size: 100, weight: .ultraLight, design: .rounded))
                Text("MINUTES EARNED")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(textColor.opacity(0.4))
            }
            .foregroundColor(textColor)
            
            Slider(value: $stopwatch.dialedBreakMinutes, in: 0...max(30, stopwatch.maxEarnedMinutes * 1.5), step: 1)
                .accentColor(colorForMinutes(stopwatch.dialedBreakMinutes))
                .padding(.horizontal, 40)
            
            Button(action: { stopwatch.startBreak() }) {
                Text("START BREAK")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(textColor)
                    .padding(.horizontal, 40)
                    .padding(.vertical, 16)
                    .background(Capsule().stroke(textColor.opacity(0.2), lineWidth: 1))
            }
        }
    }
    
    private func colorForMinutes(_ mins: Double) -> Color {
        let minEarned = round(stopwatch.minEarnedMinutes)
        let maxEarned = round(stopwatch.maxEarnedMinutes)
        if mins < minEarned { return .orange }
        if mins <= maxEarned { return .green }
        return .red
    }
}
