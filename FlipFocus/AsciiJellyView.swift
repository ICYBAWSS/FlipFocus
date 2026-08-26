import SwiftUI

// MARK: - Constants & Bitmaps
private let RAMP: [Character] = Array("_-~:;i!|=+oxX%#@█")

private func rampChar(_ v: Double) -> Character {
    let idx = max(0, min(RAMP.count - 1, Int(v * Double(RAMP.count - 1))))
    return RAMP[idx]
}

private let CHAR_MAP: [Character: [String]] = [
    "0": ["#####","#   #","#   #","#   #","#####"],
    "1": ["  #  "," ##  ","  #  ","  #  ","#####"],
    "2": ["#####","    #","#####","#    ","#####"],
    "3": ["#####","    #"," ####","    #","#####"],
    "4": ["#   #","#   #","#####","    #","    #"],
    "5": ["#####","#    ","#####","    #","#####"],
    "6": ["#####","#    ","#####","#   #","#####"],
    "7": ["#####","    #","   # ","  #  ","  #  "],
    "8": ["#####","#   #","#####","#   #","#####"],
    "9": ["#####","#   #","#####","    #","#####"],
    ":": ["     "," ##  ","     "," ##  ","     "],
    ".": ["     ","     ","     ","     ","  ## "],
    " ": ["     ","     ","     ","     ","     "],
    "-": ["     ","     ","#####","     ","     "],
    "+": ["     ","  #  ","#####","  #  ","     "],
    "@": [" ####","#  # ","# #  ","#    "," ### "],
    "H": ["#   #","#   #","#####","#   #","#   #"],
    "R": ["#### ","#   #","#### ","#  # ","#   #"],
    "S": [" ####","#    "," ### ","    #","#### "],
    "M": ["#   #","## ##","# # #","#   #","#   #"],
    "I": [" ### ","  #  ","  #  ","  #  "," ### "],
    "N": ["#   #","##  #","# # #","#  ##","#   #"],
    "E": ["#####","#    ","#### ","#    ","#####"],
    "C": [" ####","#    ","#    ","#    "," ####"],
    "B": ["#### ","#   #","#### ","#   #","#### "],
    "A": [" ### ","#   #","#####","#   #","#   #"],
    "K": ["#  # ","# #  ","##   ","# #  ","#  # "],
    "G": [" ####","#    ","#  ##","#   #"," ####"],
    "Y": ["#   #","#   #"," ### ","  #  ","  #  "],
    "O": [" ### ","#   #","#   #","#   #"," ### "],
    "U": ["#   #","#   #","#   #","#   #"," ### "],
    "D": ["###  ","#  # ","#  # ","#  # ","###  "],
    "V": ["#   #","#   #","#   #"," # # ","  #  "],
    "T": ["#####","  #  ","  #  ","  #  ","  #  "],
    "F": ["#####","#    ","#### ","#    ","#    "],
    "L": ["#    ","#    ","#    ","#    ","#####"],
    "P": ["#### ","#   #","#### ","#    ","#    "],
    "W": ["#   #","#   #","# # #","## ##","#   #"],
    "Q": [" ### ","#   #","# # #","#  # "," ####"],
    "Z": ["#####","   # ","  #  "," #   ","#####"],
]

private let BITMAPS: [Character: [UInt8]] = {
    var maps: [Character: [UInt8]] = [:]
    for (char, rows) in CHAR_MAP {
        var bitrows: [UInt8] = []
        for row in rows {
            var val: UInt8 = 0
            for (i, c) in row.enumerated() {
                if c == "#" { val |= (1 << (4 - i)) }
            }
            bitrows.append(val)
        }
        maps[char] = bitrows
    }
    return maps
}()

// MARK: - AsciiTextView
struct AsciiTextView: View {
    let text: String
    let color: Color
    var cellSize: Double = 1.2
    var scale: Double = 1.0
    
    var body: some View {
        TimelineView(.animation) { tl in
            Canvas { ctx, size in
                let t = tl.date.timeIntervalSinceReferenceDate
                renderAsciiString(ctx: ctx, str: text, cx: size.width/2, cy: size.height/2, 
                                  cellSize: cellSize, scale: scale, color: color, t: t)
            }
        }
    }
}

// MARK: - AsciiSlider
struct AsciiSlider: View {
    @ObservedObject var stopwatch: StopwatchManager
    let width: CGFloat
    
    private var sliderMax: Double {
        max(30, stopwatch.maxEarnedMinutes * 1.5)
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // Minutes Display
            VStack(spacing: 8) {
                AsciiTextView(text: "\(Int(stopwatch.dialedBreakMinutes)) MIN", 
                              color: colorForMinutes(stopwatch.dialedBreakMinutes),
                              cellSize: 3.0, scale: 1.0)
                    .frame(height: 40)
                
                Text(statusText)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(colorForMinutes(stopwatch.dialedBreakMinutes).opacity(0.8))
            }
            
            // The Slider Track
            TimelineView(.animation) { tl in
                Canvas { ctx, size in
                    let t = tl.date.timeIntervalSinceReferenceDate
                    let trackY = size.height / 2
                    let trackWidth = size.width
                    
                    let minPct = stopwatch.minEarnedMinutes / sliderMax
                    let maxPct = stopwatch.maxEarnedMinutes / sliderMax
                    
                    // Draw Track with ASCII dots
                    let dotSpacing: CGFloat = 8
                    let numDots = Int(trackWidth / dotSpacing)
                    for i in 0...numDots {
                        let x = CGFloat(i) * dotSpacing
                        let val = Double(x / trackWidth)
                        let isPassed = val <= (stopwatch.dialedBreakMinutes / sliderMax)
                        let isInEarnedRange = val >= minPct && val <= maxPct
                        
                        let char = isPassed ? "█" : "."
                        var color = isPassed ? colorForMinutes(stopwatch.dialedBreakMinutes) : Color(white: 0.15)
                        
                        // If not passed but in range, show range indicator
                        if !isPassed && isInEarnedRange {
                            color = Color.green.opacity(0.2)
                        }
                        
                        let fnt = Font.system(size: 6, weight: .bold, design: .monospaced)
                        ctx.draw(Text(char).font(fnt).foregroundColor(color), at: CGPoint(x: x, y: trackY))
                    }
                    
                    // Draw Thumb
                    let thumbX = CGFloat(stopwatch.dialedBreakMinutes / sliderMax) * trackWidth
                    renderAsciiString(ctx: ctx, str: "@", cx: thumbX, cy: trackY, cellSize: 4.0, scale: 1.2, color: .white, t: t)
                }
            }
            .drawingGroup()
            .frame(height: 30)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let percent = max(0, min(1, value.location.x / width))
                        stopwatch.dialedBreakMinutes = round(percent * sliderMax)
                    }
            )
        }
    }
    
    private var statusText: String {
        let mins = stopwatch.dialedBreakMinutes
        if mins < round(stopwatch.minEarnedMinutes) { return "You earned more!" }
        if mins <= round(stopwatch.maxEarnedMinutes) { return "Earned!" }
        return "Too long, unless you really need it."
    }
    
    private func colorForMinutes(_ mins: Double) -> Color {
        let minEarned = round(stopwatch.minEarnedMinutes)
        let maxEarned = round(stopwatch.maxEarnedMinutes)
        
        if mins < minEarned { return .orange }
        if mins <= maxEarned { return .green }
        return .red
    }
}

// Global helper for generic string rendering
private func renderAsciiString(ctx: GraphicsContext, str: String,
                                cx: Double, cy: Double,
                                cellSize: Double, scale: Double,
                                color: Color, t: Double) {
    let stepX  = Double(5 + 1) * cellSize * scale
    let totalW = Double(str.count) * stepX
    var ox     = cx - totalW / 2
    
    // Cache the base font
    let baseFontSize = cellSize * scale
    
    for ch in str.uppercased() {
        guard let bitrows = BITMAPS[ch] ?? BITMAPS[" "] else { continue }
        
        for row in 0..<5 {
            let rowBits = bitrows[row]
            for col in 0..<5 {
                if (rowBits & (1 << (4 - col))) != 0 {
                    let px = ox + Double(col) * cellSize * scale
                    let py = cy + (Double(row) - 2.5) * cellSize * scale

                    let jx    = sin(t * 2.1 + Double(col) * 0.4 + ox / 40) * cellSize * 0.12 * scale
                    let jy    = cos(t * 1.7 + Double(row) * 0.5 + cy / 40) * cellSize * 0.1  * scale
                    let jz    = sin(t * 1.5 + Double(col) * 0.4 + Double(row) * 0.3 + ox / 50) * 0.75
                    let depth = max(0, min(1, (jz + 1.5) / 3.0))

                    let fSize = max(2.5, baseFontSize * (0.75 + depth * 0.4))
                    let fnt   = Font.system(size: fSize, weight: .bold, design: .monospaced)
                    let charVal = 0.5 + depth * 0.5
                    let rampIdx = max(0, min(RAMP.count - 1, Int(charVal * Double(RAMP.count - 1))))
                    let ascii = String(RAMP[rampIdx])
                    let fx    = px + jx
                    let fy    = py + jy

                    ctx.draw(
                        Text(ascii).font(fnt).foregroundColor(color.opacity(0.4 + depth * 0.6)),
                        at: CGPoint(x: fx, y: fy)
                    )
                }
            }
        }
        ox += stepX
    }
}

// MARK: - Theme Views
struct AsciiThemeView: View {
    @ObservedObject var stopwatch: StopwatchManager

    private var textColor: Color {
        stopwatch.themeManager.currentTheme?.isLight ?? false ? .black : .white
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                if stopwatch.showBreakSelection {
                    VStack(spacing: 0) {
                        HStack {
                            Button(action: { 
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                                    stopwatch.showBreakSelection = false 
                                }
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(textColor.opacity(0.3))
                                    .padding(24)
                            }
                            Spacer()
                        }
                        
                        Spacer()
                        
                        VStack(spacing: 30) {
                            AsciiSlider(stopwatch: stopwatch, width: geo.size.width - 80)
                                .frame(width: geo.size.width - 80, height: 150)
                            Button(action: { stopwatch.startBreak() }) {
                                AsciiTextView(text: "Start Break", color: textColor, cellSize: 2.5)
                                    .frame(width: 250, height: 50)
                                    .padding(.horizontal, 40)
                                    .padding(.vertical, 16)
                                    .background(
                                        Capsule()
                                            .fill(colorForMinutes(stopwatch.dialedBreakMinutes).opacity(0.15))
                                            .overlay(Capsule().stroke(colorForMinutes(stopwatch.dialedBreakMinutes).opacity(0.5), lineWidth: 1))
                                    )
                            }
                        }
                        
                        Spacer()
                    }
                    .frame(width: geo.size.width, height: geo.size.height)
                    .transition(.asymmetric(insertion: .move(edge: .bottom).combined(with: .opacity), removal: .opacity))
                } else {
                    let side = min(geo.size.width, geo.size.height)
                    AsciiJellyCanvas(stopwatch: stopwatch)
                        .frame(width: side, height: side)
                        .position(x: geo.size.width / 2, y: geo.size.height / 2)
                        .transition(.opacity)
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.85), value: stopwatch.showBreakSelection)
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


// MARK: - Canvas View
struct AsciiJellyCanvas: View {
    @ObservedObject var stopwatch: StopwatchManager
    @State private var revealStart: Double? = nil

    var body: some View {
        TimelineView(.animation) { tl in
            Canvas { ctx, size in
                let t  = tl.date.timeIntervalSinceReferenceDate
                let cx = size.width  / 2
                let cy = size.height / 2

                // Flash overlay
                if stopwatch.flash > 0 {
                    ctx.fill(
                        Path(ellipseIn: CGRect(origin: .zero, size: size)),
                        with: .color(Color.white.opacity(stopwatch.flash * 0.06))
                    )
                }


                // Rings — inner to outer (pushed out to avoid clashing)
                let activeElapsed = stopwatch.isBreakActive ? stopwatch.breakTime : stopwatch.elapsedTime
                let visualRings: [(r: Double, period: Double, color: Color, dim: Color)] = [
                    (size.width * 0.35, 60,       
                     Color(red: 0.0, green: 0.6, blue: 1.0), // Seconds (always blue)
                     .clear),
                    (size.width * 0.41, 3600,     
                     Color(red: 0.2, green: 0.8, blue: 0.3), // Minutes (always green)
                     .clear),
                    (size.width * 0.47, 43200,    
                     Color(red: 1.0, green: 0.2, blue: 0.3), // Hours (always red)
                     .clear),
                ]
                
                let revealFactor: Double = {
                    guard let start = revealStart else { return 1.0 }
                    let dt = t - start
                    return dt >= 1.0 ? 1.0 : max(0, dt / 1.0)
                }()

                for ring in visualRings {
                    drawJellyRing(ctx: ctx, cx: cx, cy: cy,
                                  radius: ring.r, period: ring.period,
                                  color: ring.color, dim: ring.dim,
                                  elapsed: activeElapsed, revealFactor: revealFactor, t: t, size: size)
                }

                drawDigitDisplay(ctx: ctx, cx: cx, cy: cy,
                                 elapsed: activeElapsed,
                                 t: t, size: size, isBreak: stopwatch.isBreakActive)
            }
        }
        .onChange(of: stopwatch.isRunning) { _, running in
            guard running else { return }
            revealStart = Date.timeIntervalSinceReferenceDate
        }
    }

    // MARK: Tick marks
    private func drawTicks(ctx: GraphicsContext, cx: Double, cy: Double, radius: Double, size: CGSize) {
        let sz  = max(4.0, size.width * 0.011)
        let fnt = Font.system(size: sz, weight: .bold, design: .monospaced)
        for i in 0..<60 {
            let angle = Double(i) / 60.0 * .pi * 2 - .pi / 2
            let isMaj = i % 5 == 0
            let x = cx + cos(angle) * radius
            let y = cy + sin(angle) * radius
            ctx.draw(
                Text(isMaj ? "|" : ".").font(fnt)
                    .foregroundColor(textColor.opacity(isMaj ? 0.22 : 0.07)),
                at: CGPoint(x: x, y: y)
            )
        }
    }

    // MARK: Jelly Ring
    private func drawJellyRing(ctx: GraphicsContext, cx: Double, cy: Double,
                                radius: Double, period: Double,
                                color: Color, dim: Color,
                                elapsed: TimeInterval, revealFactor: Double, t: Double, size: CGSize) {
        let nPts       = 90
        let prog       = (elapsed / period).truncatingRemainder(dividingBy: 1.0) * revealFactor
        let activeCount = Int(prog * Double(nPts))
        let cellSize   = max(2.5, size.width * 0.008)
        let fnt        = Font.system(size: cellSize, weight: .bold, design: .monospaced)

        for i in 0..<nPts {
            let baseAngle = Double(i) / Double(nPts) * .pi * 2 - .pi / 2
            let progCurrent = prog
            let isActive = Double(i) / Double(nPts) <= progCurrent

            // Skip drawing inactive dots entirely — they were forming a faint grey ring
            guard isActive else { continue }

            let ph  = Double(i) * 0.43 + 1.0
            let ph2 = Double(i) * 0.71 + 2.5
            let ph3 = Double(i) * 0.29 + 0.8
            let amp = 1.0

            let wobR  = sin(t * 1.4 + ph)  * radius * 0.02 * amp
            let wave1 = sin(t * 1.8 + ph)  * cellSize * 0.45  * amp
            let wave2 = cos(t * 2.3 + ph2) * cellSize * 0.35  * amp
            let wave3 = sin(t * 1.1 + ph3) * cellSize * 0.55  * amp

            let px = cx + cos(baseAngle) * (radius + wobR) + wave1
            let py = cy + sin(baseAngle) * (radius + wobR) + wave2

            let depth     = max(0, min(1, (wave3 + cellSize) / (cellSize * 2)))

            let charVal   = 0.5 + depth * 0.5
            let ch        = String(rampChar(charVal))
            let alpha     = 0.45 + depth * 0.55
            let shadowOff = (1 - depth) * 2.5

            ctx.draw(
                Text(ch).font(fnt).foregroundColor(Color.black.opacity(alpha * 0.3)),
                at: CGPoint(x: px + shadowOff, y: py + shadowOff)
            )

            ctx.draw(
                Text(ch).font(fnt).foregroundColor(color.opacity(0.5 + depth * 0.5)),
                at: CGPoint(x: px, y: py)
            )

            if depth > 0.55 {
                ctx.draw(
                    Text(String(rampChar(0.9))).font(fnt)
                        .foregroundColor(Color.white.opacity((depth - 0.55) * 1.6 * 0.75)),
                    at: CGPoint(x: px - 0.5, y: py - 0.5)
                )
            }
        }

        if activeCount > 0 && activeCount < nPts {
            let i         = activeCount - 1
            let baseAngle = Double(i) / Double(nPts) * .pi * 2 - .pi / 2
            let ph        = Double(i) * 0.43 + 1.0
            let wobR      = sin(t * 1.4 + ph) * radius * 0.045
            let wave1     = sin(t * 1.8 + ph) * cellSize * 0.9
            let wave2     = cos(t * 2.3 + ph) * cellSize * 0.7
            let tx = cx + cos(baseAngle) * (radius + wobR) + wave1
            let ty = cy + sin(baseAngle) * (radius + wobR) + wave2
            ctx.draw(
                Text("@").font(.system(size: cellSize + 2, weight: .bold, design: .monospaced))
                    .foregroundColor(textColor),
                at: CGPoint(x: tx, y: ty)
            )
        }
    }

    private var textColor: Color {
        stopwatch.themeManager.currentTheme?.isLight ?? false ? .black : .white
    }

    private func drawDigitDisplay(ctx: GraphicsContext, cx: Double, cy: Double,
                                   elapsed: TimeInterval, t: Double, size: CGSize, isBreak: Bool) {
        let h  = Int(elapsed / 3600)
        let m  = Int(elapsed / 60) % 60
        let s  = Int(elapsed) % 60
        let cs = Int((elapsed - floor(elapsed)) * 100)

        let mainStr = String(format: "%02d:%02d:%02d", h, m, s)
        let subStr  = String(format: ".%02d", cs)

        let cell = max(4.0, size.width * 0.016)

        renderAsciiString(ctx: ctx, str: mainStr, cx: cx, cy: cy - cell * 2.0, cellSize: cell, scale: 1.2, color: textColor, t: t)
        renderAsciiString(ctx: ctx, str: subStr, cx: cx + cell * 3.0, cy: cy + cell * 6.5, cellSize: cell, scale: 0.8, color: textColor.opacity(0.5), t: t)

        let lbls: [(String, Color, Double)] = [
            ("Hrs", Color(red: 1.0, green: 0.2, blue: 0.3), cx - cell * 8),
            ("Min", Color(red: 0.2, green: 0.8, blue: 0.3), cx),
            ("Sec", Color(red: 0.0, green: 0.6, blue: 1.0), cx + cell * 8),
        ]
        for (lbl, col, lx) in lbls {
            renderAsciiString(ctx: ctx, str: lbl, cx: lx, cy: cy + cell * 10.5, cellSize: cell, scale: 0.45, color: col.opacity(0.8), t: t)
        }
        
        if isBreak {
            renderAsciiString(ctx: ctx, str: "Break", cx: cx, cy: cy + cell * 14.0, cellSize: cell, scale: 0.5, color: Color.blue.opacity(0.8), t: t)
        } else if stopwatch.isRunning {
            renderAsciiString(ctx: ctx, str: "Focus", cx: cx, cy: cy + cell * 14.0, cellSize: cell, scale: 0.5, color: Color.green.opacity(0.8), t: t)
        } else {
            renderAsciiString(ctx: ctx, str: "Paused", cx: cx, cy: cy + cell * 14.0, cellSize: cell, scale: 0.5, color: Color.orange.opacity(0.8), t: t)
        }
    }
}
