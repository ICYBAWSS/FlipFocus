import SwiftUI

struct StreakMenuView: View {
    @ObservedObject var stopwatch: StopwatchManager
    @Environment(\.dismiss) var dismiss
    @State private var calendarMode: CalendarMode = .month
    
    private var dailyFocusMap: [Date: TimeInterval] {
        let calendar = Calendar.current
        return Dictionary(grouping: stopwatch.sessions) { calendar.startOfDay(for: $0.startTime) }
            .mapValues { $0.reduce(0) { $0 + $1.focusDuration } }
    }
    
    private var longestStreak: Int {
        let calendar = Calendar.current
        let goalSeconds = stopwatch.dailyGoal * 60
        let qualifyingDates = dailyFocusMap.filter { $0.value >= goalSeconds }.keys.sorted(by: >)
            
        guard !qualifyingDates.isEmpty else { return 0 }
        var longest = 0, current = 0, lastDate: Date?
        for date in qualifyingDates {
            if let last = lastDate {
                if (calendar.dateComponents([.day], from: date, to: last).day ?? 0) == 1 { current += 1 }
                else { longest = max(longest, current); current = 1 }
            } else { current = 1 }
            lastDate = date
        }
        return max(longest, current)
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 32) {
                        // Current Streak Display
                        VStack(spacing: 8) {
                            Text("\(longestStreak)")
                                .font(.system(size: 60, weight: .black, design: .monospaced))
                                .foregroundColor(.orange)
                            Text("DAY STREAK")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundColor(.white.opacity(0.4))
                                .kerning(2)
                        }
                        .padding(.vertical, 20)

                        // Goal Calendar Section
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                MenuLabel(text: "GOAL CALENDAR")
                                Spacer()
                                HStack(spacing: 4) {
                                    ForEach(CalendarMode.allCases) { mode in
                                        Button(action: { calendarMode = mode }) {
                                            Text(mode.rawValue)
                                                .font(.system(size: 8, weight: .bold, design: .monospaced))
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 4)
                                                .background(calendarMode == mode ? Color.green.opacity(0.2) : Color.clear)
                                                .cornerRadius(2)
                                                .foregroundColor(calendarMode == mode ? .green : .white.opacity(0.3))
                                        }
                                    }
                                }
                            }
                            
                            GoalCalendar(focusMap: dailyFocusMap, goal: stopwatch.dailyGoal, mode: calendarMode)
                                .padding()
                                .background(Color.white.opacity(0.03))
                                .cornerRadius(8)
                        }
                        .padding(.horizontal)

                        // Streak Settings
                        VStack(alignment: .leading, spacing: 12) {
                            MenuLabel(text: "STREAK SETTINGS")
                            VStack(alignment: .leading, spacing: 16) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("DAILY FOCUS GOAL")
                                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                                            .foregroundColor(.white.opacity(0.6))
                                        Text("\(Int(stopwatch.dailyGoal)) MINUTES")
                                            .font(.system(size: 14, weight: .black, design: .monospaced))
                                            .foregroundColor(.blue)
                                    }
                                    Spacer()
                                    HStack(spacing: 20) {
                                        Button(action: { stopwatch.dailyGoal = max(10, stopwatch.dailyGoal - 10) }) {
                                            Image(systemName: "minus.square.fill").font(.title2).foregroundColor(.white.opacity(0.2))
                                        }
                                        Button(action: { stopwatch.dailyGoal = min(480, stopwatch.dailyGoal + 10) }) {
                                            Image(systemName: "plus.square.fill").font(.title2).foregroundColor(.white.opacity(0.2))
                                        }
                                    }
                                }
                                Text("A day only counts toward your streak if you focus for at least \(Int(stopwatch.dailyGoal)) minutes.")
                                    .font(.system(size: 8, weight: .medium, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.3))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding()
                            .background(Color.white.opacity(0.03))
                            .cornerRadius(8)
                        }
                        .padding(.horizontal)
                    }
                    .padding(.vertical, 20)
                }
            }
            .navigationTitle("STREAKS")
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
}
