import SwiftUI

struct StreakMenuView: View {
    @ObservedObject var stopwatch: StopwatchManager
    @Environment(\.dismiss) var dismiss
    @State private var calendarMode: CalendarMode = .month

    private var dailyFocusMap: [Date: TimeInterval] {
        let cal = Calendar.current
        return Dictionary(grouping: stopwatch.sessions) {
            cal.startOfDay(for: $0.startTime)
        }.mapValues { $0.reduce(0) { $0 + $1.focusDuration } }
    }

    private var currentStreak: Int {
        let cal = Calendar.current; let goal = stopwatch.dailyGoal * 60
        var streak = 0; var day = cal.startOfDay(for: Date())
        while (dailyFocusMap[day] ?? 0) >= goal {
            streak += 1
            day = cal.date(byAdding: .day, value: -1, to: day)!
        }
        return streak
    }

    private var longestStreak: Int {
        let cal = Calendar.current; let goal = stopwatch.dailyGoal * 60
        let dates = dailyFocusMap.filter { $0.value >= goal }.keys.sorted(by: >)
        guard !dates.isEmpty else { return 0 }
        var longest = 0, cur = 0, last: Date?
        for d in dates {
            if let l = last, (cal.dateComponents([.day], from: d, to: l).day ?? 0) == 1 { cur += 1 }
            else { longest = max(longest, cur); cur = 1 }
            last = d
        }
        return max(longest, cur)
    }

    var body: some View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 32) {

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Hopefully this will motivate you")
                            .font(.system(size: 11, weight: .bold, design: .default))
                            .foregroundColor(.secondary)
                        Text("Streaks")
                            .font(.system(size: 48, weight: .bold, design: .default))
                    }
                    .padding(.horizontal, 24)

                    HStack(spacing: 12) {
                        streakCard(value: currentStreak, label: "Current", color: .orange)
                        streakCard(value: longestStreak, label: "Best", color: .yellow)
                    }
                    .padding(.horizontal, 24)

                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            MenuLabel(text: "Activity Log")
                            Spacer()
                            HStack(spacing: 4) {
                                ForEach(CalendarMode.allCases) { mode in
                                    Button(action: { calendarMode = mode }) {
                                        Text(mode.rawValue)
                                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                                            .padding(.horizontal, 12).padding(.vertical, 6)
                                            .background(Capsule().fill(calendarMode == mode ? Color.green : Color.primary.opacity(0.04)))
                                            .foregroundColor(calendarMode == mode ? .black : .secondary)
                                    }
                                    .animation(.easeInOut(duration: 0.15), value: calendarMode)
                                }
                            }
                        }
                        GoalCalendar(focusMap: dailyFocusMap, goal: stopwatch.dailyGoal, mode: calendarMode)
                            .padding(20)
                            .glassCard()
                    }
                    .padding(.horizontal, 24)

                    VStack(alignment: .leading, spacing: 10) {
                        MenuLabel(text: "Daily Goal").padding(.horizontal, 24)
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(Int(stopwatch.dailyGoal))")
                                    .font(.system(size: 44, weight: .bold)).foregroundColor(.blue)
                                Text("how many minutes would you like to be focusing daily?")
                                    .font(.system(size: 12, design: .rounded)).foregroundColor(.secondary)
                            }
                            Spacer()
                            HStack(spacing: 10) {
                                stepBtn("−") { stopwatch.dailyGoal = max(10, stopwatch.dailyGoal - 10) }
                                stepBtn("+") { stopwatch.dailyGoal = min(480, stopwatch.dailyGoal + 10) }
                            }
                        }
                        .padding(20)
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
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                }
            }
        }
        .background(.clear)
    }

    private func streakCard(value: Int, label: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(value)").font(.system(size: 48, weight: .bold)).foregroundColor(color)
            Text(label)
                .font(.system(size: 10, weight: .bold, design: .default))
                .foregroundColor(color.opacity(0.7))
            Text("days").font(.system(size: 12, weight: .medium, design: .default)).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .glassCard(tint: color.opacity(0.04))
    }

    private func stepBtn(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label).font(.system(size: 22, weight: .medium))
                .frame(width: 44, height: 44)
                .background(Circle().fill(Color.primary.opacity(0.04)))
        }
    }
}
