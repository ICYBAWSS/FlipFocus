import SwiftUI

struct IntelMenuView: View {
    @ObservedObject var stopwatch: StopwatchManager
    @Environment(\.dismiss) var dismiss
    @State private var selectedTimeFrame: TimeFrame = .week
    
    // Analytics Calculations (Copied from former MenuView)
    private var dailyFocusMap: [Date: TimeInterval] {
        let calendar = Calendar.current
        return Dictionary(grouping: stopwatch.sessions) { calendar.startOfDay(for: $0.startTime) }
            .mapValues { $0.reduce(0) { $0 + $1.focusDuration } }
    }
    
    private var totalFocusTime: TimeInterval {
        stopwatch.sessions.reduce(0) { $0 + $1.focusDuration }
    }
    
    private var totalBreakTime: TimeInterval {
        stopwatch.sessions.reduce(0) { $0 + $1.breakDuration }
    }
    
    private var avgFocusToBreakRatio: Double {
        guard !stopwatch.sessions.isEmpty else { return 0 }
        let ratios = stopwatch.sessions.compactMap { s -> Double? in
            guard s.breakDuration > 0 else { return nil }
            return s.focusDuration / s.breakDuration
        }
        return ratios.reduce(0, +) / Double(max(1, ratios.count))
    }
    
    private var weeklyFocusTime: TimeInterval {
        let lastWeek = Date().addingTimeInterval(-7 * 24 * 3600)
        return stopwatch.sessions
            .filter { $0.startTime > lastWeek }
            .reduce(0) { $0 + $1.focusDuration }
    }
    
    private var avgDailyFocusTime: TimeInterval {
        guard let firstSession = stopwatch.sessions.map({ $0.startTime }).min() else { return 0 }
        let days = max(1.0, Date().timeIntervalSince(firstSession) / (24 * 3600))
        return totalFocusTime / days
    }
    
    private var sessionsPerDay: Double {
        guard let firstSession = stopwatch.sessions.map({ $0.startTime }).min() else { return 0 }
        let days = max(1.0, Date().timeIntervalSince(firstSession) / (24 * 3600))
        return Double(stopwatch.sessions.count) / days
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 32) {
                        // Line Graph Section
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                MenuLabel(text: "ACTIVITY")
                                Spacer()
                                HStack(spacing: 4) {
                                    ForEach(TimeFrame.allCases) { tf in
                                        Button(action: { selectedTimeFrame = tf }) {
                                            Text(tf.rawValue)
                                                .font(.system(size: 8, weight: .bold, design: .monospaced))
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 4)
                                                .background(selectedTimeFrame == tf ? Color.blue.opacity(0.2) : Color.clear)
                                                .cornerRadius(2)
                                                .foregroundColor(selectedTimeFrame == tf ? .blue : .white.opacity(0.3))
                                        }
                                    }
                                }
                            }
                            
                            FilledLineGraph(sessions: stopwatch.sessions, timeFrame: selectedTimeFrame)
                                .frame(height: 150)
                                .padding(.vertical, 20)
                                .background(Color.white.opacity(0.02))
                                .cornerRadius(8)
                        }
                        .padding(.horizontal)

                        // Analytics Stats
                        VStack(alignment: .leading, spacing: 12) {
                            MenuLabel(text: "DETAILED STATS")
                            VStack(spacing: 1) {
                                AnalyticsRow(label: "AVG DAILY FOCUS", value: formatTimeShort(avgDailyFocusTime))
                                AnalyticsRow(label: "WEEKLY FOCUS", value: formatTimeShort(weeklyFocusTime))
                                AnalyticsRow(label: "TOTAL FOCUS", value: formatTimeShort(totalFocusTime))
                                AnalyticsRow(label: "SESSIONS / DAY", value: String(format: "%.1f", sessionsPerDay))
                                AnalyticsRow(label: "TOTAL F/B RATIO", value: String(format: "%.1f", totalFocusTime / max(1, totalBreakTime)))
                                AnalyticsRow(label: "AVG F/B RATIO", value: String(format: "%.1f", avgFocusToBreakRatio))
                            }
                            .background(Color.white.opacity(0.03))
                            .cornerRadius(8)
                        }
                        .padding(.horizontal)
                        
                        // Reset Button
                        Button(action: {
                            stopwatch.sessions = []
                            UserDefaults.standard.removeObject(forKey: "saved_sessions")
                        }) {
                            Text("CLEAR ALL INTEL")
                                .font(.system(size: 8, weight: .bold, design: .monospaced))
                                .foregroundColor(.red.opacity(0.5))
                                .padding()
                        }
                    }
                    .padding(.vertical, 20)
                }
            }
            .navigationTitle("INTEL")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("DONE") { dismiss() }
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(.blue)
                }
            }
        }
    }
    
    private func formatTimeShort(_ time: TimeInterval) -> String {
        let h = Int(time) / 3600
        let m = (Int(time) % 3600) / 60
        return h > 0 ? "\(h)h \(m)m" : "\(m)m"
    }
}
