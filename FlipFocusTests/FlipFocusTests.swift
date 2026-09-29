//
//  FlipFocusTests.swift
//  FlipFocusTests
//
//  Created by Rayhan Mohamed on 3/18/26.
//

import Testing
@testable import FlipFocus

struct FlipFocusTests {

    @Test func example() async throws {
        // Write your test here and use APIs like `#expect(...)` to check expected conditions.
    }

    /// The rings must genuinely sweep: 0 at the flip, 1 once done, never backwards.
    @Test func ringRevealSweepsFromZeroToOne() {
        #expect(ringRevealFactor(since: nil, at: 100) == 1.0)          // no flip → no reveal
        #expect(ringRevealFactor(since: 100, at: 99) == 0.0)           // clock skew → still 0
        #expect(ringRevealFactor(since: 100, at: 100) == 0.0)          // starts at 0, not at the value
        #expect(ringRevealFactor(since: 100, at: 100.5) > 0.0)
        #expect(ringRevealFactor(since: 100, at: 100.5) < 1.0)
        #expect(ringRevealFactor(since: 100, at: 101) == 1.0)
        #expect(ringRevealFactor(since: 100, at: 500) == 1.0)          // clamped

        var last = -1.0
        for step in 0...100 {
            let f = ringRevealFactor(since: 100, at: 100 + Double(step) / 100)
            #expect(f >= last, "reveal must be monotonic")
            last = f
        }
    }

    /// The sweep belongs to the pause — the moment the session stops and the user is
    /// looking at the screen. Face-down start happens behind the user's back, so it
    /// must not fire anything.
    @MainActor
    @Test func pausingSweepsTheRingsBackIn() {
        let stopwatch = StopwatchManager()

        stopwatch.start()                  // flip face down: screen covered, nothing to see
        #expect(stopwatch.ringRevealID == 0)

        stopwatch.gravityZ = 0.95          // still face down
        #expect(stopwatch.ringRevealID == 0)

        stopwatch.pause()                  // paused: this is when the sweep has to play
        #expect(stopwatch.ringRevealID == 1)

        stopwatch.pause()                  // already paused, nothing changed, no sweep
        #expect(stopwatch.ringRevealID == 1)

        stopwatch.gravityZ = 0.0           // the flip hook bumps as well — on device this
        #expect(stopwatch.ringRevealID == 2)   // lands in the same frame as pause()
    }

    /// Flipping face-up while a break runs stops the break instead of pausing, and the
    /// user is looking at the screen there too.
    @MainActor
    @Test func flipUpDuringBreakAlsoSweeps() {
        let stopwatch = StopwatchManager()
        stopwatch.gravityZ = 0.95
        stopwatch.startBreak()

        let before = stopwatch.ringRevealID
        stopwatch.gravityZ = 0.0
        #expect(stopwatch.ringRevealID == before + 1)
    }
}
