import SwiftUI

// MARK: - NatureThemeView

struct NatureThemeView: View {
    @ObservedObject var stopwatch: StopwatchManager

    var body: some View {
        ZStack {
            SkyBackgroundView(isBreak: stopwatch.isBreakActive)
            GroundView()
            GrowingTreeView(
                elapsedSeconds: stopwatch.elapsedTime,
                isBreak: stopwatch.isBreakActive,
                breakSeconds: stopwatch.breakTime
            )
            ParticleOverlayView(isBreak: stopwatch.isBreakActive)

            VStack {
                Spacer()
                if stopwatch.showBreakSelection {
                    NatureBreakSelectorView(stopwatch: stopwatch)
                        .padding(.bottom, 60)
                } else {
                    NatureTimerHUDView(stopwatch: stopwatch)
                        .padding(.bottom, 50)
                }
            }
        }
        .ignoresSafeArea()
    }
}

// MARK: - Sky Background

struct SkyBackgroundView: View {
    let isBreak: Bool

    var body: some View {
        TimelineView(.animation) { tl in
            let t = tl.date.timeIntervalSinceReferenceDate

            ZStack {
                LinearGradient(
                    colors: isBreak
                        ? [Color(hex: "1a1a2e"), Color(hex: "16213e"), Color(hex: "0f3460")]
                        : [Color(hex: "dce8f5"), Color(hex: "b8d4e8"), Color(hex: "8fbcd4")],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .animation(.easeInOut(duration: 2), value: isBreak)

                // Subtle cloud wisps (focus mode only)
                if !isBreak {
                    ForEach(0..<4, id: \.self) { i in
                        CloudWispView(index: i, t: t)
                    }
                }

                // Stars (break mode)
                if isBreak {
                    StarsView(t: t)
                }
            }
        }
    }
}

struct CloudWispView: View {
    let index: Int
    let t: Double

    var body: some View {
        let baseX: [CGFloat] = [0.1, 0.35, 0.6, 0.8]
        let baseY: [CGFloat] = [0.12, 0.08, 0.15, 0.1]
        let widths: [CGFloat] = [80, 120, 90, 70]
        let speed: [Double] = [0.008, 0.005, 0.007, 0.009]

        return GeometryReader { geo in
            let drift = CGFloat(sin(t * speed[index % 4] + Double(index))) * 12
            Capsule()
                .fill(Color.white.opacity(0.18))
                .frame(width: widths[index % 4], height: 16)
                .blur(radius: 8)
                .position(
                    x: geo.size.width * baseX[index % 4] + drift,
                    y: geo.size.height * baseY[index % 4]
                )
        }
    }
}

struct StarsView: View {
    let t: Double

    var starPositions: [(CGFloat, CGFloat, Double)] {
        // Fixed seed positions so they don't shuffle
        [
            (0.05, 0.05, 0.8), (0.15, 0.12, 1.0), (0.28, 0.04, 0.6),
            (0.42, 0.09, 0.9), (0.55, 0.03, 0.7), (0.68, 0.14, 1.0),
            (0.80, 0.06, 0.8), (0.92, 0.11, 0.6), (0.10, 0.22, 0.7),
            (0.34, 0.18, 0.9), (0.60, 0.20, 0.8), (0.75, 0.25, 0.6),
            (0.88, 0.30, 1.0), (0.22, 0.32, 0.7), (0.48, 0.28, 0.9),
        ]
    }

    var body: some View {
        GeometryReader { geo in
            ForEach(0..<starPositions.count, id: \.self) { i in
                let (rx, ry, base) = starPositions[i]
                let twinkle = base * (0.4 + 0.6 * sin(t * 1.2 + Double(i) * 2.1))
                Circle()
                    .fill(Color.white.opacity(twinkle))
                    .frame(width: 2.5, height: 2.5)
                    .position(x: geo.size.width * rx, y: geo.size.height * ry)
            }
        }
    }
}

// MARK: - Ground

struct GroundView: View {
    var body: some View {
        VStack {
            Spacer()
            ZStack(alignment: .bottom) {
                // Rolling hill
                Canvas { ctx, size in
                    var path = Path()
                    path.move(to: CGPoint(x: 0, y: size.height * 0.4))
                    path.addCurve(
                        to: CGPoint(x: size.width, y: size.height * 0.3),
                        control1: CGPoint(x: size.width * 0.3, y: size.height * 0.1),
                        control2: CGPoint(x: size.width * 0.7, y: size.height * 0.5)
                    )
                    path.addLine(to: CGPoint(x: size.width, y: size.height))
                    path.addLine(to: CGPoint(x: 0, y: size.height))
                    path.closeSubpath()
                    ctx.fill(path, with: .color(Color(hex: "2d4a1e")))
                }

                // Lighter grass highlight
                Canvas { ctx, size in
                    var path = Path()
                    path.move(to: CGPoint(x: 0, y: size.height * 0.35))
                    path.addCurve(
                        to: CGPoint(x: size.width, y: size.height * 0.25),
                        control1: CGPoint(x: size.width * 0.3, y: size.height * 0.05),
                        control2: CGPoint(x: size.width * 0.7, y: size.height * 0.45)
                    )
                    path.addLine(to: CGPoint(x: size.width, y: size.height * 0.38))
                    path.addCurve(
                        to: CGPoint(x: 0, y: size.height * 0.48),
                        control1: CGPoint(x: size.width * 0.7, y: size.height * 0.58),
                        control2: CGPoint(x: size.width * 0.3, y: size.height * 0.18)
                    )
                    path.closeSubpath()
                    ctx.fill(path, with: .color(Color(hex: "3d6628").opacity(0.7)))
                }
            }
            .frame(height: 200)
        }
        .ignoresSafeArea()
    }
}

// MARK: - Growing Tree

struct GrowingTreeView: View {
    let elapsedSeconds: Double
    let isBreak: Bool
    let breakSeconds: Double

    /// Growth from 0 (sapling) to 1 (full tree) over 90 minutes
    var growthProgress: Double {
        min(1.0, elapsedSeconds / (90 * 60))
    }

    var body: some View {
        TimelineView(.animation) { tl in
            let t = tl.date.timeIntervalSinceReferenceDate
            GeometryReader { geo in
                let cx = geo.size.width / 2
                let groundY = geo.size.height * 0.72
                TreeCanvas(t: t, cx: cx, groundY: groundY, growth: growthProgress, isBreak: isBreak)
            }
        }
    }
}

struct TreeCanvas: View {
    let t: Double
    let cx: CGFloat
    let groundY: CGFloat
    let growth: Double
    let isBreak: Bool

    var body: some View {
        Canvas { ctx, size in
            let sway = sin(t * 0.6) * 3.0 * CGFloat(0.3 + growth * 0.7)
            let trunkHeight = 40 + CGFloat(growth) * 140
            let trunkWidth = 6 + CGFloat(growth) * 14

            // --- Trunk ---
            drawTrunk(ctx: ctx, cx: cx, groundY: groundY,
                      height: trunkHeight, width: trunkWidth, sway: sway)

            // --- Branches & Foliage (appear as growth increases) ---
            if growth > 0.15 {
                let branchAlpha = min(1.0, (growth - 0.15) / 0.25)
                drawBranches(ctx: ctx, cx: cx, groundY: groundY,
                             trunkHeight: trunkHeight, sway: sway,
                             growth: growth, alpha: CGFloat(branchAlpha), t: t)
            }

            // --- Leaf clusters ---
            if growth > 0.2 {
                let leafAlpha = min(1.0, (growth - 0.2) / 0.3)
                drawLeafClusters(ctx: ctx, cx: cx, groundY: groundY,
                                 trunkHeight: trunkHeight, sway: sway,
                                 growth: growth, alpha: CGFloat(leafAlpha), t: t,
                                 isBreak: isBreak)
            }

            // --- Blossoms (break mode) ---
            if isBreak && growth > 0.3 {
                drawBlossoms(ctx: ctx, cx: cx, groundY: groundY,
                             trunkHeight: trunkHeight, sway: sway, t: t, growth: growth)
            }
        }
    }

    private func drawTrunk(ctx: GraphicsContext, cx: CGFloat, groundY: CGFloat,
                           height: CGFloat, width: CGFloat, sway: CGFloat) {
        var path = Path()
        let tipX = cx + sway
        let tipY = groundY - height

        path.move(to: CGPoint(x: cx - width / 2, y: groundY))
        path.addCurve(
            to: CGPoint(x: tipX - width * 0.2, y: tipY),
            control1: CGPoint(x: cx - width * 0.4, y: groundY - height * 0.4),
            control2: CGPoint(x: tipX - width * 0.3, y: tipY + height * 0.3)
        )
        path.addLine(to: CGPoint(x: tipX + width * 0.2, y: tipY))
        path.addCurve(
            to: CGPoint(x: cx + width / 2, y: groundY),
            control1: CGPoint(x: tipX + width * 0.3, y: tipY + height * 0.3),
            control2: CGPoint(x: cx + width * 0.4, y: groundY - height * 0.4)
        )
        path.closeSubpath()

        ctx.fill(path, with: .color(Color(hex: "5c3a1e")))

        // Bark highlight
        var highlight = Path()
        highlight.move(to: CGPoint(x: cx - width * 0.15, y: groundY - 10))
        highlight.addCurve(
            to: CGPoint(x: tipX - width * 0.05, y: tipY + 10),
            control1: CGPoint(x: cx - width * 0.1, y: groundY - height * 0.4),
            control2: CGPoint(x: tipX, y: tipY + height * 0.3)
        )
        highlight.addLine(to: CGPoint(x: tipX, y: tipY + 10))
        highlight.addCurve(
            to: CGPoint(x: cx, y: groundY - 10),
            control1: CGPoint(x: tipX + width * 0.05, y: tipY + height * 0.35),
            control2: CGPoint(x: cx + width * 0.05, y: groundY - height * 0.38)
        )
        highlight.closeSubpath()
        ctx.fill(highlight, with: .color(Color(hex: "7a5030").opacity(0.5)))
    }

    private func drawBranches(ctx: GraphicsContext, cx: CGFloat, groundY: CGFloat,
                              trunkHeight: CGFloat, sway: CGFloat,
                              growth: Double, alpha: CGFloat, t: Double) {
        let tipX = cx + sway
        let tipY = groundY - trunkHeight

        struct Branch {
            let startFrac: CGFloat   // fraction up the trunk
            let angle: CGFloat       // radians from vertical
            let length: CGFloat
            let width: CGFloat
            let swayMult: CGFloat
        }

        let branches: [Branch] = [
            Branch(startFrac: 0.55, angle: -0.8, length: 55 * CGFloat(growth), width: 4, swayMult: 1.1),
            Branch(startFrac: 0.55, angle: 0.9, length: 50 * CGFloat(growth), width: 4, swayMult: -1.0),
            Branch(startFrac: 0.72, angle: -1.1, length: 45 * CGFloat(growth), width: 3, swayMult: 1.3),
            Branch(startFrac: 0.72, angle: 0.7, length: 40 * CGFloat(growth), width: 3, swayMult: -1.2),
            Branch(startFrac: 0.88, angle: -0.6, length: 35 * CGFloat(growth), width: 2.5, swayMult: 1.5),
            Branch(startFrac: 0.88, angle: 0.5, length: 30 * CGFloat(growth), width: 2.5, swayMult: -1.4),
        ]

        for b in branches {
            let bSway = sin(t * 0.6 + Double(b.swayMult)) * 2.5 * b.swayMult
            let bx = tipX + sway * (1 - b.startFrac) * (-b.swayMult > 0 ? 1 : -1) * 0.3
            let by = tipY + trunkHeight * (1 - b.startFrac)
            let endX = bx + cos(.pi / 2 - b.angle) * b.length + CGFloat(bSway)
            let endY = by - sin(.pi / 2 - b.angle) * b.length

            var path = Path()
            path.move(to: CGPoint(x: bx, y: by))
            path.addQuadCurve(
                to: CGPoint(x: endX, y: endY),
                control: CGPoint(x: (bx + endX) / 2 + CGFloat(bSway) * 0.5, y: by - 15)
            )

            ctx.stroke(path, with: .color(Color(hex: "5c3a1e").opacity(alpha)),
                       style: StrokeStyle(lineWidth: b.width, lineCap: .round))
        }
    }

    private func drawLeafClusters(ctx: GraphicsContext, cx: CGFloat, groundY: CGFloat,
                                  trunkHeight: CGFloat, sway: CGFloat,
                                  growth: Double, alpha: CGFloat, t: Double,
                                  isBreak: Bool) {
        let tipX = cx + sway
        let tipY = groundY - trunkHeight

        struct Cluster {
            let x: CGFloat; let y: CGFloat; let r: CGFloat; let layer: Int
        }

        let g = CGFloat(growth)
        let clusters: [Cluster] = [
            // Crown top
            Cluster(x: tipX,          y: tipY - 30 * g,      r: 45 * g, layer: 2),
            Cluster(x: tipX - 30 * g, y: tipY - 10 * g,      r: 38 * g, layer: 1),
            Cluster(x: tipX + 28 * g, y: tipY - 8 * g,       r: 35 * g, layer: 1),
            // Mid
            Cluster(x: tipX - 50 * g, y: tipY + 40 * g,      r: 32 * g, layer: 0),
            Cluster(x: tipX + 48 * g, y: tipY + 42 * g,      r: 30 * g, layer: 0),
            Cluster(x: tipX - 65 * g, y: tipY + 80 * g,      r: 28 * g, layer: 0),
            Cluster(x: tipX + 60 * g, y: tipY + 75 * g,      r: 26 * g, layer: 0),
        ]

        // Leaf colors: deep green (focus) or warm blossom tint (break)
        let colors: [Color] = isBreak
            ? [Color(hex: "5a8a3a"), Color(hex: "4a7a2a"), Color(hex: "6a9a4a")]
            : [Color(hex: "2e5e1a"), Color(hex: "3d7224"), Color(hex: "4a8a2c")]

        for c in clusters {
            let drift = CGFloat(sin(t * 0.5 + Double(c.r))) * 3.0
            let col = colors[c.layer % colors.count]
            let ellipse = Path(ellipseIn: CGRect(
                x: c.x + drift - c.r,
                y: c.y - c.r * 0.8,
                width: c.r * 2,
                height: c.r * 1.6
            ))
            ctx.fill(ellipse, with: .color(col.opacity(Double(alpha) * 0.9)))

            // Lighter highlight on top-left
            let highlight = Path(ellipseIn: CGRect(
                x: c.x + drift - c.r * 0.6,
                y: c.y - c.r * 0.7,
                width: c.r,
                height: c.r * 0.7
            ))
            ctx.fill(highlight, with: .color(col.opacity(Double(alpha) * 0.25)))
        }
    }

    private func drawBlossoms(ctx: GraphicsContext, cx: CGFloat, groundY: CGFloat,
                              trunkHeight: CGFloat, sway: CGFloat, t: Double, growth: Double) {
        let tipX = cx + sway
        let tipY = groundY - trunkHeight
        let g = CGFloat(growth)

        let blossomPositions: [(CGFloat, CGFloat)] = [
            (tipX - 20 * g,  tipY - 35 * g),
            (tipX + 15 * g,  tipY - 20 * g),
            (tipX - 45 * g,  tipY + 15 * g),
            (tipX + 40 * g,  tipY + 20 * g),
            (tipX - 60 * g,  tipY + 55 * g),
            (tipX + 55 * g,  tipY + 60 * g),
            (tipX + 5 * g,   tipY - 5 * g),
        ]

        for (i, (bx, by)) in blossomPositions.enumerated() {
            let twinkle = 0.4 + 0.6 * sin(t * 1.5 + Double(i) * 1.3)
            let drift = CGFloat(sin(t * 0.7 + Double(i) * 0.8)) * 4

            for petal in 0..<5 {
                let angle = Double(petal) * .pi * 2 / 5
                let px = bx + drift + cos(angle) * 5
                let py = by + sin(angle) * 5
                let petalPath = Path(ellipseIn: CGRect(x: px - 3, y: py - 4, width: 6, height: 8))
                ctx.fill(petalPath, with: .color(Color(hex: "ffb7c5").opacity(twinkle * 0.9)))
            }
            // Center
            let center = Path(ellipseIn: CGRect(x: bx + drift - 2.5, y: by - 2.5, width: 5, height: 5))
            ctx.fill(center, with: .color(Color(hex: "ffe066").opacity(twinkle)))
        }
    }
}

// MARK: - Particle Overlay (Fireflies / Pollen)

struct ParticleOverlayView: View {
    let isBreak: Bool

    var body: some View {
        TimelineView(.animation) { tl in
            let t = tl.date.timeIntervalSinceReferenceDate
            GeometryReader { geo in
                Canvas { ctx, size in
                    for i in 0..<(isBreak ? 12 : 6) {
                        let seed = Double(i) * 137.508
                        let baseX = CGFloat((seed * 0.618).truncatingRemainder(dividingBy: 1.0)) * size.width
                        let baseY = CGFloat((seed * 0.382).truncatingRemainder(dividingBy: 1.0)) * size.height * 0.7 + size.height * 0.1

                        let dx = CGFloat(sin(t * 0.4 + seed)) * 30
                        let dy = CGFloat(cos(t * 0.3 + seed * 0.7)) * 20
                        let alpha = 0.2 + 0.8 * abs(sin(t * 1.1 + seed * 0.5))

                        let rect = CGRect(x: baseX + dx - 2, y: baseY + dy - 2, width: 4, height: 4)
                        let dot = Path(ellipseIn: rect)
                        if isBreak {
                            ctx.fill(dot, with: .color(Color(hex: "aaffaa").opacity(alpha * 0.8)))
                        } else {
                            ctx.fill(dot, with: .color(Color(hex: "ffffcc").opacity(alpha * 0.4)))
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Timer HUD

struct NatureTimerHUDView: View {
    @ObservedObject var stopwatch: StopwatchManager

    private var activeElapsed: Double {
        stopwatch.isBreakActive ? stopwatch.breakTime : stopwatch.elapsedTime
    }
    private var label: String {
        stopwatch.isBreakActive ? "RESTING" : "GROWING"
    }
    private var accent: Color {
        stopwatch.isBreakActive ? Color(hex: "7ec8a0") : Color(hex: "4a8a2c")
    }
    private var growthPercent: Int {
        min(100, Int(stopwatch.elapsedTime / (90 * 60) * 100))
    }

    var body: some View {
        VStack(spacing: 6) {
            // Growth progress ring
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.12), lineWidth: 3)
                    .frame(width: 110, height: 110)

                Circle()
                    .trim(from: 0, to: CGFloat(growthPercent) / 100)
                    .stroke(accent, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: 110, height: 110)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 1), value: growthPercent)

                VStack(spacing: 2) {
                    Text(timeString(activeElapsed))
                        .font(.system(size: 28, weight: .semibold, design: .monospaced))
                        .foregroundColor(.white)

                    Text(label)
                        .font(.system(size: 8, weight: .black))
                        .foregroundColor(accent)
                        .kerning(2.5)
                }
            }

            Text("tree is \(growthPercent)% grown")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white.opacity(0.55))
                .padding(.top, 2)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.black.opacity(0.25))
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 20))
        )
    }

    private func timeString(_ t: Double) -> String {
        let m = Int(t / 60) % 60
        let s = Int(t) % 60
        let h = Int(t / 3600)
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%02d:%02d", m, s)
    }
}

// MARK: - Break Selector

struct NatureBreakSelectorView: View {
    @ObservedObject var stopwatch: StopwatchManager

    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 4) {
                Text("REST IN NATURE")
                    .font(.system(size: 11, weight: .black))
                    .foregroundColor(.white.opacity(0.7))
                    .kerning(3)
                Text("how long will you rest?")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.5))
            }

            // Slider
            VStack(spacing: 8) {
                let sliderMax = max(30.0, stopwatch.maxEarnedMinutes * 1.5)

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        // Track
                        Capsule()
                            .fill(Color.white.opacity(0.15))
                            .frame(height: 6)

                        // Fill
                        Capsule()
                            .fill(LinearGradient(
                                colors: [Color(hex: "7ec8a0"), Color(hex: "aaffcc")],
                                startPoint: .leading, endPoint: .trailing
                            ))
                            .frame(width: CGFloat(stopwatch.dialedBreakMinutes / sliderMax) * geo.size.width, height: 6)

                        // Thumb
                        Circle()
                            .fill(Color.white)
                            .frame(width: 24, height: 24)
                            .shadow(color: .black.opacity(0.25), radius: 4)
                            .offset(x: CGFloat(stopwatch.dialedBreakMinutes / sliderMax) * geo.size.width - 12)
                            .gesture(
                                DragGesture()
                                    .onChanged { val in
                                        let pct = max(0, min(1, val.location.x / geo.size.width))
                                        stopwatch.dialedBreakMinutes = round(pct * sliderMax)
                                    }
                            )
                    }
                    .frame(height: 24)
                }
                .frame(height: 24)
                .padding(.horizontal, 4)

                Text("\(Int(stopwatch.dialedBreakMinutes)) min")
                    .font(.system(size: 36, weight: .thin, design: .serif))
                    .foregroundColor(.white)
            }

            Button(action: { stopwatch.startBreak() }) {
                HStack(spacing: 8) {
                    Image(systemName: "leaf.fill")
                    Text("Begin Rest")
                        .fontWeight(.semibold)
                }
                .foregroundColor(Color(hex: "2d4a1e"))
                .padding(.horizontal, 36)
                .padding(.vertical, 14)
                .background(
                    Capsule()
                        .fill(LinearGradient(
                            colors: [Color(hex: "7ec8a0"), Color(hex: "4ec880")],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ))
                )
            }
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 24)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.black.opacity(0.3))
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 24))
        )
        .padding(.horizontal, 24)
    }
}

// MARK: - Color Extension

extension Color {
    init(hex: String) {
        let h = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: h).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8)  & 0xFF) / 255
        let b = Double(int         & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}
