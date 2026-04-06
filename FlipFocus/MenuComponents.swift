import SwiftUI

// MARK: - Shared Analytics UI Components
struct MenuLabel: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.system(size: 8, weight: .black, design: .monospaced))
            .foregroundColor(.white.opacity(0.3))
            .kerning(1.5)
    }
}

struct AnalyticsRow: View {
    let label: String
    let value: String
    var body: some View {
        HStack {
            Text(label).font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundColor(.white.opacity(0.4))
            Spacer()
            Text(value).font(.system(size: 10, weight: .bold, design: .monospaced)).foregroundColor(.white)
        }
        .padding(.horizontal).padding(.vertical, 12)
        .border(Color.white.opacity(0.02), width: 0.5)
    }
}

// MARK: - Filled Line Graph
struct FilledLineGraph: View {
    let sessions: [FocusSession]
    let timeFrame: TimeFrame
    
    private var dataPoints: [Double] {
        let calendar = Calendar.current
        let now = Date()
        
        switch timeFrame {
        case .week:
            var points = [Double](repeating: 0, count: 7)
            for s in sessions {
                let diff = calendar.dateComponents([.day], from: calendar.startOfDay(for: s.startTime), to: calendar.startOfDay(for: now)).day ?? 10
                if diff < 7 { points[6 - diff] += s.focusDuration }
            }
            return points
        case .year:
            var points = [Double](repeating: 0, count: 12)
            for s in sessions {
                let diff = calendar.dateComponents([.month], from: s.startTime, to: now).month ?? 20
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
        GeometryReader { geo in
            let points = dataPoints
            let maxVal = max(60, points.max() ?? 0)
            let stepX = geo.size.width / CGFloat(max(1, points.count - 1))
            
            ZStack {
                VStack {
                    ForEach(0..<4) { _ in
                        Divider().background(Color.white.opacity(0.05))
                        Spacer()
                    }
                }
                
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
                .fill(LinearGradient(colors: [Color.blue.opacity(0.3), Color.blue.opacity(0.0)], startPoint: .top, endPoint: .bottom))
                
                Path { path in
                    for i in 0..<points.count {
                        let x = CGFloat(i) * stepX
                        let y = geo.size.height - (CGFloat(points[i] / maxVal) * geo.size.height)
                        if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
                        else { path.addLine(to: CGPoint(x: x, y: y)) }
                    }
                }
                .stroke(Color.blue.opacity(0.6), lineWidth: 2)
            }
        }
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
        if mode == .month {
            monthGridView
        } else {
            yearGridView
        }
    }
    
    private var monthGridView: some View {
        let days = daysInMonth(for: now)
        let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
        
        return LazyVGrid(columns: columns, spacing: 4) {
            ForEach(0..<days.count, id: \.self) { i in
                if let date = days[i] {
                    DayCell(date: date, duration: focusMap[date] ?? 0, goal: goal * 60)
                } else {
                    Color.clear.aspectRatio(1, contentMode: .fit)
                }
            }
        }
    }
    
    private var yearGridView: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 4)
        return LazyVGrid(columns: columns, spacing: 8) {
            ForEach(0..<12) { i in
                monthMiniView(offset: i)
            }
        }
    }
    
    private func monthMiniView(offset: Int) -> some View {
        let monthDate = calendar.date(byAdding: .month, value: -offset, to: now)!
        let days = daysInMonth(for: monthDate)
        let columns = Array(repeating: GridItem(.fixed(4), spacing: 1), count: 7)
        
        return VStack(alignment: .leading, spacing: 2) {
            Text(monthName(for: monthDate))
                .font(.system(size: 6, weight: .bold, design: .monospaced))
                .foregroundColor(.white.opacity(0.4))
            
            LazyVGrid(columns: columns, spacing: 1) {
                ForEach(0..<days.count, id: \.self) { i in
                    if let date = days[i] {
                        let hit = (focusMap[date] ?? 0) >= (goal * 60)
                        let isPast = date <= now
                        Rectangle()
                            .fill(hit ? Color.green : (isPast ? Color.red.opacity(0.3) : Color.white.opacity(0.05)))
                            .frame(width: 4, height: 4)
                    } else {
                        Color.clear.frame(width: 4, height: 4)
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
        formatter.dateFormat = "MMM"
        return formatter.string(from: date).uppercased()
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
            RoundedRectangle(cornerRadius: 2)
                .fill(hitGoal ? Color.green.opacity(0.8) : (isPast ? Color.red.opacity(0.2) : Color.white.opacity(0.05)))
                .aspectRatio(1, contentMode: .fit)
            Text("\(Calendar.current.component(.day, from: date))")
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundColor(hitGoal ? .black : (isToday ? .blue : .white.opacity(0.5)))
        }
    }
}
