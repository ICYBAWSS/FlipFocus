import SwiftUI

struct MinimalThemeView: View {
    @ObservedObject var stopwatch: StopwatchManager

    private var isLight: Bool { stopwatch.themeManager.currentTheme?.isLight ?? false }
    private var textColor: Color { isLight ? .black : .white }
    private var subtleColor: Color { isLight ? Color.black.opacity(0.25) : Color.white.opacity(0.25) }

    private var accentColor: Color {
        if stopwatch.isBreakActive { return .blue }
        if stopwatch.isRunning    { return Color(red: 0.12, green: 0.78, blue: 0.42) }
        return Color(red: 1.0, green: 0.62, blue: 0.1)
    }

    private var stateLabel: String {
        if stopwatch.isBreakActive { return "Break" }
        if stopwatch.isRunning     { return "Focus" }
        if stopwatch.elapsedTime > 0 { return "Paused" }
        return "Ready"
    }

    var body: some View {
        ZStack {
            if stopwatch.showBreakSelection {
                minimalSliderView
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal: .opacity
                    ))
            } else {
                minimalTimerView
                    .transition(.opacity)
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: stopwatch.showBreakSelection)
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
                    .opacity(stopwatch.isRunning || stopwatch.isBreakActive ? 1 : 0.4)

                Text(stateLabel)
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

                // Tenths
                Text(".\(fraction)")
                    .font(.system(size: 28, weight: .light))
                    .foregroundColor(subtleColor)
                    .padding(.bottom, 6)
            }
            .padding(.horizontal, 32)

            Spacer().frame(height: 40)

            // Triple progress rings
            tripleProgressRings(active: active)
                .frame(width: 240, height: 240)

            Spacer()
        }
    }

    private func timeBlock(value: Int, unit: String) -> some View {
        HStack(alignment: .lastTextBaseline, spacing: 2) {
            Text(String(format: "%02d", value))
                .font(.system(size: 72, weight: .thin, design: .default))
                .foregroundColor(textColor)
                .monospacedDigit()
            Text(unit)
                .font(.system(size: 16, weight: .regular, design: .rounded))
                .foregroundColor(subtleColor)
                .padding(.bottom, 10)
        }
    }

    private func tripleProgressRings(active: TimeInterval) -> some View {
        let hProg = (active / 43200).truncatingRemainder(dividingBy: 1.0)
        let mProg = (active / 3600).truncatingRemainder(dividingBy: 1.0)
        let sProg = (active / 60).truncatingRemainder(dividingBy: 1.0)
        
        return ZStack {
            // Seconds (Outer) - Blue
            singleRing(progress: sProg, color: Color(red: 0.0, green: 0.6, blue: 1.0), thickness: 2, radius: 110)
            
            // Minutes (Middle) - Green
            singleRing(progress: mProg, color: Color(red: 0.2, green: 0.8, blue: 0.3), thickness: 2, radius: 95)
            
            // Hours (Inner) - Red
            singleRing(progress: hProg, color: Color(red: 1.0, green: 0.2, blue: 0.3), thickness: 2, radius: 80)
        }
    }

    private func singleRing(progress: Double, color: Color, thickness: CGFloat, radius: CGFloat) -> some View {
        ZStack {
            Circle()
                .stroke(textColor.opacity(0.04), lineWidth: thickness)
                .frame(width: radius * 2, height: radius * 2)

            Circle()
                .trim(from: 0, to: CGFloat(progress))
                .stroke(
                    color,
                    style: StrokeStyle(lineWidth: thickness + 0.5, lineCap: .round)
                )
                .frame(width: radius * 2, height: radius * 2)
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 1), value: progress)
        }
    }

    // MARK: - Break Selector
    private var minimalSliderView: some View {
        let sliderMax = max(30.0, stopwatch.maxEarnedMinutes * 1.5)
        let breakColor = colorForMinutes(stopwatch.dialedBreakMinutes)

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

            // Big number display
            VStack(spacing: 6) {
                Text("\(Int(stopwatch.dialedBreakMinutes))")
                    .font(.system(size: 100, weight: .thin))
                    .foregroundColor(textColor)
                    .monospacedDigit()
                    .animation(nil, value: stopwatch.dialedBreakMinutes)

                Text("minutes")
                    .font(.system(size: 14, weight: .regular, design: .rounded))
                    .foregroundColor(subtleColor)

                // Earned range label
                Text(breakStatusText)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(breakColor)
                    .tracking(0.5)
                    .padding(.top, 6)
            }
            .padding(.bottom, 52)

            // Slim slider
            GeometryReader { geo in
                let trackW = geo.size.width - 48
                let pct = CGFloat(stopwatch.dialedBreakMinutes / sliderMax).clamped(to: 0...1)
                let thumbX = 24 + trackW * pct

                ZStack(alignment: .leading) {
                    // Track background
                    Capsule()
                        .fill(textColor.opacity(0.08))
                        .frame(height: 3)
                        .padding(.horizontal, 24)

                    // Filled portion
                    Capsule()
                        .fill(breakColor)
                        .frame(width: max(6, trackW * pct), height: 3)
                        .padding(.leading, 24)

                    // Thumb
                    Circle()
                        .fill(breakColor)
                        .frame(width: 22, height: 22)
                        .shadow(color: breakColor.opacity(0.4), radius: 6, y: 2)
                        .position(x: thumbX, y: geo.size.height / 2)
                }
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { v in
                            let pct = ((v.location.x - 24) / trackW).clamped(to: 0...1)
                            stopwatch.dialedBreakMinutes = round(Double(pct) * sliderMax)
                        }
                )
            }
            .frame(height: 40)
            .padding(.horizontal, 0)
            .padding(.bottom, 44)

            // CTA Button
            Button(action: { stopwatch.startBreak() }) {
                Text("Start Break")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(isLight ? .white : .black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(textColor)
                    )
            }
            .padding(.horizontal, 32)

            Spacer()
        }
    }

    private var breakStatusText: String {
        let mins = stopwatch.dialedBreakMinutes
        let minE = round(stopwatch.minEarnedMinutes)
        let maxE = round(stopwatch.maxEarnedMinutes)
        if mins < minE    { return "You deserve more!" }
        if mins <= maxE   { return "Earned!" }
        return "Too long, unless you REALLY need it."
    }

    private func colorForMinutes(_ mins: Double) -> Color {
        let minE = round(stopwatch.minEarnedMinutes)
        let maxE = round(stopwatch.maxEarnedMinutes)
        if mins < minE  { return .orange }
        if mins <= maxE { return Color(red: 0.12, green: 0.78, blue: 0.42) }
        return .red
    }
}

// MARK: - Comparable clamping helper
private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
