import SwiftUI
import Combine
import CoreMotion

extension Notification.Name {
    static let deviceDidShake = Notification.Name("deviceDidShake")
}

// MARK: - Enums
enum TimeFrame: String, CaseIterable, Identifiable {
    case week = "1W"
    case year = "1Y"
    case all = "ALL"
    var id: String { self.rawValue }
}

enum CalendarMode: String, CaseIterable, Identifiable {
    case month = "MONTH"
    case year = "YEAR"
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
    case nature = "NATURE"
    case torus = "3D TORUS"
    
    var id: String { self.rawValue }
    
    var isLight: Bool {
        self == .asciiLight || self == .minimalLight || self == .nature
    }
}

class ThemeManager: ObservableObject {
    @Published var currentTheme: ThemeType = .ascii

    func nextTheme() {
        let all = ThemeType.allCases
        if let idx = all.firstIndex(of: currentTheme) {
            currentTheme = all[(idx + 1) % all.count]
        }
    }
}

class StopwatchManager: ObservableObject {
    @Published var themeManager = ThemeManager()
    @Published var sessions: [FocusSession] = []
    @Published var dailyGoal: Double = 60 // Default 60 minutes

    // Focus Timer
    @Published var elapsedTime: TimeInterval = 0
    @Published var isRunning: Bool = false
    
    // Break Timer
    @Published var isBreakActive: Bool = false
    @Published var showBreakSelection: Bool = false
    @Published var breakTime: TimeInterval = 0
    @Published var dialedBreakMinutes: Double = 5
    
    // Visual Effects
    @Published var flash: Double = 0
    
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
    
    private let motionManager = CMMotionManager()
    private let queue = OperationQueue()
    
    private var lastShakeDate = Date.distantPast
    private let shakeThreshold = 1.0 // Very sensitive

    init() {
        loadSessions()
    }
    
    private func saveSessions() {
        if let encoded = try? JSONEncoder().encode(sessions) {
            UserDefaults.standard.set(encoded, forKey: "saved_sessions")
        }
        UserDefaults.standard.set(dailyGoal, forKey: "daily_goal")
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
    }

    private func handleShake() {
        print("DEBUG: handleShake called. elapsedTime: \(elapsedTime), isRunning: \(isRunning), isBreakActive: \(isBreakActive)")
        // Only trigger break selection if we have focus time and are NOT currently focusing
        if elapsedTime > 0 && !isRunning && !isBreakActive {
            let generator = UIImpactFeedbackGenerator(style: .heavy)
            generator.impactOccurred()
            
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
                
                // Trigger shake if magnitude is high and we haven't triggered in the last 1.5 seconds
                if magnitude > self.shakeThreshold && Date().timeIntervalSince(self.lastShakeDate) > 1.5 {
                    print("DEBUG: Sensitive shake detected! Magnitude: \(magnitude)")
                    self.lastShakeDate = Date()
                    self.handleShake()
                }
                
                let isFaceDown = z > 0.8
                
                if isFaceDown {
                    if self.isBreakActive {
                        self.stopBreak()
                    }
                    if !self.isRunning {
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
        
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.prepare()
        generator.impactOccurred()
        
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
        
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()
        generator.impactOccurred()
    }

    func reset() {
        // Save session before resetting if there was focus time
        if elapsedTime > 1 {
            let session = FocusSession(
                startTime: startTime ?? Date().addingTimeInterval(-elapsedTime),
                focusDuration: elapsedTime,
                breakDuration: breakTime,
                theme: themeManager.currentTheme.rawValue
            )
            sessions.append(session)
            saveSessions()
        }
        
        pause()
        stopBreak()
        accumulatedTime = 0
        elapsedTime = 0
        accumulatedBreakTime = 0
        breakTime = 0
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
        isBreakActive = true
        showBreakSelection = false // Hide the slider screen
        breakStartTime = Date()
        flash = 1.0
        
        // Prevent sleep during break
        UIApplication.shared.isIdleTimerDisabled = true
        
        let generator = UIImpactFeedbackGenerator(style: .soft)
        generator.impactOccurred()
        
        breakTimer = Timer.publish(every: 1.0 / 60.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.updateBreakTime()
            }
    }

    func stopBreak() {
        guard isBreakActive else { return }
        isBreakActive = false
        accumulatedBreakTime += Date().timeIntervalSince(breakStartTime ?? Date())
        breakTime = accumulatedBreakTime
        breakTimer?.cancel()
        breakTimer = nil
        breakStartTime = nil
        
        // Allow sleep again (unless focus resumes immediately)
        if !isRunning {
            UIApplication.shared.isIdleTimerDisabled = false
        }
    }

    private func updateBreakTime() {
        if let breakStartTime = breakStartTime {
            breakTime = accumulatedBreakTime + Date().timeIntervalSince(breakStartTime)
        }
        if flash > 0 { flash = max(0, flash - 0.04) }
    }
}
