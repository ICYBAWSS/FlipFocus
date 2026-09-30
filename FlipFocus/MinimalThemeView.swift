import SwiftUI

struct MinimalThemeView: View {
    @ObservedObject var stopwatch: StopwatchManager
    @State private var revealStart: Double? = nil

    private var isLight: Bool { stopwatch.themeManager.isLightActive }
    private var textColor: Color { isLight ? .black : .white }
    private var subtleColor: Color { isLight ? Color.black.opacity(0.45) : Color.white.opacity(0.45) }

    // OG minimal palette. Kept local on purpose: ThemeManager.ringColors/pausedColor
    // carry the ASCII theme's darker light-mode hues, which read as muddy here.
    private let ringSec = Color(red: 0.0, green: 0.6, blue: 1.0)
    private let ringMin = Color(red: 0.2, green: 0.8, blue: 0.3)
    private let ringHr  = Color(red: 1.0, green: 0.2, blue: 0.3)

    private var accentColor: Color {
        if stopwatch.isBreakActive { return .blue }
        if stopwatch.isRunning    { return Color(red: 0.12, green: 0.78, blue: 0.42) }
        return Color(red: 1.0, green: 0.62, blue: 0.1)
    }

    private var stateLabel: String {
        if stopwatch.isBreakActive { return "Break" }
        if stopwatch.isRunning     { return "Focus" }
        return "Paused"
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
        .onChange(of: stopwatch.ringRevealID) { _, _ in
            revealStart = Date.timeIntervalSinceReferenceDate
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
                    .opacity(stopwatch.isRunning || stopwatch.isBreakActive ? 1 : 0.4)

                Text(stateLabel)
                    .font(helvetica(11, .semibold))
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
                    .font(helvetica(28, .light))
                    .foregroundColor(subtleColor)
                    .padding(.bottom, 6)
            }
            .padding(.horizontal, 32)

            Spacer().frame(height: 40)

            // Triple progress rings
            tripleProgressRings(active: active)
                .frame(width: 240, height: 240)

            ringLegend
                .padding(.top, 16)

            Spacer()
        }
    }

    private var ringLegend: some View {
        HStack(spacing: 20) {
            legendItem("Hrs", color: ringHr)
            legendItem("Min", color: ringMin)
            legendItem("Sec", color: ringSec)
        }
    }

    private func legendItem(_ label: String, color: Color) -> some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(label)
                .font(helvetica(11, .semibold))
                .foregroundColor(subtleColor)
        }
    }

    private func timeBlock(value: Int, unit: String) -> some View {
        HStack(alignment: .lastTextBaseline, spacing: 2) {
            Text(String(format: "%02d", value))
                .font(helvetica(72, .thin))
                .foregroundColor(textColor)
                .monospacedDigit()
            Text(unit)
                .font(helvetica(16, .regular))
                .foregroundColor(subtleColor)
                .padding(.bottom, 10)
        }
    }

    private func tripleProgressRings(active: TimeInterval) -> some View {
        let hProg = (active / 43200).truncatingRemainder(dividingBy: 1.0)
        let mProg = (active / 3600).truncatingRemainder(dividingBy: 1.0)
        let sProg = (active / 60).truncatingRemainder(dividingBy: 1.0)

        // TimelineView (not an implicit animation) drives the sweep frame by frame, so
        // a flip face-up grows the arcs 0 → their real position instead of the value
        // already being there. Same trick the ASCII canvas uses.
        return TimelineView(.animation) { tl in
            let reveal = ringRevealFactor(since: revealStart, at: tl.date.timeIntervalSinceReferenceDate)

            ZStack {
                // Seconds (Outer) - Blue
                singleRing(progress: sProg * reveal, color: ringSec, thickness: 3, radius: 110)

                // Minutes (Middle) - Green
                singleRing(progress: mProg * reveal, color: ringMin, thickness: 3, radius: 95)

                // Hours (Inner) - Red
                singleRing(progress: hProg * reveal, color: ringHr, thickness: 3, radius: 80)
            }
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
                        .font(helvetica(24))
                        .foregroundColor(subtleColor)
                        .padding(24)
                }
                Spacer()
            }
            
            Spacer()

            // Big number display
            VStack(spacing: 6) {
                Text("\(Int(stopwatch.dialedBreakMinutes))")
                    .font(helvetica(100, .thin))
                    .foregroundColor(textColor)
                    .monospacedDigit()
                    .animation(nil, value: stopwatch.dialedBreakMinutes)

                Text("minutes")
                    .font(helvetica(14, .regular))
                    .foregroundColor(subtleColor)

                // Earned range label
                Text(breakStatusText)
                    .font(helvetica(11, .semibold))
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
                    .font(helvetica(16, .semibold))
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
