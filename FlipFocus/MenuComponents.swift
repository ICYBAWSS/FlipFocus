import SwiftUI

// MARK: - Ring Reveal
/// How far through the flip-over ring reveal we are, 0 → 1, eased so the arcs settle
/// into place. Returns 1 (no reveal) when there was no flip.
func ringRevealFactor(since start: Double?, at t: Double, duration: Double = 1.0) -> Double {
    guard let start else { return 1.0 }
    let p = min(1.0, max(0, (t - start) / duration))
    return p * p * (3 - 2 * p)   // smoothstep: gentle start, no snap at the end
}

// MARK: - Liquid Glass Atmosphere
struct ThemeAtmosphere: View {
    let isLight: Bool
    var body: some View {
        Color.clear
            .background(.ultraThinMaterial)
            .ignoresSafeArea()
    }
}

// MARK: - Shared Analytics UI Components
struct MenuLabel: View {
    let text: String
    var body: some View {
        Text(text)
            .font(helvetica(10, .bold))
            .foregroundColor(.secondary)
    }
}

struct AnalyticsRow: View {
    let label: String
    let value: String
    var body: some View {
        HStack {
            Text(label)
                .font(helvetica(13, .medium))
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(helvetica(14, .bold))
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 15)
        .background(Color.primary.opacity(0.015))
    }
}

// MARK: - Glass Card Modifier
struct GlassCardModifier: ViewModifier {
    var tint: Color = .clear
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(tint == .clear ? Color.primary.opacity(0.04) : tint)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.5)
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

extension View {
    func glassCard(tint: Color = .clear) -> some View {
        modifier(GlassCardModifier(tint: tint))
    }
}

// MARK: - Filled Line Graph
struct FilledLineGraph: View {
    let sessions: [FocusSession]
    let timeFrame: TimeFrame

    // Pre-compute outside of drawing
    private var dataPoints: [Double] {
        let calendar = Calendar.current
        let now = Date()

        switch timeFrame {
        case .week:
            var points = [Double](repeating: 0, count: 7)
            for s in sessions {
                let diff = calendar.dateComponents([.day],
                    from: calendar.startOfDay(for: s.startTime),
                    to: calendar.startOfDay(for: now)).day ?? 10
                if diff < 7 { points[6 - diff] += s.focusDuration }
            }
            return points
        case .month:
            var points = [Double](repeating: 0, count: 30)
            let startOfToday = calendar.startOfDay(for: now)
            for s in sessions {
                let sessionDay = calendar.startOfDay(for: s.startTime)
                let diff = calendar.dateComponents([.day], from: sessionDay, to: startOfToday).day ?? 40
                if diff < 30 { points[29 - diff] += s.focusDuration }
            }
            return points
        case .year:
            var points = [Double](repeating: 0, count: 12)
            let currentMonthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
            for s in sessions {
                let sessionMonthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: s.startTime))!
                let diff = calendar.dateComponents([.month], from: sessionMonthStart, to: currentMonthStart).month ?? 20
                if diff < 12 { points[11 - diff] += s.focusDuration }
            }
            return points
        case .all:
            guard let first = sessions.map({ $0.startTime }).min() else { return [0, 0] }
            let totalDays = max(2, Int(now.timeIntervalSince(first) / (24 * 3600)) + 1)
            var points = [Double](repeating: 0, count: min(totalDays, 30))
            let stride = Double(totalDays) / Double(points.count)
            for s in sessions {
                let dayIndex = Int(now.timeIntervalSince(s.startTime) / (24 * 3600))
                let pointIndex = points.count - 1 - Int(Double(dayIndex) / stride)
                if pointIndex >= 0 && pointIndex < points.count {
                    points[pointIndex] += s.focusDuration
                }
            }
            return points
        }
    }

    var body: some View {
        let points = dataPoints
        let maxVal = max(60, points.max() ?? 0)

        GeometryReader { geo in
            let stepX = geo.size.width / CGFloat(max(1, points.count - 1))

            ZStack {
                // Grid lines — static, no animation
                VStack(spacing: 0) {
                    ForEach(0..<4) { _ in
                        Spacer()
                        Rectangle()
                            .fill(Color.white.opacity(0.03))
                            .frame(height: 0.5)
                    }
                    Spacer()
                }

                // Filled area
                Path { path in
                    path.move(to: CGPoint(x: 0, y: geo.size.height))
                    for i in 0..<points.count {
                        let x = CGFloat(i) * stepX
                        let y = geo.size.height - (CGFloat(points[i] / maxVal) * geo.size.height)
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                    path.addLine(to: CGPoint(x: geo.size.width, y: geo.size.height))
                    path.closeSubpath()
                }
                .fill(
                    LinearGradient(
                        colors: [Color.blue.opacity(0.28), Color.blue.opacity(0.0)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

                // Stroke line
                Path { path in
                    for i in 0..<points.count {
                        let x = CGFloat(i) * stepX
                        let y = geo.size.height - (CGFloat(points[i] / maxVal) * geo.size.height)
                        if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
                        else { path.addLine(to: CGPoint(x: x, y: y)) }
                    }
                }
                .stroke(Color.blue.opacity(0.7), style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))

                // Dots at each data point
                ForEach(0..<points.count, id: \.self) { i in
                    let x = CGFloat(i) * stepX
                    let y = geo.size.height - (CGFloat(points[i] / maxVal) * geo.size.height)
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 4, height: 4)
                        .position(x: x, y: y)
                        .opacity(points[i] > 0 ? 1 : 0)
                }
            }
        }
        .drawingGroup()
    }
}

// MARK: - Goal Calendar
struct GoalCalendar: View {
    let focusMap: [Date: TimeInterval]
    let goal: Double
    let mode: CalendarMode

    private let calendar = Calendar.current
    private let now = Date()

    var body: some View {
        Group {
            if mode == .month {
                monthGridView
            } else {
                yearGridView
            }
        }
        .id(mode)
    }

    private var monthGridView: some View {
        let days = daysInMonth(for: now)
        let columns = Array(repeating: GridItem(.flexible(), spacing: 5), count: 7)

        return LazyVGrid(columns: columns, spacing: 5) {
            ForEach(0..<days.count, id: \.self) { i in
                if let date = days[i] {
                    DayCell(date: date, duration: focusMap[date] ?? 0, goal: goal * 60)
                        .id(date)
                } else {
                    Color.clear.aspectRatio(1, contentMode: .fit)
                }
            }
        }
    }

    private var yearGridView: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 4)
        return LazyVGrid(columns: columns, spacing: 10) {
            ForEach(0..<12) { i in
                monthMiniView(offset: 11 - i)
                    .id(i)
            }
        }
    }

    private func monthMiniView(offset: Int) -> some View {
        let monthDate = calendar.date(byAdding: .month, value: -offset, to: now)!
        let days = daysInMonth(for: monthDate)
        let columns = Array(repeating: GridItem(.fixed(5), spacing: 2), count: 7)

        return VStack(alignment: .leading, spacing: 3) {
            Text(monthName(for: monthDate))
                .font(helvetica(7, .bold))
                .foregroundColor(.white.opacity(0.5))

            LazyVGrid(columns: columns, spacing: 2) {
                ForEach(0..<days.count, id: \.self) { i in
                    if let date = days[i] {
                        let hit = (focusMap[date] ?? 0) >= (goal * 60)
                        let isPast = date <= now
                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(hit ? Color.green : (isPast ? Color.red.opacity(0.15) : Color.white.opacity(0.03)))
                            .frame(width: 5, height: 5)
                    } else {
                        Color.clear.frame(width: 5, height: 5)
                    }
                }
            }
        }
    }

    private func daysInMonth(for date: Date) -> [Date?] {
        let range = calendar.range(of: .day, in: .month, for: date)!
        let components = calendar.dateComponents([.year, .month], from: date)
        let startOfMonth = calendar.date(from: components)!
        let weekday = calendar.component(.weekday, from: startOfMonth)

        var days: [Date?] = Array(repeating: nil, count: weekday - 1)
        for day in range {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: startOfMonth) {
                days.append(calendar.startOfDay(for: date))
            }
        }
        return days
    }

    private func monthName(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM ''yy"
        return formatter.string(from: date)
    }
}

struct DayCell: View {
    let date: Date
    let duration: TimeInterval
    let goal: Double
    private var isToday: Bool { Calendar.current.isDateInToday(date) }
    private var hitGoal: Bool { duration >= goal }
    private var isPast: Bool { date < Calendar.current.startOfDay(for: Date()) }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(hitGoal
                    ? Color.green.opacity(0.75)
                    : (isPast ? Color.red.opacity(0.12) : Color.white.opacity(0.04)))
                .aspectRatio(1, contentMode: .fit)
                .overlay(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .strokeBorder(isToday ? Color.blue.opacity(0.8) : .clear, lineWidth: 1.5)
                )

            Text("\(Calendar.current.component(.day, from: date))")
                .font(helvetica(9, .semibold))
                .foregroundColor(hitGoal ? .black : (isToday ? .blue : .white.opacity(0.45)))
        }
    }
}
