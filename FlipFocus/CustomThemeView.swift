import SwiftUI

struct CustomThemeView: View {
    @ObservedObject var stopwatch: StopwatchManager
    let theme: CustomTheme
    
    private var settings: CustomThemeSettings { theme.settings }
    private var isLight: Bool { settings.isLightMode }
    private var textColor: Color { isLight ? .black : .white }
    private var subtleColor: Color { isLight ? Color.black.opacity(0.35) : Color.white.opacity(0.35) }
    private var accentColor: Color { settings.color(for: settings.mainAccentColor) }

    var body: some View {
        VStack(spacing: 0) {
            if stopwatch.showBreakSelection {
                minimalSliderView
            } else {
                minimalTimerView
            }
        }
    }

    // MARK: - Timer View
    private var minimalTimerView: some View {
        let active = stopwatch.isBreakActive ? stopwatch.breakTime : stopwatch.elapsedTime
        let hours   = Int(active / 3600)
        let minutes = Int(active / 60) % 60
        let seconds = Int(active) % 60
        let fraction = Int((active.truncatingRemainder(dividingBy: 1)) * 10)

        return VStack(spacing: 0) {
            Spacer()

            // State badge
            HStack(spacing: 8) {
                Circle()
                    .fill(accentColor)
                    .frame(width: 7, height: 7)
                Text(stopwatch.isBreakActive ? "Break" : (stopwatch.isRunning ? "Focus" : "Paused"))
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(accentColor)
                    .tracking(0.5)
            }
            .padding(.bottom, 24)

            // Main time digits
            HStack(alignment: .lastTextBaseline, spacing: 0) {
                if hours > 0 {
                    timeBlock(value: hours, unit: "h")
                    Text("  ")
                }
                timeBlock(value: minutes, unit: "m")
                Text("  ")
                timeBlock(value: seconds, unit: "s")
                Text(".\(fraction)")
                    .font(.system(size: 28, weight: .light))
                    .foregroundColor(subtleColor)
                    .padding(.bottom, 6)
            }
            .padding(.horizontal, 32)

            Spacer().frame(height: 40)

            // Triple progress rings with custom colors
            ZStack {
                // Seconds (Outer)
                singleRing(progress: (active / 60).truncatingRemainder(dividingBy: 1.0), 
                           color: settings.color(for: settings.ringColorSeconds), thickness: 3, radius: 110)
                // Minutes (Middle)
                singleRing(progress: (active / 3600).truncatingRemainder(dividingBy: 1.0), 
                           color: settings.color(for: settings.ringColorMinutes), thickness: 3, radius: 95)
                // Hours (Inner)
                singleRing(progress: (active / 43200).truncatingRemainder(dividingBy: 1.0), 
                           color: settings.color(for: settings.ringColorHours), thickness: 3, radius: 80)
            }
            .frame(width: 240, height: 240)

            Spacer()
        }
    }

    private func timeBlock(value: Int, unit: String) -> some View {
        HStack(alignment: .lastTextBaseline, spacing: 2) {
            Text(String(format: "%02d", value))
                .font(.system(size: 72, weight: .thin))
                .foregroundColor(textColor)
                .monospacedDigit()
            Text(unit)
                .font(.system(size: 16, weight: .regular))
                .foregroundColor(subtleColor)
                .padding(.bottom, 10)
        }
    }

    private func singleRing(progress: Double, color: Color, thickness: CGFloat, radius: CGFloat) -> some View {
        ZStack {
            Circle()
                .stroke(textColor.opacity(0.1), lineWidth: thickness)
                .frame(width: radius * 2, height: radius * 2)
            Circle()
                .trim(from: 0, to: CGFloat(progress))
                .stroke(color, style: StrokeStyle(lineWidth: thickness + 1, lineCap: .round))
                .frame(width: radius * 2, height: radius * 2)
                .rotationEffect(.degrees(-90))
        }
    }

    // MARK: - Break Selector
    private var minimalSliderView: some View {
        let sliderMax = max(30.0, stopwatch.maxEarnedMinutes * 1.5)
        let breakColor = accentColor

        return VStack(spacing: 0) {
            HStack {
                Button(action: { 
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                        stopwatch.showBreakSelection = false 
                    }
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(subtleColor)
                        .padding(24)
                }
                Spacer()
            }
            
            Spacer()
            VStack(spacing: 6) {
                Text("\(Int(stopwatch.dialedBreakMinutes))")
                    .font(.system(size: 100, weight: .thin))
                    .foregroundColor(textColor)
                Text("minutes").font(.system(size: 14)).foregroundColor(subtleColor)
            }
            .padding(.bottom, 52)

            GeometryReader { geo in
                let trackW = geo.size.width - 48
                let pct = CGFloat(stopwatch.dialedBreakMinutes / sliderMax).clamped(to: 0...1)
                ZStack(alignment: .leading) {
                    Capsule().fill(textColor.opacity(0.1)).frame(height: 4).padding(.horizontal, 24)
                    Capsule().fill(breakColor).frame(width: max(8, trackW * pct), height: 4).padding(.leading, 24)
                    Circle().fill(breakColor).frame(width: 24, height: 24)
                        .position(x: 24 + trackW * pct, y: geo.size.height / 2)
                }
                .gesture(DragGesture(minimumDistance: 0).onChanged { v in
                    let pct = ((v.location.x - 24) / trackW).clamped(to: 0...1)
                    stopwatch.dialedBreakMinutes = round(Double(pct) * sliderMax)
                })
            }
            .frame(height: 40).padding(.bottom, 44)

            Button(action: { stopwatch.startBreak() }) {
                Text("Start Break")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(isLight ? .white : .black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(RoundedRectangle(cornerRadius: 16).fill(textColor))
            }
            .padding(.horizontal, 32)
            Spacer()
        }
    }
}

private extension CGFloat {
    func clamped(to range: ClosedRange<CGFloat>) -> CGFloat {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
