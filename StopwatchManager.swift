import SwiftUI
import Combine
import CoreMotion
import AVFoundation
import UserNotifications

extension Notification.Name {
    static let deviceDidShake = Notification.Name("deviceDidShake")
}

// MARK: - Enums
enum TimeFrame: String, CaseIterable, Identifiable {
    case week = "1W"
    case month = "1M"
    case year = "1Y"
    case all = "All"
    var id: String { self.rawValue }
}

enum CalendarMode: String, CaseIterable, Identifiable {
    case month = "Month"
    case year = "Year"
    var id: String { self.rawValue }
}

// MARK: - Models
struct FocusSession: Codable, Identifiable {
    var id = UUID()
    let startTime: Date
    let focusDuration: TimeInterval
    let breakDuration: TimeInterval
    let theme: String
}

// MARK: - Themes
enum ThemeType: String, CaseIterable, Identifiable {
    case ascii = "ASCII DARK"
    case asciiLight = "ASCII LIGHT"
    case minimal = "MINIMAL DARK"
    case minimalLight = "MINIMAL LIGHT"
    
    var id: String { self.rawValue }
    
    var isLight: Bool {
        switch self {
        case .asciiLight, .minimalLight: return true
        default: return false
        }
    }
}

struct CustomTheme: Codable, Identifiable {
    var id = UUID()
    var name: String
    var settings: CustomThemeSettings
}

struct CustomThemeSettings: Codable {
    var backgroundImageFileName: String?
    var ringColorSeconds: [Double] = [0.0, 0.6, 1.0] // RGB
    var ringColorMinutes: [Double] = [0.2, 0.8, 0.3]
    var ringColorHours: [Double] = [1.0, 0.2, 0.3]
    var mainAccentColor: [Double] = [1.0, 1.0, 1.0]
    var isLightMode: Bool = false
    
    func color(for components: [Double]) -> Color {
        Color(red: components[0], green: components[1], blue: components[2])
    }
}

class ThemeManager: ObservableObject {
    @Published var currentTheme: ThemeType? = .ascii
    @Published var selectedCustomThemeID: UUID? = nil
    @Published var customThemes: [CustomTheme] = []
    
    private var isInitialLoading = false

    init() {
        load()
    }

    var activeSettings: CustomThemeSettings? {
        if let id = selectedCustomThemeID {
            return customThemes.first(where: { $0.id == id })?.settings
        }
        return nil
    }

    func save() {
        if isInitialLoading { return }
        UserDefaults.standard.set(currentTheme?.rawValue, forKey: "current_theme")
        UserDefaults.standard.set(selectedCustomThemeID?.uuidString, forKey: "selected_custom_theme_id")
        
        if let data = try? JSONEncoder().encode(customThemes) {
            UserDefaults.standard.set(data, forKey: "custom_themes_list")
        }
    }

    func saveCustomImage(data: Data, for themeID: UUID) {
        guard let image = UIImage(data: data),
              let jpegData = image.jpegData(compressionQuality: 0.9) else {
            return
        }

        let fileManager = FileManager.default
        let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let name = "custom_theme_\(themeID.uuidString).jpg"
        let url = docs.appendingPathComponent(name)
        
        do {
            try jpegData.write(to: url, options: [.atomic])
            if let index = customThemes.firstIndex(where: { $0.id == themeID }) {
                customThemes[index].settings.backgroundImageFileName = name
                save()
            }
        } catch {
            print("DEBUG: Error saving custom image: \(error.localizedDescription)")
        }
    }

    func deleteCustomImage(for themeID: UUID) {
        if let index = customThemes.firstIndex(where: { $0.id == themeID }),
           let name = customThemes[index].settings.backgroundImageFileName {
            let fileManager = FileManager.default
            let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let url = docs.appendingPathComponent(name)
            try? fileManager.removeItem(at: url)
            
            customThemes[index].settings.backgroundImageFileName = nil
            save()
        }
    }

    private func load() {
        isInitialLoading = true
        
        if let raw = UserDefaults.standard.string(forKey: "current_theme"), let t = ThemeType(rawValue: raw) {
            currentTheme = t
        } else if UserDefaults.standard.string(forKey: "current_theme") == nil {
            currentTheme = .ascii
        } else {
            currentTheme = nil
        }
        
        if let idString = UserDefaults.standard.string(forKey: "selected_custom_theme_id"),
           let id = UUID(uuidString: idString) {
            selectedCustomThemeID = id
        }

        if let data = UserDefaults.standard.data(forKey: "custom_themes_list"), 
           let themes = try? JSONDecoder().decode([CustomTheme].self, from: data) {
            customThemes = themes
        }
        
        isInitialLoading = false
    }

    func selectTheme(_ theme: ThemeType) {
        currentTheme = theme
        selectedCustomThemeID = nil
        save()
    }

    func selectCustomTheme(_ theme: CustomTheme) {
        currentTheme = nil
        selectedCustomThemeID = theme.id
        save()
    }

    func addNewCustomTheme() -> CustomTheme {
        let newTheme = CustomTheme(name: "New Theme \(customThemes.count + 1)", settings: CustomThemeSettings())
        customThemes.append(newTheme)
        selectCustomTheme(newTheme)
        save()
        return newTheme
    }

    func deleteCustomTheme(_ theme: CustomTheme) {
        if let name = theme.settings.backgroundImageFileName {
            let fileManager = FileManager.default
            let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let url = docs.appendingPathComponent(name)
            try? fileManager.removeItem(at: url)
        }
        
        customThemes.removeAll(where: { $0.id == theme.id })
        if selectedCustomThemeID == theme.id {
            selectTheme(.ascii)
        }
        save()
    }

    func nextTheme() {
        // Built-in theme cycling
        if let current = currentTheme {
            let all = ThemeType.allCases
            if let idx = all.firstIndex(of: current) {
                let nextIdx = (idx + 1) % all.count
                selectTheme(all[nextIdx])
            }
        } else {
            selectTheme(.ascii)
        }
    }
}

class StopwatchManager: ObservableObject {
    @Published var themeManager = ThemeManager()
    @Published var sessions: [FocusSession] = []
    @Published var dailyGoal: Double = 60 // Default 60 minutes
    
    // Settings
    @Published var isBatterySaveModeEnabled: Bool = false
    @Published var isHapticsEnabled: Bool = true
    @Published var customSoundFileName: String? = nil
    @Published var customSoundDisplayName: String? = nil
    @Published var shakeSensitivity: Double = 1.0 // 1.0 is default

    // Internal Shake Tracking
    private var shakeActiveStartTime: Date? = nil

    // Focus Timer
    @Published var elapsedTime: TimeInterval = 0
    @Published var isRunning: Bool = false
    
    // Break Timer
    @Published var isBreakActive: Bool = false
    @Published var showBreakSelection: Bool = false
    @Published var breakTime: TimeInterval = 0
    @Published var dialedBreakMinutes: Double = 5
    @Published var breakDidComplete: Bool = false
    
    // Visual Effects
    @Published var flash: Double = 0
    
    private var audioPlayer: AVAudioPlayer?
    
    // Earned Range
    var minEarnedMinutes: Double {
        calculateBreakLogic().minEarned
    }
    
    var maxEarnedMinutes: Double {
        calculateBreakLogic().maxEarned
    }
    
    private func calculateBreakLogic() -> (minEarned: Double, maxEarned: Double) {
        let focusMinutes = max(1, elapsedTime / 60)
        
        // Dynamic range: 10% to 25% of focus time
        let minBreak = focusMinutes * 0.10
        let maxBreak = focusMinutes * 0.25
        
        // Ensure at least 1 min if focused at all, and cap max reasonably
        return (max(1, minBreak), max(2, maxBreak))
    }
    
    // Debug/Sensor
    @Published var gravityZ: Double = 0.0
    
    private var timer: AnyCancellable?
    private var breakTimer: AnyCancellable?
    
    private var startTime: Date?
    private var breakStartTime: Date?
    private var accumulatedTime: TimeInterval = 0
    private var accumulatedBreakTime: TimeInterval = 0
    
    // Pending session storage
    private var pendingFocusStartTime: Date?
    private var pendingFocusDuration: TimeInterval?
    
    private let motionManager = CMMotionManager()
    private let queue = OperationQueue()
    
    private var lastShakeDate = Date.distantPast
    private var themeManagerCancellable: AnyCancellable?

    init() {
        loadSessions()
        requestNotificationPermissions()
        // ThemeManager is a nested ObservableObject — its own @Published changes don't
        // propagate to views observing only `self`, so forward them manually.
        themeManagerCancellable = themeManager.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
    }
    
    func save() {
        if let encoded = try? JSONEncoder().encode(sessions) {
            UserDefaults.standard.set(encoded, forKey: "saved_sessions")
        }
        UserDefaults.standard.set(dailyGoal, forKey: "daily_goal")
        UserDefaults.standard.set(isBatterySaveModeEnabled, forKey: "battery_save_mode")
        UserDefaults.standard.set(isHapticsEnabled, forKey: "haptics_enabled")
        UserDefaults.standard.set(customSoundFileName, forKey: "custom_sound_filename")
        UserDefaults.standard.set(customSoundDisplayName, forKey: "custom_sound_displayname")
        UserDefaults.standard.set(shakeSensitivity, forKey: "shake_sensitivity")
    }
    
    private func loadSessions() {
        if let data = UserDefaults.standard.data(forKey: "saved_sessions"),
           let decoded = try? JSONDecoder().decode([FocusSession].self, from: data) {
            self.sessions = decoded
        }
        let savedGoal = UserDefaults.standard.double(forKey: "daily_goal")
        if savedGoal > 0 {
            self.dailyGoal = savedGoal
        }
        self.isBatterySaveModeEnabled = UserDefaults.standard.bool(forKey: "battery_save_mode")
        self.customSoundFileName = UserDefaults.standard.string(forKey: "custom_sound_filename")
        self.customSoundDisplayName = UserDefaults.standard.string(forKey: "custom_sound_displayname")
        
        let savedSensitivity = UserDefaults.standard.double(forKey: "shake_sensitivity")
        self.shakeSensitivity = savedSensitivity > 0 ? savedSensitivity : 1.0

        // Default haptics to true if not set
        if UserDefaults.standard.object(forKey: "haptics_enabled") == nil {
            self.isHapticsEnabled = true
        } else {
            self.isHapticsEnabled = UserDefaults.standard.bool(forKey: "haptics_enabled")
        }
    }

    func saveCustomSound(from url: URL) {
        let fileManager = FileManager.default
        let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileName = "CustomBreakEnd.\(url.pathExtension)"
        let destinationURL = documentsDirectory.appendingPathComponent(fileName)
        
        // Remove old sound if exists
        if let oldName = customSoundFileName {
            let oldURL = documentsDirectory.appendingPathComponent(oldName)
            try? fileManager.removeItem(at: oldURL)
        }
        
        do {
            if fileManager.fileExists(atPath: destinationURL.path) {
                try fileManager.removeItem(at: destinationURL)
            }
            try fileManager.copyItem(at: url, to: destinationURL)
            self.customSoundFileName = fileName
            self.customSoundDisplayName = url.lastPathComponent
            save()
        } catch {
            print("DEBUG: Could not save custom sound: \(error.localizedDescription)")
        }
    }

    func resetToDefaultSound() {
        if let fileName = customSoundFileName {
            let fileManager = FileManager.default
            let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let url = documentsDirectory.appendingPathComponent(fileName)
            try? fileManager.removeItem(at: url)
        }
        customSoundFileName = nil
        customSoundDisplayName = nil
        save()
    }

    func resetStats() {
        sessions = []
        save()
    }

    #if targetEnvironment(simulator)
    // Screenshot-only helpers, never compiled on device.
    func debugLoadDemoData() {
        let cal = Calendar.current
        var demo: [FocusSession] = []
        for dayOffset in 0...16 {
            if dayOffset == 5 || dayOffset == 11 { continue } // gaps so the streak/calendar look real
            let day = cal.date(byAdding: .day, value: -dayOffset, to: Date())!
            let start = cal.date(bySettingHour: 9, minute: 0, second: 0, of: day) ?? day
            let focusMin = Double.random(in: 65...115)
            let breakMin = focusMin * Double.random(in: 0.08...0.2)
            demo.append(FocusSession(startTime: start, focusDuration: focusMin * 60, breakDuration: breakMin * 60, theme: themeManager.currentTheme?.rawValue ?? "CUSTOM"))
        }
        sessions = demo
        save()
    }

    func debugFastForward(_ seconds: TimeInterval) {
        accumulatedTime += seconds
        if !isRunning { elapsedTime = accumulatedTime }
    }

    /// Pins the clock to an exact elapsed time and leaves `isRunning` true (with no
    /// timer attached) so every theme renders identical digits in the "Focus" state.
    /// Used to shoot the same moment across themes for composite screenshots.
    func debugFreeze(at seconds: TimeInterval) {
        pause()
        accumulatedTime = seconds
        elapsedTime = seconds
        startTime = nil
        isRunning = true
    }
    #endif

    func resetStreak() {
        // Streaks are derived from sessions. To reset streaks, we filter out sessions that contribute to streaks, 
        // or for simplicity in this app's logic, we can clear sessions if that's the intent.
        // If the user wants to keep history but reset the current streak, we'd need a different data model.
        // Assuming "Reset Streak" means clear current progress.
        resetStats()
    }

    private func triggerHaptic(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        guard isHapticsEnabled else { return }
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred()
    }

    private func triggerNotificationHaptic(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        guard isHapticsEnabled else { return }
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(type)
    }

    private func requestNotificationPermissions() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if granted {
                print("DEBUG: Notifications granted")
            } else if let error = error {
                print("DEBUG: Notification error: \(error.localizedDescription)")
            }
        }
    }

    private func scheduleBreakEndNotification(after seconds: TimeInterval) {
        cancelPendingNotifications()
        
        let content = UNMutableNotificationContent()
        content.title = "Break Finished"
        content.body = "Time to get back to focus!"
        content.sound = UNNotificationSound.default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(0.1, seconds), repeats: false)
        let request = UNNotificationRequest(identifier: "breakEnd", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("DEBUG: Error scheduling notification: \(error.localizedDescription)")
            }
        }
    }

    private func cancelPendingNotifications() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["breakEnd"])
    }

    private func handleShake() {
        print("DEBUG: handleShake called. elapsedTime: \(elapsedTime), isRunning: \(isRunning), isBreakActive: \(isBreakActive)")
        // Only trigger break selection if we have focus time and are NOT currently focusing
        if elapsedTime > 0 && !isRunning && !isBreakActive {
            triggerHaptic(.heavy)
            
            withAnimation(.spring()) {
                self.showBreakSelection = true
                self.dialedBreakMinutes = round(self.minEarnedMinutes)
            }
        }
    }

    deinit {
        motionManager.stopDeviceMotionUpdates()
        timer?.cancel()
        breakTimer?.cancel()
    }

    func activate() {
        print("DEBUG: Activating sensors...")
        startMotionUpdates()
    }

    private func startMotionUpdates() {
        print("DEBUG: Starting motion updates...")
        guard motionManager.isDeviceMotionAvailable else {
            print("DEBUG: Device motion NOT available")
            return
        }

        motionManager.deviceMotionUpdateInterval = 0.1
        motionManager.startDeviceMotionUpdates(to: queue) { [weak self] (motion, error) in
            if let error = error {
                print("DEBUG: Motion error: \(error.localizedDescription)")
                return
            }
            guard let self = self, let motion = motion else { return }
            
            let z = motion.gravity.z
            
            // Custom Shake Detection
            let userAcc = motion.userAcceleration
            let magnitude = sqrt(pow(userAcc.x, 2) + pow(userAcc.y, 2) + pow(userAcc.z, 2))
            
            DispatchQueue.main.async {
                self.gravityZ = z
                
                // Shake Logic
                let threshold = self.shakeSensitivity
                let requiresSustained = threshold > 2.0
                let requiredDuration: TimeInterval = requiresSustained ? (threshold - 2.0) : 0
                
                if magnitude > threshold {
                    if self.shakeActiveStartTime == nil {
                        self.shakeActiveStartTime = Date()
                    }
                    
                    let currentDuration = Date().timeIntervalSince(self.shakeActiveStartTime!)
                    
                    if currentDuration >= requiredDuration {
                        if Date().timeIntervalSince(self.lastShakeDate) > 1.5 {
                            print("DEBUG: Shake success! Magnitude: \(magnitude), Duration: \(currentDuration)")
                            self.lastShakeDate = Date()
                            self.shakeActiveStartTime = nil
                            self.handleShake()
                        }
                    } else if requiresSustained {
                        // Optional: trigger tiny haptic "tick" during build-up
                        // self.triggerHaptic(.light) 
                    }
                } else {
                    // Reset if shake drops below threshold
                    self.shakeActiveStartTime = nil
                }
                
                let isFaceDown = z > 0.8
                
                if isFaceDown {
                    if self.isBreakActive {
                        self.stopBreak()
                    }
                    // Only start focus if we are not in break selection or already breaking
                    if !self.isRunning && !self.showBreakSelection && !self.isBreakActive {
                        self.start()
                    }
                } else {
                    if self.isRunning {
                        self.pause()
                    }
                }
            }
        }
    }

    // MARK: - Focus Logic
    func start() {
        guard !isRunning else { return }
        isRunning = true
        startTime = Date()
        flash = 1.0
        
        // When focusing resumes, hide break selection if it was open
        showBreakSelection = false
        
        // Prevent sleep during focus
        UIApplication.shared.isIdleTimerDisabled = true
        
        triggerHaptic(.medium)
        
        timer = Timer.publish(every: 1.0 / 60.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.updateElapsedTime()
            }
    }

    func pause() {
        guard isRunning else { return }
        isRunning = false
        accumulatedTime += Date().timeIntervalSince(startTime ?? Date())
        elapsedTime = accumulatedTime
        timer?.cancel()
        timer = nil
        startTime = nil
        
        // Allow sleep again (unless break is active)
        if !isBreakActive {
            UIApplication.shared.isIdleTimerDisabled = false
        }
        
        triggerHaptic(.light)
    }

    func reset() {
        // Save current session if it exists and wasn't already moved to pending
        if elapsedTime > 1 {
            let session = FocusSession(
                startTime: startTime ?? Date().addingTimeInterval(-elapsedTime),
                focusDuration: elapsedTime,
                breakDuration: breakTime,
                theme: themeManager.currentTheme?.rawValue ?? "CUSTOM"
            )
            sessions.append(session)
            save()
        }
        
        pause()
        stopBreak() // stopBreak will handle saving any pending focus + current break duration
        cancelPendingNotifications()
        
        // Clear all state
        accumulatedTime = 0
        elapsedTime = 0
        accumulatedBreakTime = 0
        breakTime = 0
        pendingFocusDuration = nil
        pendingFocusStartTime = nil
        isBreakActive = false
        showBreakSelection = false
        flash = 0
        UIApplication.shared.isIdleTimerDisabled = false
    }

    private func updateElapsedTime() {
        if let startTime = startTime {
            elapsedTime = accumulatedTime + Date().timeIntervalSince(startTime)
        }
        if flash > 0 { flash = max(0, flash - 0.04) }
    }

    // MARK: - Break Logic
    func startBreak() {
        guard !isBreakActive && !isRunning else { return }
        
        // Capture focus session as "pending" and reset the focus stopwatch
        if elapsedTime > 1 {
            pendingFocusDuration = elapsedTime
            pendingFocusStartTime = startTime ?? Date().addingTimeInterval(-elapsedTime)
            
            // Restart focus stopwatch for a "new focus stretch"
            accumulatedTime = 0
            elapsedTime = 0
            startTime = nil
        }
        
        // Reset break progress for the new session
        accumulatedBreakTime = 0
        breakTime = 0
        breakDidComplete = false
        
        isBreakActive = true
        showBreakSelection = false // Hide the slider screen
        breakStartTime = Date()
        flash = 1.0
        
        // Prevent sleep during break
        UIApplication.shared.isIdleTimerDisabled = true
        
        triggerHaptic(.soft)
        
        let breakSeconds = dialedBreakMinutes * 60
        scheduleBreakEndNotification(after: breakSeconds)
        
        breakTimer = Timer.publish(every: 1.0 / 60.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.updateBreakTime()
            }
    }

    func stopBreak() {
        guard isBreakActive else { return }
        isBreakActive = false
        cancelPendingNotifications()
        accumulatedBreakTime += Date().timeIntervalSince(breakStartTime ?? Date())
        breakTime = accumulatedBreakTime
        breakTimer?.cancel()
        breakTimer = nil
        breakStartTime = nil
        
        // Finalize and save the session (Focus + Break)
        if let fDur = pendingFocusDuration, let fStart = pendingFocusStartTime {
            let session = FocusSession(
                startTime: fStart,
                focusDuration: fDur,
                breakDuration: breakTime,
                theme: themeManager.currentTheme?.rawValue ?? "CUSTOM"
            )
            sessions.append(session)
            save()
            
            // Clear pending storage
            pendingFocusDuration = nil
            pendingFocusStartTime = nil
        }
        
        // Allow sleep again (unless focus resumes immediately)
        if !isRunning {
            UIApplication.shared.isIdleTimerDisabled = false
        }
    }

    private func playBreakEndSound() {
        let url: URL?
        
        if let customName = customSoundFileName {
            let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            url = docs.appendingPathComponent(customName)
        } else {
            url = Bundle.main.url(forResource: "BreakEnd", withExtension: "wav")
        }
        
        guard let finalURL = url else {
            print("DEBUG: Sound file not found")
            return
        }
        
        do {
            // Configure AVAudioSession for ambient playback (respects silent switch)
            try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default, options: [])
            try AVAudioSession.sharedInstance().setActive(true)
            
            audioPlayer = try AVAudioPlayer(contentsOf: finalURL)
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()
        } catch {
            print("DEBUG: Could not play sound: \(error.localizedDescription)")
        }
    }

    private func updateBreakTime() {
        if let breakStartTime = breakStartTime {
            let currentBreak = accumulatedBreakTime + Date().timeIntervalSince(breakStartTime)
            let limit = dialedBreakMinutes * 60
            
            if currentBreak >= limit {
                breakTime = limit
                stopBreak()
                breakDidComplete = true
                
                playBreakEndSound()
                
                // Haptic notification for break end
                triggerNotificationHaptic(.success)
            } else {
                breakTime = currentBreak
            }
        }
        if flash > 0 { flash = max(0, flash - 0.04) }
    }
}
