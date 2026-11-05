#if os(iOS)
import SwiftUI
import UIKit
import AsyncAlgorithms

/// UIKit counterpart of the macOS AppKit tracker: reports the source view's
/// frame in window coordinates (the iOS space in which `UIWindow` frames live).
internal struct SourceViewFrameReader: UIViewRepresentable {
    let frameChannel: AsyncChannel<CGRect?>

    func makeUIView(context: Context) -> SourceTrackingView {
        let view = SourceTrackingView(frame: .zero)
        view.frameChannel = frameChannel
        return view
    }

    func updateUIView(_ view: SourceTrackingView, context: Context) {
        view.frameChannel = frameChannel
        view.reportFrameIfPossible()
    }
}

extension SourceViewFrameReader {
    final class SourceTrackingView: UIView {
        var frameChannel: AsyncChannel<CGRect?>?

        override init(frame frameRect: CGRect) {
            super.init(frame: frameRect)
            clipsToBounds = false
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func didMoveToWindow() {
            super.didMoveToWindow()

            reportFrameIfPossible()
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            reportFrameIfPossible()
        }

        /// Frame in window coordinates — the space `UIWindow.frame` shares.
        func reportFrameIfPossible() {
            guard let channel = frameChannel else { return }
            let frameInWindow: CGRect?
            if let window {
                frameInWindow = convert(bounds, to: window)
            } else {
                frameInWindow = nil
            }
            Task { await channel.send(frameInWindow) }
        }
    }
}
#endif
