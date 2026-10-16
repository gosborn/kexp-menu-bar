import AppKit
import Observation
import SwiftUI

/// Owns the menu bar item and its popover. Done in AppKit rather than SwiftUI's MenuBarExtra
/// because MenuBarExtra re-renders its whole label on every equalizer frame (~10% CPU);
/// here each frame is just a cheap image swap on the status item button.
@MainActor
final class StatusBarController: NSObject {
    private let radio: Radio
    private let statusItem = NSStatusBar.system.statusItem(withLength: MenuBarIcon.width + 8)  // fixed width: no menu bar relayout per frame
    private let popover = NSPopover()

    init(radio: Radio, likes: Likes) {
        self.radio = radio
        super.init()

        let hosting = NSHostingController(rootView: PlayerView(radio: radio, likes: likes))
        hosting.sizingOptions = .preferredContentSize
        popover.contentViewController = hosting
        popover.behavior = .transient

        if let button = statusItem.button {
            button.target = self
            button.action = #selector(togglePopover)
            button.setAccessibilityTitle("KEXP")
        }
        updateIcon()
        observeIcon()
    }

    @objc private func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            // Activate so the popover's keyboard shortcuts (space, L, ⌘Q) work.
            NSApp.activate()
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }

    private func observeIcon() {
        withObservationTracking {
            _ = radio.state
            _ = radio.equalizer.levels
        } onChange: { [weak self] in
            Task { @MainActor in
                self?.updateIcon()
                self?.observeIcon()
            }
        }
    }

    private func updateIcon() {
        statusItem.button?.image = radio.state == .stopped
            ? MenuBarIcon.stopped
            : MenuBarIcon.image(levels: radio.equalizer.levels)
    }
}
