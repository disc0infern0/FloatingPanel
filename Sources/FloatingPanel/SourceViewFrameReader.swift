//
//  SourceViewFrameReader.swift
//  FloatingPanel
//
//  Created by Andrew on 19/05/2026.
//

import SwiftUI
import AppKit

/// Bridges a lightweight AppKit view into SwiftUI so we can measure the SwiftUI
/// view's frame in screen coordinates.
///
/// Usage: `FloatingPanelModifier` attaches this view with `.background(...)` to the
/// main content. That keeps the tracker in the same layout/window context as the
/// source view, so it passively receives geometry changes as the content moves/resizes.
///
/// The location changes are sent into an Async stream object that is passed from the FloatingPanelModifier,
/// whereupon the changes are also debounced.
///
/// Why AppKit: SwiftUI does not expose this exact frame-tracking behavior directly
/// on macOS, so we use `NSViewRepresentable` to observe AppKit layout/window events.
internal struct SourceViewFrameReader: NSViewRepresentable {
    let frameEmitter: AsyncEmitter<CGRect?>

    /// Creates the underlying AppKit view once for this representable.
    /// SwiftUI manages this lifecycle and keeps the instance alive across updates.
    func makeNSView(context: Context) -> SourceTrackingView {
        let sourceTrackingView = SourceTrackingView(frame: .zero)
        sourceTrackingView.frameEmitter = frameEmitter
        return sourceTrackingView
    }

    /// Called whenever SwiftUI updates this representable.
    ///
    /// We keep the callback in sync and request an immediate frame report so
    /// SwiftUI state stays current even if no AppKit notification fired recently.
    func updateNSView(_ sourceTrackingView: SourceTrackingView, context: Context) {
        sourceTrackingView.frameEmitter = frameEmitter
        // Collect where the sourceTrackingView is on the screen.
        sourceTrackingView.reportFrameIfPossible()
    }
}

extension SourceViewFrameReader {
    /// AppKit view responsible for observing geometry/window changes and reporting
    /// its bounds converted to screen coordinates by sending the new cgrect to the supplied AsyncEmitter
    ///  this is basically acting like a SwiftUI GeometryReader, but unforunately the GeometryReader doesnt track movements of the window.
    final class SourceTrackingView: NSView {
        var frameEmitter: AsyncEmitter<CGRect?>?

        /// AppKit initializer for programmatic views.
        ///
        /// `postsFrameChangedNotifications`/`postsBoundsChangedNotifications` opt in
        /// to notifications when this view's geometry changes.
        override init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            postsFrameChangedNotifications = true
            postsBoundsChangedNotifications = true
            // Re-report when this view's frame changes in its parent coordinate space.
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(reportFrameIfPossible),
                name: NSView.frameDidChangeNotification,
                object: self
            )
            // Re-report when this view's internal bounds change (e.g. layout/size updates).
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(reportFrameIfPossible),
                name: NSView.boundsDidChangeNotification,
                object: self
            )
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        deinit {
            // Important: clean up observers to avoid callbacks to a deallocated object.
            NotificationCenter.default.removeObserver(self)
        }

        /// Called when AppKit attaches/detaches this view from a window.
        ///
        /// Window movement/resizing/screen changes can affect the final screen frame,
        /// so we subscribe to those notifications for the current window.
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()

            // Remove old window observers before attaching new ones.
            NotificationCenter.default.removeObserver(self, name: NSWindow.didMoveNotification, object: nil)
            NotificationCenter.default.removeObserver(self, name: NSWindow.didResizeNotification, object: nil)
            NotificationCenter.default.removeObserver(self, name: NSWindow.didChangeScreenNotification, object: nil)

            if let window {
                // Window moved on screen.
                NotificationCenter.default.addObserver(
                    self,
                    selector: #selector(reportFrameIfPossible),
                    name: NSWindow.didMoveNotification,
                    object: window
                )
                // Window resized.
                NotificationCenter.default.addObserver(
                    self,
                    selector: #selector(reportFrameIfPossible),
                    name: NSWindow.didResizeNotification,
                    object: window
                )
                // Window moved to another display or display setup changed.
                NotificationCenter.default.addObserver(
                    self,
                    selector: #selector(reportFrameIfPossible),
                    name: NSWindow.didChangeScreenNotification,
                    object: window
                )
            }

            reportFrameIfPossible()
        }

        /// Computes this view's frame in global screen coordinates and sends it out.
        ///
        /// Conversion steps:
        /// 1. `bounds` -> window coordinates via `convert(_:to:)`
        /// 2. window coordinates -> screen coordinates via `convertToScreen(_:)`
        ///
        /// It is used as a selector target in NotificationCentre ; #selector(reportFrameIfPossible),
        /// and hence must be marked as visible in Objective-C.
        @objc func reportFrameIfPossible() {
            guard let window else {
                frameEmitter?.send(nil)
                return
            }
            let frameInWindow = convert(bounds, to: nil)
            let frameInScreen = window.convertToScreen(frameInWindow)
            frameEmitter?.send(frameInScreen)
        }
    }
}
