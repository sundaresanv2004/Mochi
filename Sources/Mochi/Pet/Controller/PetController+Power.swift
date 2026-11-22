#if canImport(AppKit)
import AppKit
#else
import AppKitLite
#endif

/// Power: frame timer, adaptive frame rate, pausing while the Mac sleeps.
extension PetController {
    /// Stop animating entirely (Mac asleep, display off, screen locked). Nothing runs until `resume`.
    func pause(_ reason: String) {
        pauseReasons.insert(reason)
        timer?.invalidate()
        timer = nil
        fps = 0
        if isMain { mind.save(); log.publish() }
    }

    func resume(_ reason: String) {
        pauseReasons.remove(reason)
        guard pauseReasons.isEmpty, timer == nil else { return }
        lastFrame = Date()
        lastSlow = Date()                          // time spent asleep doesn't count as time awake
        keyCount = SystemInfo.keyPressCount()
        lastCPU = SystemInfo.cpuTicks()
        schedule(30)
        window.orderFrontRegardless()
    }

    func schedule(_ rate: Int) {
        timer?.invalidate()
        fps = rate
        let t = Timer(timeInterval: 1.0 / Double(rate), repeats: true) { [weak self] _ in self?.frame() }
        t.tolerance = 0.2 / Double(rate)           // lets macOS line the wake-ups up with other work
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    /// Full speed only when something is moving; a napping pet barely costs anything.
    var wantedFPS: Int {
        if held || jump != nil || surface == .air || treat != nil || ball != nil || bubble.visible { return 30 }
        if action == .sleep { return 6 }
        if ProcessInfo.processInfo.isLowPowerModeEnabled { return 15 }
        switch action {
        case .idle, .lookAround, .mope, .leap, .climbEdge:
            // Just standing there: breathing and blinking look fine at half speed.
            return view.musicBpm > 0 || view.tap > 0 || view.impact > 0 || view.facing != facing || slipTimer > 0
                || abs(hideShift) > 0.5 ? 30 : 15
        case .hide where hidePhase == .hidden:
            return 15
        default:
            return 30
        }
    }

    func frame() {
        let now = Date()
        let dt = CGFloat(min(0.2, max(0.001, now.timeIntervalSince(lastFrame))))
        lastFrame = now
        tick(dt)
        let want = wantedFPS
        if want != fps, timer != nil { schedule(want) }
    }
}
