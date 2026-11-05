//
//  SourceViewFrameReader.swift
//  FloatingPanel
//
//  Created by Andrew on 19/05/2026.
//

#if os(macOS)
import SwiftUI
import AppKit
import AsyncAlgorithms

/// Bridges a lightweight AppKit view into SwiftUI so we can measure the SwiftUI
/// view's frame in screen coordinates.
///
/// Usage: `FloatingPanelModifier` attaches this view with `.background(...)` to the
/// main content. That keeps the tracker in the same layout/window context as the
/// source view, so it passively receives geometry changes as the content moves/resizes.
///
/// The location changes are sent into an `AsyncChannel` that is passed from the FloatingPanelModifier,
/// whereupon the changes are also debounced.
///
/// Why AppKit: SwiftUI does not expose this exact frame-tracking behavior directly
/// on macOS, so we use `NSViewRepresentable` to observe AppKit layout/window events.
internal struct SourceViewFrameReader: NSViewRepresentable {
    let frameChannel: AsyncChannel<CGRect?>

    /// Creates the underlying AppKit view once for this representable.
    /// SwiftUI manages this lifecycle and keeps the instance alive across updates.
    func makeNSView(context: Context) -> SourceTrackingView {
        let sourceTrackingView = SourceTrackingView(frame: .zero)
        sourceTrackingView.frameChannel = frameChannel
        return sourceTrackingView
    }

    /// Called whenever SwiftUI updates this representable.
    ///
    /// We keep the callback in sync and request an immediate frame report so
    /// SwiftUI state stays current even if no AppKit notification fired recently.
    func updateNSView(_ sourceTrackingView: SourceTrackingView, context: Context) {
        sourceTrackingView.frameChannel = frameChannel
        // Collect where the sourceTrackingView is on the screen.
        sourceTrackingView.reportFrameIfPossible()
    }
}

extension SourceViewFrameReader {
    /// AppKit view responsible for observing geometry/window changes and reporting
    /// its bounds converted to screen coordinates by sending the new cgrect to the supplied AsyncChannel.
    /// This is basically acting like a SwiftUI GeometryReader, but unfortunately the GeometryReader doesn't track movements of the window.
    final class SourceTrackingView: NSView {
        var frameChannel: AsyncChannel<CGRect?>?
        private var observationTasks: [Task<Void, Never>] = []

        /// AppKit initializer for programmatic views.
        ///
        /// `postsFrameChangedNotifications`/`postsBoundsChangedNotifications` opt in
        /// to notifications when this view's geometry changes.
        override init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            postsFrameChangedNotifications = true
            postsBoundsChangedNotifications = true
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        deinit {
            for task in observationTasks { task.cancel() }
        }

        /// Called when AppKit attaches/detaches this view from a window.
        ///
        /// Window movement/resizing/screen changes can affect the final screen frame,
        /// so we observe the relevant notification streams for the current window.
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()

            // Cancel the previous window observers before attaching new ones.
            for task in observationTasks { task.cancel() }
            observationTasks.removeAll()

            // Re-report when this view's frame changes in its parent coordinate space.
            observationTasks.append(Task { [weak self] in
                for await _ in NotificationCenter.default.notifications(
                    named: NSView.frameDidChangeNotification,
                    object: self
                ).compactMap({ _ in () }) {
                    self?.reportFrameIfPossible()
                }
            })

            // Re-report when this view's internal bounds change (e.g. layout/size updates).
            observationTasks.append(Task { [weak self] in
                for await _ in NotificationCenter.default.notifications(
                    named: NSView.boundsDidChangeNotification,
                    object: self
                ).compactMap({ _ in () }) {
                    self?.reportFrameIfPossible()
                }
            })

            if let window {
                observationTasks.append(Task { [weak self] in
                    for await _ in NotificationCenter.default.notifications(
                        named: NSWindow.didMoveNotification,
                        object: window
                    ).compactMap({ _ in () }) {
                        self?.reportFrameIfPossible()
                    }
                })

                observationTasks.append(Task { [weak self] in
                    for await _ in NotificationCenter.default.notifications(
                        named: NSWindow.didResizeNotification,
                        object: window
                    ).compactMap({ _ in () }) {
                        self?.reportFrameIfPossible()
                    }
                })

                observationTasks.append(Task { [weak self] in
                    for await _ in NotificationCenter.default.notifications(
                        named: NSWindow.didChangeScreenNotification,
                        object: window
                    ).compactMap({ _ in () }) {
                        self?.reportFrameIfPossible()
                    }
                })
            }

            reportFrameIfPossible()
        }

        /// Computes this view's frame in global screen coordinates and sends it out.
        ///
        /// Conversion steps:
        /// 1. `bounds` -> window coordinates via `convert(_:to:)`
        /// 2. window coordinates -> screen coordinates via `convertToScreen(_:)`
        func reportFrameIfPossible() {
            guard let channel = frameChannel else { return }
            let frameInScreen: CGRect?
            if let window {
                let frameInWindow = convert(bounds, to: nil)
                frameInScreen = window.convertToScreen(frameInWindow)
            } else {
                frameInScreen = nil
            }
            Task { await channel.send(frameInScreen) }
        }
    }
}
#endif
