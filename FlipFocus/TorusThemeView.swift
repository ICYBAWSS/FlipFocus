import SwiftUI
import Combine

// MARK: - TorusThemeView

struct TorusThemeView: View {
    @ObservedObject var stopwatch: StopwatchManager
    @StateObject private var interaction = TorusInteractionState()

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if stopwatch.showBreakSelection {
                TorusBreakSelectorView(stopwatch: stopwatch)
            } else {
                TorusMainView(stopwatch: stopwatch, interaction: interaction)
            }
        }
        // Shake already triggers the break — we just watch the flag flip
        .onChange(of: stopwatch.isBreakActive) { oldValue, newValue in
            if newValue { interaction.triggerBreakTransition() }
        }
    }
}

// MARK: - Interaction State

class TorusInteractionState: ObservableObject {

    // Tap shockwaves: (birth date, phi seed)
    @Published var shockwaves: [(date: Date, phiOffset: Double)] = []

    // Long press distortion 0→1
    @Published var longPressIntensity: Double = 0
    @Published var isLongPressing: Bool = false

    // Break transition
    enum TransitionPhase { case idle, exploding, reforming }
    @Published var transitionPhase: TransitionPhase = .idle
    @Published var transitionProgress: Double = 0

    func tick(dt: Double) {
        // Long press
        if isLongPressing {
            longPressIntensity = min(1.0, longPressIntensity + dt * 1.1)
        } else {
            longPressIntensity = max(0, longPressIntensity - dt * (0.7 + longPressIntensity * 2.0))
        }

        // Break transition timeline
        switch transitionPhase {
        case .exploding:
            transitionProgress += dt / 0.55
            if transitionProgress >= 1.0 {
                transitionProgress = 0
                transitionPhase = .reforming
            }
        case .reforming:
            transitionProgress += dt / 0.85
            if transitionProgress >= 1.0 {
                transitionProgress = 1.0
                transitionPhase = .idle
            }
        case .idle:
            break
        }

        // Prune stale waves
        shockwaves = shockwaves.filter { -$0.date.timeIntervalSinceNow < 2.0 }
    }

    func triggerBreakTransition() {
        transitionPhase = .exploding
        transitionProgress = 0
    }

    func addShockwave(phiOffset: Double) {
        shockwaves.append((date: Date(), phiOffset: phiOffset))
    }

    func beginLongPress() { isLongPressing = true }
    func endLongPress()   { isLongPressing = false }
}

// MARK: - Main View

struct TorusMainView: View {
    @ObservedObject var stopwatch: StopwatchManager
    @ObservedObject var interaction: TorusInteractionState

    var body: some View {
        ZStack {
            TimelineView(.animation) { _ in
                TorusCanvas(stopwatch: stopwatch, interaction: interaction)
                    .ignoresSafeArea()
            }

            // Gesture layer
            Color.clear
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {
                    interaction.addShockwave(phiOffset: Double.random(in: 0 ..< .pi * 2))
                }
                .simultaneousGesture(
                    LongPressGesture(minimumDuration: 0.01)
                        .onChanged { _ in interaction.beginLongPress() }
                        .onEnded   { _ in interaction.endLongPress() }
                )
                .simultaneousGesture(
                    DragGesture(minimumDistance: 0)
                        .onEnded { _ in interaction.endLongPress() }
                )

            VStack {
                Spacer()
                TorusHUD(stopwatch: stopwatch)
                    .padding(.bottom, 60)
            }
        }
    }
}

// MARK: - Canvas

struct TorusCanvas: View {
    @ObservedObject var stopwatch: StopwatchManager
    @ObservedObject var interaction: TorusInteractionState

    var body: some View {
        Canvas { ctx, size in
            Task { @MainActor in interaction.tick(dt: 1.0 / 60.0) }

            let t        = Date().timeIntervalSinceReferenceDate
            let elapsed  = stopwatch.isBreakActive ? stopwatch.breakTime : stopwatch.elapsedTime
            let goalSecs = max(1.0, stopwatch.dailyGoal * 60.0)
            let progress = min(1.0, elapsed / goalSecs)
            let over     = max(0.0, elapsed / goalSecs - 1.0)
            let isBreak  = stopwatch.isBreakActive
            let frag     = interaction.longPressIntensity
            let phase    = interaction.transitionPhase
            let tProg    = interaction.transitionProgress
            let waves    = interaction.shockwaves

            // How much to scatter points outward
            let explodeAmt: Double = {
                switch phase {
                case .exploding: return tProg
                case .reforming: return 1.0 - pow(tProg, 0.55)
                case .idle:      return 0
                }
            }()
            let totalScatter = max(frag, explodeAmt)

            // Geometry — tube radius grows from sliver to full torus over session
            let R2: Double = 2.0
            let R1: Double = 0.18 + progress * 1.0
            let K2: Double = 5.0
            let side = Double(min(size.width, size.height))
            let K1   = side * K2 * 3.4 / (8.0 * (R1 + R2))
            let cx   = size.width  / 2
            let cy   = size.height / 2

            // Spin speed — slows during explosion, settles to break pace after
            let spinBase: Double = {
                switch phase {
                case .exploding: return 0.5 * (1.0 - tProg * 0.8)
                case .reforming: return 0.22 + tProg * (isBreak ? 0.0 : 0.28)
                case .idle:      return isBreak ? 0.22 : (0.50 + progress * 0.60)
                }
            }()
            let A = t * spinBase * 0.85
            let B = t * spinBase * 0.42

            // Arc reveal: only a sliver at session start, full ring at goal
            let revealFrac = max(0.06, progress)
            let phiMax     = revealFrac * 2.0 * .pi

            let thetaStep = 0.24 - progress * 0.08
            let phiStep   = 0.10 - progress * 0.03

            var theta = 0.0
            while theta < 2 * .pi {
                let cosT = cos(theta), sinT = sin(theta)
                var phi = 0.0
                while phi < phiMax {
                    let cosP = cos(phi), sinP = sin(phi)

                    // Tap shockwave — tangential ripple along the ring
                    var waveU: Double = 0, waveV: Double = 0
                    for wave in waves {
                        let age = -wave.date.timeIntervalSinceNow
                        guard age < 1.8 else { continue }
                        let front    = age * 3.2
                        let dist     = abs(phi - wave.phiOffset.truncatingRemainder(dividingBy: phiMax + 0.001))
                        let envelope = max(0, 1.0 - abs(dist - front) * 5.0)
                        let decay    = pow(1.0 - age / 1.8, 2.0)
                        let disp     = sin(dist * 10 - age * 14) * 22.0 * envelope * decay
                        waveU += disp * (-sinP)
                        waveV += disp *   cosP
                    }

                    // Scatter — deterministic per-point using theta/phi as seed
                    var scatterX: Double = 0, scatterY: Double = 0
                    if totalScatter > 0 {
                        let s1  = sin(theta * 31.7 + phi * 17.3) * 43758.5453
                        let sx  = s1 - floor(s1)
                        let s2  = sin(theta * 11.3 + phi * 61.1) * 43758.5453
                        let sy  = s2 - floor(s2)
                        let ang = sx * 2 * .pi
                        let r   = (sy * 140 + 30) * pow(totalScatter, 0.65)
                        scatterX = cos(ang) * r
                        scatterY = sin(ang) * r
                    }

                    // Torus projection
                    let circX = R2 + R1 * cosT
                    let circY = R1 * sinT
                    let x = circX * (cos(B) * cosP + sin(A) * sin(B) * sinP) - circY * cos(A) * sin(B)
                    let y = circX * (sin(B) * cosP - sin(A) * cos(B) * sinP) + circY * cos(A) * cos(B)
                    let z = K2 + circX * cos(A) * sinP + circY * sin(A)
                    let ooz = 1.0 / z

                    let xp = cx + K1 * ooz * x + waveU + scatterX
                    let yp = cy - K1 * ooz * y + waveV + scatterY

                    let L = cosP * cosT * sin(B)
                           - cos(A) * cosT * sinP
                           - sin(A) * sinT
                           + cos(B) * (cos(A) * sinT - cosT * sin(A) * sinP)
                    guard L > 0 else { phi += phiStep; continue }

                    let depth  = (z - (K2 - R1 - R2)) / (2.0 * (R1 + R2))
                    let arcPos = phi / phiMax   // 0 = arc root, 1 = leading edge

                    // Colour: focus green ↔ break indigo, blended during transition
                    let breakBlend: Double = {
                        switch phase {
                        case .exploding: return tProg
                        case .reforming: return 1.0
                        case .idle:      return isBreak ? 1.0 : 0.0
                        }
                    }()

                    let color: Color
                    if over > 0 && breakBlend < 0.5 {
                        // Overdrive: molten gold
                        let pulse = 0.5 + 0.5 * sin(t * 3.5)
                        color = Color(hue: 0.09 + pulse * 0.05, saturation: 1.0,
                                      brightness: 0.7 + pulse * 0.3)
                            .opacity(0.3 + (1 - depth) * 0.7)
                    } else {
                        let focusHue: Double = 0.36 - arcPos * 0.10        // green → teal
                        let breakHue: Double = 0.63 + sin(t * 0.7) * 0.04  // indigo breathe
                        let hue     = focusHue + (breakHue - focusHue) * breakBlend
                        let tipGlow = pow(arcPos, 2.5) * (1.0 - breakBlend)
                        let breathe = breakBlend * (0.5 + 0.5 * sin(t * 0.7))
                        let bright  = 0.25 + (1 - depth) * 0.55 + tipGlow * 0.3 + breathe * 0.15
                        let alpha   = (0.2 + (1 - depth) * 0.8) * (1.0 - totalScatter * 0.5)
                        color = Color(hue: hue, saturation: 0.78, brightness: bright).opacity(alpha)
                    }

                    // Chars dissolve to sparse dots mid-explosion
                    let denseChars: [Character]  = ["·", "·", ",", "-", "~", ":", ";", "=", "!", "*", "#", "@"]
                    let sparseChars: [Character] = ["·", "·", "·", ",", "."]
                    let charSet = totalScatter > 0.4 ? sparseChars : denseChars
                    let ci = max(0, min(charSet.count - 1, Int(L * Double(charSet.count))))

                    let tipScale = 1.0 + pow(arcPos, 4.0) * 0.7
                    let fontSize = (5.5 + (1.0 - depth) * 3.5) * tipScale

                    ctx.draw(
                        Text(String(charSet[ci]))
                            .font(.system(size: fontSize, weight: .bold, design: .monospaced))
                            .foregroundColor(color),
                        at: CGPoint(x: xp, y: yp)
                    )

                    phi += phiStep
                }
                theta += thetaStep
            }

            // Leading-edge glow dot (focus mode only)
            if !isBreak && progress > 0.04 && totalScatter < 0.2 && phase == .idle {
                let cosTP = cos(phiMax), sinTP = sin(phiMax)
                let pulse = 0.55 + 0.45 * sin(t * 4.5)
                for i in 0..<12 {
                    let th = Double(i) / 12.0 * 2 * .pi
                    let cT = cos(th), sT = sin(th)
                    let cX = R2 + R1 * cT, cY = R1 * sT
                    let x  = cX * (cos(B) * cosTP + sin(A) * sin(B) * sinTP) - cY * cos(A) * sin(B)
                    let y  = cX * (sin(B) * cosTP - sin(A) * cos(B) * sinTP) + cY * cos(A) * cos(B)
                    let z  = K2 + cX * cos(A) * sinTP + cY * sin(A)
                    let ooz = 1.0 / z
                    let xp  = cx + K1 * ooz * x
                    let yp  = cy - K1 * ooz * y
                    let r   = 2.5 + pulse * 1.5
                    ctx.fill(
                        Path(ellipseIn: CGRect(x: xp - r, y: yp - r, width: r * 2, height: r * 2)),
                        with: .color(Color(hue: 0.22, saturation: 0.9, brightness: 1.0).opacity(pulse * 0.85))
                    )
                }
            }

            // Blue-white flash at the moment of reformation
            if phase == .reforming && tProg < 0.12 {
                let flash = (0.12 - tProg) / 0.12 * 0.3
                ctx.fill(
                    Path(CGRect(origin: .zero, size: size)),
                    with: .color(Color(hue: 0.63, saturation: 0.4, brightness: 1.0).opacity(flash))
                )
            }
        }
    }
}

// MARK: - HUD

struct TorusHUD: View {
    @ObservedObject var stopwatch: StopwatchManager

    private var elapsed: Double  { stopwatch.isBreakActive ? stopwatch.breakTime : stopwatch.elapsedTime }
    private var goalSecs: Double { max(1.0, stopwatch.dailyGoal * 60.0) }
    private var progress: Double { min(1.0, elapsed / goalSecs) }
    private var over: Double     { max(0, elapsed / goalSecs - 1.0) }

    private var timeString: String {
        let h = Int(elapsed / 3600), m = Int(elapsed / 60) % 60, s = Int(elapsed) % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%02d:%02d", m, s)
    }
    private var statusLabel: String {
        if stopwatch.isBreakActive { return "RESTORING" }
        if !stopwatch.isRunning    { return "PAUSED" }
        return over > 0 ? "OVERDRIVE" : "FOCUSING"
    }
    private var accentColor: Color {
        if stopwatch.isBreakActive { return Color(hue: 0.63, saturation: 0.7, brightness: 0.95) }
        if over > 0                { return Color(hue: 0.10, saturation: 1.0, brightness: 1.0) }
        return Color(hue: 0.35, saturation: 0.85, brightness: 0.95)
    }

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.08), lineWidth: 2.5)
                    .frame(width: 104, height: 104)
                Circle()
                    .trim(from: 0, to: CGFloat(progress))
                    .stroke(accentColor, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 104, height: 104)
                    .animation(.easeInOut(duration: 1), value: progress)
                VStack(spacing: 3) {
                    Text(timeString)
                        .font(.system(size: 26, weight: .semibold, design: .monospaced))
                        .foregroundColor(.white)
                    Text(statusLabel)
                        .font(.system(size: 8, weight: .black, design: .monospaced))
                        .foregroundColor(accentColor)
                        .kerning(2.5)
                }
            }
            Text("ring \(Int(progress * 100))% complete")
                .font(.system(size: 10, weight: .regular, design: .monospaced))
                .foregroundColor(.white.opacity(0.35))
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(.ultraThinMaterial)
                .environment(\.colorScheme, .dark)
        )
    }
}

// MARK: - Break Selector

struct TorusBreakSelectorView: View {
    @ObservedObject var stopwatch: StopwatchManager

    var body: some View {
        VStack(spacing: 32) {
            // Mini torus in break colours
            TimelineView(.animation) { tl in
                let t = tl.date.timeIntervalSinceReferenceDate
                Canvas { ctx, size in drawMini(ctx: ctx, size: size, t: t) }
            }
            .frame(width: 180, height: 180)

            VStack(spacing: 6) {
                Text("SET BREAK")
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .foregroundColor(Color(hue: 0.63, saturation: 0.7, brightness: 0.9))
                    .kerning(3)
                HStack(alignment: .lastTextBaseline, spacing: 4) {
                    Text("\(Int(stopwatch.dialedBreakMinutes))")
                        .font(.system(size: 56, weight: .thin, design: .monospaced))
                        .foregroundColor(.white)
                    Text("min")
                        .font(.system(size: 16, weight: .light, design: .monospaced))
                        .foregroundColor(.white.opacity(0.4))
                        .padding(.bottom, 6)
                }
            }

            let sliderMax = max(30.0, stopwatch.maxEarnedMinutes * 1.5)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.1)).frame(height: 4)
                    Capsule()
                        .fill(LinearGradient(
                            colors: [Color(hue: 0.62, saturation: 0.8, brightness: 0.7),
                                     Color(hue: 0.65, saturation: 0.6, brightness: 1.0)],
                            startPoint: .leading, endPoint: .trailing))
                        .frame(width: CGFloat(stopwatch.dialedBreakMinutes / sliderMax) * geo.size.width,
                               height: 4)
                    Circle()
                        .fill(Color.white)
                        .frame(width: 20, height: 20)
                        .shadow(color: .black.opacity(0.4), radius: 4)
                        .offset(x: CGFloat(stopwatch.dialedBreakMinutes / sliderMax) * geo.size.width - 10)
                        .gesture(DragGesture().onChanged { val in
                            let pct = max(0, min(1, val.location.x / geo.size.width))
                            stopwatch.dialedBreakMinutes = round(pct * sliderMax)
                        })
                }
                .frame(height: 20)
            }
            .frame(height: 20)
            .padding(.horizontal, 8)

            Button(action: { stopwatch.startBreak() }) {
                Text("BEGIN REST")
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundColor(.black)
                    .padding(.horizontal, 44)
                    .padding(.vertical, 14)
                    .background(Capsule().fill(LinearGradient(
                        colors: [Color(hue: 0.62, saturation: 0.6, brightness: 0.9),
                                 Color(hue: 0.65, saturation: 0.7, brightness: 1.0)],
                        startPoint: .topLeading, endPoint: .bottomTrailing)))
            }
        }
        .padding(.horizontal, 36)
        .padding(.vertical, 28)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(.ultraThinMaterial)
                .environment(\.colorScheme, .dark)
        )
        .padding(.horizontal, 28)
    }

    private func drawMini(ctx: GraphicsContext, size: CGSize, t: Double) {
        let cx = size.width / 2, cy = size.height / 2
        let R1 = 0.55, R2 = 1.3, K2 = 4.0
        let K1 = Double(min(size.width, size.height)) * K2 / (4.5 * (R1 + R2))
        let A = t * 0.3, B = t * 0.15
        let breathe = 0.5 + 0.5 * sin(t * 0.7)
        for theta in stride(from: 0.0, to: 2 * .pi, by: 0.28) {
            for phi in stride(from: 0.0, to: 2 * .pi, by: 0.10) {
                let cT = cos(theta), sT = sin(theta)
                let cP = cos(phi),   sP = sin(phi)
                let circX = R2 + R1 * cT, circY = R1 * sT
                let x = circX * (cos(B) * cP + sin(A) * sin(B) * sP) - circY * cos(A) * sin(B)
                let y = circX * (sin(B) * cP - sin(A) * cos(B) * sP) + circY * cos(A) * cos(B)
                let z = K2 + circX * cos(A) * sP + circY * sin(A)
                let ooz = 1.0 / z
                let xp = cx + K1 * ooz * x, yp = cy - K1 * ooz * y
                let L = cP * cT * sin(B) - cos(A) * cT * sP - sin(A) * sT
                       + cos(B) * (cos(A) * sT - cT * sin(A) * sP)
                guard L > 0 else { continue }
                let depth = (z - (K2 - R1 - R2)) / (2 * (R1 + R2))
                ctx.draw(
                    Text("·")
                        .font(.system(size: 6, weight: .bold, design: .monospaced))
                        .foregroundColor(Color(
                            hue: 0.62 + breathe * 0.07,
                            saturation: 0.65,
                            brightness: 0.4 + (1 - depth) * 0.5
                        ).opacity(0.3 + (1 - depth) * 0.7)),
                    at: CGPoint(x: xp, y: yp)
                )
            }
        }
    }
}
