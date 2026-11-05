#if os(iOS)
import SwiftUI
import UIKit

/// Create an iPadOS floating window.
/// UIKit equivalent of the macOS `NSPanel`: a separate `UIWindow` that can be
/// dragged anywhere within its `UIWindowScene` — including outside the bounds
/// of the view that presented it.
@MainActor
public final class FloatingPanel<Content: View>: UIWindow {
    let panelID: String
    let defaultSize: CGSize
    let style: FloatingPanelStyle
    let allowMove: Bool
    let allowResize: Bool
    @Binding var sourceViewFrameInWindow: CGRect?
    @Binding var presentationAnchorInWindow: CGPoint?
    var lastPresentationAnchor: CGPoint?
    var isAnimatingPresentation = false
    var isAnimatingClose = false
    var onPanelClose: (() -> Void)?

    private var hostingController: UIHostingController<AnyView>?
    private var dragStartCenter: CGPoint?
    private var dragStartWindowLocation: CGPoint?
    private var resizeStartFrame: CGRect?
    private var resizeStartWindowLocation: CGPoint?
    nonisolated(unsafe) private var resignObserver: NSObjectProtocol?

    private let minSize = CGSize(width: 220, height: 140)

    public init(
        windowScene: UIWindowScene,
        id: String,
        defaultSize: CGSize = CGSize(width: 360, height: 320),
        style: FloatingPanelStyle = .default,
        allowMove: Bool = true,
        allowResize: Bool = true,
        sourceViewFrameInWindow: Binding<CGRect?> = .constant(nil),
        presentationAnchorInWindow: Binding<CGPoint?> = .constant(nil),
        onClose: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.panelID = id
        self.defaultSize = defaultSize
        self.style = style
        self.allowMove = allowMove
        self.allowResize = allowResize
        self._sourceViewFrameInWindow = sourceViewFrameInWindow
        self._presentationAnchorInWindow = presentationAnchorInWindow
        self.onPanelClose = onClose

        super.init(windowScene: windowScene)

        windowLevel = .normal + 1
        backgroundColor = .clear

        let hostingController: UIHostingController<AnyView> = UIHostingController(rootView: AnyView(content().ignoresSafeArea(SafeAreaRegions.all)))
        hostingController.view.backgroundColor = .clear
        rootViewController = hostingController
        self.hostingController = hostingController

        let restored = Self.restoredFrame(id)
        frame = restored ?? CGRect(origin: .zero, size: defaultSize)

        // Mirror macOS `windowDidResignKey` — dismiss if we lose key status.
        resignObserver = NotificationCenter.default.addObserver(
            forName: UIWindow.didResignKeyNotification,
            object: self,
            queue: .main
        ) { [weak self] _ in
            self?.dismiss()
        }

        setupHandles()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        if let resignObserver {
            NotificationCenter.default.removeObserver(resignObserver)
        }
    }

    public var isPresented: Bool { !isHidden }

    public func updateOnClose(_ onClose: (() -> Void)?) {
        onPanelClose = onClose
    }

    var resolvedSourceAnchorInWindow: CGPoint? {
        guard let frame = sourceViewFrameInWindow, let anchor = presentationAnchorInWindow else {
            // Fall back to the center of the source view when there is no pointer location.
            if let frame = sourceViewFrameInWindow {
                return CGPoint(x: frame.midX, y: frame.midY)
            }
            return nil
        }
        return CGPoint(x: frame.minX + anchor.x, y: frame.minY + anchor.y)
    }

    // MARK: - Presentation

    public func present() {
        let anchor = resolvedSourceAnchorInWindow ?? CGPoint(x: 80, y: 80)
        lastPresentationAnchor = anchor

        let targetFrame = resolvedFrame(anchor: anchor)
        frame = targetFrame
        isHidden = false
        makeKeyAndVisible()

        animatePresentation(from: anchor, to: targetFrame)
    }

    public func dismiss() {
        animateClose()
    }

    private func resolvedFrame(anchor: CGPoint) -> CGRect {
        if let restored = Self.restoredFrame(panelID) {
            return clampToVisible(restored, anchor: anchor)
        }

        let proposedOrigin = CGPoint(
            x: anchor.x - (defaultSize.width / 2),
            y: anchor.y + 12
        )

        return clampToVisible(CGRect(origin: proposedOrigin, size: defaultSize), anchor: anchor)
    }

    private var visibleBounds: CGRect {
        if let scene = windowScene {
            let bounds = scene.coordinateSpace.bounds
            if bounds.width > 0 && bounds.height > 0 {
                return bounds
            }
        }
        return UIScreen.main.bounds
    }

    private func clampToVisible(_ frame: CGRect, anchor: CGPoint) -> CGRect {
        let bounds = visibleBounds
        guard bounds.width > 0, bounds.height > 0 else { return frame }

        let clampedSize = CGSize(
            width: min(frame.width, bounds.width),
            height: min(frame.height, bounds.height)
        )
        var clampedOrigin = frame.origin
        clampedOrigin.x = min(max(clampedOrigin.x, bounds.minX), bounds.maxX - clampedSize.width)
        clampedOrigin.y = min(max(clampedOrigin.y, bounds.minY), bounds.maxY - clampedSize.height)

        return CGRect(origin: clampedOrigin, size: clampedSize)
    }

    private func animatePresentation(from anchor: CGPoint, to finalFrame: CGRect) {
        isAnimatingPresentation = true
        let startFrame = CGRect(x: anchor.x, y: anchor.y, width: 1, height: 1)
        alpha = 0
        frame = startFrame
        isHidden = false

        guard style.animatesOnOpen, style.animationDuration > 0 else {
            alpha = 1
            frame = finalFrame
            isAnimatingPresentation = false
            return
        }

        let animator = UIViewPropertyAnimator(duration: style.animationDuration, curve: .easeInOut) { [weak self] in
            guard let self else { return }
            self.alpha = 1
            self.frame = finalFrame
        }
        animator.addCompletion { [weak self] _ in
            self?.isAnimatingPresentation = false
        }
        animator.startAnimation()
    }

    private func animateClose() {
        guard !isHidden, !isAnimatingClose else { return }
        isAnimatingClose = true

        let anchor = resolvedSourceAnchorInWindow ?? lastPresentationAnchor ?? CGPoint(x: 80, y: 80)
        let endFrame = CGRect(x: anchor.x, y: anchor.y, width: 1, height: 1)

        guard style.animatesOnClose, style.animationDuration > 0 else {
            alpha = 0
            frame = endFrame
            isHidden = true
            alpha = 1
            isAnimatingClose = false
            onPanelClose?()
            return
        }

        let animator = UIViewPropertyAnimator(duration: style.animationDuration, curve: .easeIn) { [weak self] in
            guard let self else { return }
            self.alpha = 0.18
            self.frame = endFrame
        }
        animator.addCompletion { [weak self] _ in
            guard let self else { return }
            self.alpha = 0
            self.isHidden = true
            self.alpha = 1
            self.isAnimatingClose = false
            self.onPanelClose?()
        }
        animator.startAnimation()
    }

    /// Stop the animation triggering storage of intermediate frame sizes
    func persistFrameIfAppropriate() {
        guard !isHidden, !isAnimatingPresentation, !isAnimatingClose else { return }
        guard frame.width >= minSize.width, frame.height >= minSize.height else { return }
        guard frame.origin.x.isFinite, frame.origin.y.isFinite, frame.width.isFinite, frame.height.isFinite else { return }
        Self.saveFrame(frame, panelID: panelID)
    }

    // MARK: - Frame persistence (UIKit counterpart of `setFrameUsingName`)

    private static func restoredFrame(_ panelID: String) -> CGRect? {
        guard let string = UserDefaults.standard.string(forKey: "FloatingPanel.\(panelID).frame") else {
            return nil
        }
        return NSCoder.cgRect(for: string)
    }

    private static func saveFrame(_ frame: CGRect, panelID: String) {
        UserDefaults.standard.set(NSCoder.string(for: frame), forKey: "FloatingPanel.\(panelID).frame")
    }

    // MARK: - Drag / resize handles
    //
    // On macOS this whole section is one line: `isMovableByWindowBackground`.
    // UIKit has no system equivalent — `UIWindow` never moves by its content —
    // so the behavior is hand-built from a pan recognizer that shifts `center`
    // by the touch delta (`handlePan(_:)`) and persists the frame when done.
    //
    // The current setup exposes only a 36pt top strip, so the panel's interactive
    // content keeps its own touches and dragging begins from the strip. To match
    // macOS' "drag from anywhere except controls" semantics instead:
    //
    // 1. Attach `handlePan` to `hostingController.view` (the full window surface)
    //    rather than the strip, and drop both handle constraints.
    // 2. Require the drag to start on background: in the recognizer's `.began`,
    //    hit-test at the start point and only engage the move if the topmost
    //    view doesn't consume touches (controls keep their own drags).
    // 3. Coordinate gestures: make the move pan `require(toFail:)` scroll-view
    //    pans inside the panel, and engage only after a small touch slop so
    //    buttons don't jitter the window.
    //
    // `handlePan` itself needs no changes — it already does the delta math and
    // frame persistence that a full-surface recognizer requires.

    private func setupHandles() {
        guard let hostingController else { return }

        if allowMove {
            let handle = UIView()
            handle.backgroundColor = .clear
            handle.translatesAutoresizingMaskIntoConstraints = false
            hostingController.view.addSubview(handle)
            NSLayoutConstraint.activate([
                handle.topAnchor.constraint(equalTo: hostingController.view.topAnchor),
                handle.leadingAnchor.constraint(equalTo: hostingController.view.leadingAnchor),
                handle.trailingAnchor.constraint(equalTo: hostingController.view.trailingAnchor, constant: -44),
                handle.heightAnchor.constraint(equalToConstant: 36)
            ])
            let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
            handle.addGestureRecognizer(pan)
        }

        if allowResize {
            let handle = UIView()
            handle.backgroundColor = .clear
            handle.translatesAutoresizingMaskIntoConstraints = false
            hostingController.view.addSubview(handle)
            NSLayoutConstraint.activate([
                handle.trailingAnchor.constraint(equalTo: hostingController.view.trailingAnchor),
                handle.bottomAnchor.constraint(equalTo: hostingController.view.bottomAnchor),
                handle.widthAnchor.constraint(equalToConstant: 32),
                handle.heightAnchor.constraint(equalToConstant: 32)
            ])
            let pan = UIPanGestureRecognizer(target: self, action: #selector(handleResizePan(_:)))
            handle.addGestureRecognizer(pan)
        }
    }

    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        guard !isAnimatingPresentation, !isAnimatingClose else { return }

        let windowLocation = gesture.location(in: nil)
        if gesture.state == .began {
            dragStartCenter = center
            dragStartWindowLocation = windowLocation
        } else if gesture.state == .changed {
            guard let startCenter = dragStartCenter,
                  let startLocation = dragStartWindowLocation else { return }
            let delta = CGPoint(x: windowLocation.x - startLocation.x, y: windowLocation.y - startLocation.y)
            center = CGPoint(x: startCenter.x + delta.x, y: startCenter.y + delta.y)
        } else if gesture.state == .ended || gesture.state == .cancelled {
            dragStartCenter = nil
            dragStartWindowLocation = nil
            persistFrameIfAppropriate()
        }
    }

    @objc private func handleResizePan(_ gesture: UIPanGestureRecognizer) {
        guard !isAnimatingPresentation, !isAnimatingClose else { return }

        let windowLocation = gesture.location(in: nil)
        if gesture.state == .began {
            resizeStartFrame = frame
            resizeStartWindowLocation = windowLocation
        } else if gesture.state == .changed {
            guard let startFrame = resizeStartFrame,
                  let startLocation = resizeStartWindowLocation else { return }
            let delta = CGPoint(x: windowLocation.x - startLocation.x, y: windowLocation.y - startLocation.y)
            let newWidth = max(minSize.width, startFrame.width + delta.x)
            let newHeight = max(minSize.height, startFrame.height + delta.y)
            frame = CGRect(x: startFrame.origin.x, y: startFrame.origin.y, width: newWidth, height: newHeight)
        } else if gesture.state == .ended || gesture.state == .cancelled {
            resizeStartFrame = nil
            resizeStartWindowLocation = nil
            persistFrameIfAppropriate()
        }
    }
}
#endif
