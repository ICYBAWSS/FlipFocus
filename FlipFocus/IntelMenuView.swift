import SwiftUI

struct IntelMenuView: View {
    @ObservedObject var stopwatch: StopwatchManager
    @Environment(\.dismiss) var dismiss
    @State private var selectedTimeFrame: TimeFrame = .week

    private var totalFocusTime: TimeInterval {
        stopwatch.sessions.reduce(0) { $0 + $1.focusDuration }
    }
    private var totalBreakTime: TimeInterval {
        stopwatch.sessions.reduce(0) { $0 + $1.breakDuration }
    }
    private var weeklyFocusTime: TimeInterval {
        let cutoff = Date().addingTimeInterval(-7 * 24 * 3600)
        return stopwatch.sessions.filter { $0.startTime > cutoff }.reduce(0) { $0 + $1.focusDuration }
    }
    private var avgDailyFocusTime: TimeInterval {
        guard let first = stopwatch.sessions.map({ $0.startTime }).min() else { return 0 }
        return totalFocusTime / max(1.0, Date().timeIntervalSince(first) / 86400)
    }
    private var sessionsPerDay: Double {
        guard let first = stopwatch.sessions.map({ $0.startTime }).min() else { return 0 }
        return Double(stopwatch.sessions.count) / max(1.0, Date().timeIntervalSince(first) / 86400)
    }

    var body: some View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 32) {

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Stats for nerds")
                            .font(helvetica(11, .bold))
                            .foregroundColor(.secondary)
                        Text("Statistics")
                            .font(helvetica(48, .bold))
                    }
                    .padding(.horizontal, 24)

                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            MenuLabel(text: "Activity History")
                            Spacer()
                            HStack(spacing: 4) {
                                ForEach(TimeFrame.allCases) { tf in
                                    Button(action: { selectedTimeFrame = tf }) {
                                        Text(tf.rawValue)
                                            .font(helvetica(11, .semibold))
                                            .fixedSize(horizontal: true, vertical: false)
                                            .padding(.horizontal, 10).padding(.vertical, 6)
                                            .background(Capsule().fill(selectedTimeFrame == tf ? Color.blue : Color.primary.opacity(0.04)))
                                            .foregroundColor(selectedTimeFrame == tf ? .white : .secondary)
                                    }
                                    .animation(.easeInOut(duration: 0.15), value: selectedTimeFrame)
                                }
                            }
                        }
                        FilledLineGraph(sessions: stopwatch.sessions, timeFrame: selectedTimeFrame)
                            .frame(height: 150)
                            .padding(20)
                            .glassCard()
                    }
                    .padding(.horizontal, 24)

                    VStack(alignment: .leading, spacing: 10) {
                        MenuLabel(text: "Data Breakdown").padding(.horizontal, 24)
                        VStack(spacing: 0) {
                            AnalyticsRow(label: "Average daily focus", value: formatTimeShort(avgDailyFocusTime))
                            AnalyticsRow(label: "Weekly Focus",    value: formatTimeShort(weeklyFocusTime))
                            AnalyticsRow(label: "Total Focus",     value: formatTimeShort(totalFocusTime))
                            AnalyticsRow(label: "Sessions Per Day",  value: String(format: "%.1f", sessionsPerDay))
                            AnalyticsRow(label: "Focus To Break Ratio",   value: String(format: "%.1f : 1", totalFocusTime / max(1, totalBreakTime)))
                        }
                        .glassCard()
                        .padding(.horizontal, 24)
                    }

                    Spacer(minLength: 40)
                }
                .padding(.top, 40)
            }
            .scrollContentBackground(.hidden)
            .background(.clear)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(helvetica(15, .semibold))
                }
            }
        }
        .background(.clear)
    }

    private func formatTimeShort(_ time: TimeInterval) -> String {
        let h = Int(time) / 3600; let m = (Int(time) % 3600) / 60
        return h > 0 ? "\(h)h \(m)m" : "\(m)m"
    }
}
