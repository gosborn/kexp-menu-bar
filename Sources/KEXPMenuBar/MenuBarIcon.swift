import AppKit
import Observation

/// KEXP's four-bar mark, drawn as a template image so it follows the menu bar's light/dark tint.
/// The "KEXP" lettering under the bars is left out; it's illegible at menu bar size.
enum MenuBarIcon {
    /// Bar heights relative to the tallest, left to right, measured from the logo.
    static let logoLevels: [CGFloat] = [0.90, 0.65, 1.0, 0.80]

    static let stopped = image(levels: logoLevels, alpha: 0.45)

    static let height: CGFloat = 16
    private static let barWidth: CGFloat = 3.3
    private static let gap: CGFloat = 1.2
    static let width = ceil(barWidth * CGFloat(logoLevels.count) + gap * CGFloat(logoLevels.count - 1))

    static func image(levels: [CGFloat], alpha: CGFloat = 1) -> NSImage {
        let image = NSImage(size: NSSize(width: width, height: height), flipped: false) { _ in
            NSColor.black.withAlphaComponent(alpha).set()
            for (i, level) in levels.enumerated() {
                NSRect(x: CGFloat(i) * (barWidth + gap), y: 0, width: barWidth, height: height * level).fill()
            }
            return true
        }
        image.isTemplate = true
        return image
    }
}

/// Bounces the bars like an equalizer while running; rests on the logo shape otherwise.
@MainActor
@Observable
final class Equalizer {
    private(set) var levels = MenuBarIcon.logoLevels

    /// Set by Radio: true while audio is actually playing.
    var isPlaying = false {
        didSet { update() }
    }

    /// User preference from the dropdown; persisted.
    var isEnabled = UserDefaults.standard.object(forKey: "animateIcon") as? Bool ?? true {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: "animateIcon")
            update()
        }
    }

    @ObservationIgnored private var targets = MenuBarIcon.logoLevels
    @ObservationIgnored private var timer: Timer?

    private func update() {
        let shouldRun = isPlaying && isEnabled && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        if shouldRun, timer == nil { start() }
        if !shouldRun, timer != nil { stop() }
    }

    private func start() {
        // Each frame costs a menu bar redraw in the system's drawing code, so keep the rate low.
        let timer = Timer(timeInterval: 1.0 / 6, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        // .common keeps it animating while the dropdown is open.
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func stop() {
        timer?.invalidate()
        timer = nil
        levels = MenuBarIcon.logoLevels
        targets = MenuBarIcon.logoLevels
    }

    private func tick() {
        let next = levels.indices.map { i in
            if abs(targets[i] - levels[i]) < 0.06 {
                targets[i] = .random(in: 0.3...1.0)
            }
            return Self.snapToPixel(levels[i] + (targets[i] - levels[i]) * 0.55)
        }
        // Skip frames where no bar moved a whole (Retina) pixel; they'd redraw for nothing.
        if next != levels { levels = next }
    }

    private static func snapToPixel(_ level: CGFloat) -> CGFloat {
        let steps = MenuBarIcon.height * 2
        return (level * steps).rounded() / steps
    }
}
