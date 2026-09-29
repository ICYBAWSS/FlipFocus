import SwiftUI
import UniformTypeIdentifiers

struct SettingsMenuView: View {
    @ObservedObject var stopwatch: StopwatchManager
    @Environment(\.dismiss) var dismiss
    @State private var showingResetStatsAlert = false
    @State private var showingResetStreakAlert = false
    @State private var showingFilePicker = false

    private var sensitivityLabel: String {
        switch stopwatch.shakeSensitivity {
        case 0.5..<1.0: return "Sensitive"
        case 1.0..<1.5: return "Balanced"
        case 1.5..<2.0: return "Firm"
        case 2.0..<2.8: return "Hard"
        case 2.8...3.5: return "Woah, that's a lot"
        default: return "Balanced"
        }
    }

    var body: some View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 32) {
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Some stuff u might want to tweak")
                            .font(helvetica(11, .bold))
                            .foregroundColor(.secondary)
                        Text("Settings")
                            .font(helvetica(48, .bold))
                    }
                    .padding(.horizontal, 24)

                    // General Settings
                    VStack(alignment: .leading, spacing: 10) {
                        MenuLabel(text: "General").padding(.horizontal, 24)
                        VStack(spacing: 0) {
                            settingsToggle(label: "Battery Save Mode",
                                           description: "Dims screen when face down",
                                           isOn: $stopwatch.isBatterySaveModeEnabled)
                                .onChange(of: stopwatch.isBatterySaveModeEnabled) { _, _ in
                                    stopwatch.save()
                                }
                            settingsToggle(label: "Haptic Feedback",
                                           description: "Might annoy some people",
                                           isOn: $stopwatch.isHapticsEnabled)
                                .onChange(of: stopwatch.isHapticsEnabled) { _, _ in
                                    stopwatch.save()
                                }
                            
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Shake Sensitivity")
                                            .font(helvetica(15, .semibold))
                                        Text("How hard you need to shake for a break. More might be more fun?")
                                            .font(helvetica(11))
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    Text(sensitivityLabel)
                                        .font(helvetica(11, .bold))
                                        .foregroundColor(.blue)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Capsule().fill(Color.blue.opacity(0.1)))
                                }
                                
                                Slider(value: $stopwatch.shakeSensitivity, in: 0.5...3.5, step: 0.1)
                                    .tint(.blue)
                                    .onChange(of: stopwatch.shakeSensitivity) { _, _ in
                                        stopwatch.save()
                                    }
                                
                                HStack {
                                    Text("Sensitive").font(helvetica(8, .bold)).foregroundColor(.secondary)
                                    Spacer()
                                    Text("Firm").font(helvetica(8, .bold)).foregroundColor(.secondary)
                                }
                            }
                            .padding(.horizontal, 18)
                            .padding(.vertical, 16)
                            .background(Color.primary.opacity(0.015))
                        }
                        .glassCard()
                        .padding(.horizontal, 24)
                    }

                    // Sound Effects
                    VStack(alignment: .leading, spacing: 10) {
                        MenuLabel(text: "Sound").padding(.horizontal, 24)
                        VStack(spacing: 0) {
                            settingsButton(label: "Break End Sound", 
                                           description: stopwatch.customSoundDisplayName ?? "Default Melody", 
                                           color: .blue) {
                                showingFilePicker = true
                            }
                            if stopwatch.customSoundFileName != nil {
                                settingsButton(label: "Reset to Default", 
                                               description: "Use the standard melody", 
                                               color: .secondary) {
                                    stopwatch.resetToDefaultSound()
                                }
                            }
                        }
                        .glassCard()
                        .padding(.horizontal, 24)
                    }

                    // Data Management
                    VStack(alignment: .leading, spacing: 10) {
                        MenuLabel(text: "Data").padding(.horizontal, 24)
                        VStack(spacing: 0) {
                            settingsButton(label: "Reset Statistics", 
                                           description: "Clear all focus session history", 
                                           color: .red) {
                                showingResetStatsAlert = true
                            }
                            settingsButton(label: "Reset Current Streak", 
                                           description: "Start your streak over", 
                                           color: .orange) {
                                showingResetStreakAlert = true
                            }
                        }
                        .glassCard()
                        .padding(.horizontal, 24)
                    }

                    // About
                    VStack(alignment: .center, spacing: 8) {
                        Text("Flip&Focus v1.0")
                            .font(helvetica(12, .medium))
                            .foregroundColor(.secondary)
                        Text("Thank you for using my app! :D")
                            .font(helvetica(11))
                            .foregroundColor(.secondary.opacity(0.6))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 20)

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
            .alert("Reset all statistics?", isPresented: $showingResetStatsAlert) {
                Button("Reset", role: .destructive) { stopwatch.resetStats() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will permanently delete all your focus and break history. This action cannot be undone.")
            }
            .alert("Reset your streak?", isPresented: $showingResetStreakAlert) {
                Button("Reset", role: .destructive) { stopwatch.resetStreak() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will clear your current focus progress and reset your daily streak.")
            }
        }
        .background(.clear)
        .fileImporter(isPresented: $showingFilePicker, allowedContentTypes: [.wav, .mp3, .mpeg4Audio], allowsMultipleSelection: false) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                if url.startAccessingSecurityScopedResource() {
                    stopwatch.saveCustomSound(from: url)
                    url.stopAccessingSecurityScopedResource()
                }
            case .failure(let error):
                print("DEBUG: File selection failed: \(error.localizedDescription)")
            }
        }
    }

    private func settingsToggle(label: String, description: String, isOn: Binding<Bool>) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(helvetica(15, .bold))
                Text(description)
                    .font(helvetica(12, .medium))
                    .foregroundColor(.secondary)
            }
            Spacer()
            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(.blue)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(Color.primary.opacity(0.015))
    }

    private func settingsButton(label: String, description: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(helvetica(15, .bold))
                        .foregroundColor(color)
                    Text(description)
                        .font(helvetica(12, .medium))
                        .foregroundColor(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(helvetica(12, .bold))
                    .foregroundColor(.secondary.opacity(0.4))
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background(Color.primary.opacity(0.015))
        }
    }
}
