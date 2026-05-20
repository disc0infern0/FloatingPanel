import SwiftUI
import AppKit


@MainActor
public final class FloatingPanel<Content: View>: NSPanel, NSWindowDelegate {
    let panelID: String
    let defaultSize: CGSize
    let animationDuration: TimeInterval
    let allowResize: Bool
    let positionStore: FloatingPanelPositionStore
    @Binding var sourceViewFrameInScreen: CGRect?
    @Binding var presentationAnchorInSourceView: CGPoint?
    var lastPresentationAnchor: CGPoint?
    var isAnimatingPresentation = false
    var isAnimatingClose = false
    var onPanelClose: (() -> Void)?

    public init(
        id: String,
        defaultSize: CGSize = CGSize(width: 360, height: 320),
        animationDuration: TimeInterval = 0.18,
        allowResize: Bool = true,
        sourceViewFrameInScreen: Binding<CGRect?> = .constant(nil),
        presentationAnchorInSourceView: Binding<CGPoint?> = .constant(nil),
        onClose: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.panelID = id
        self.defaultSize = defaultSize
        self.animationDuration = animationDuration
        self.allowResize = allowResize
        self.positionStore = FloatingPanelPositionStore(id: id)
        self._sourceViewFrameInScreen = sourceViewFrameInScreen
        self._presentationAnchorInSourceView = presentationAnchorInSourceView
        self.onPanelClose = onClose

        var styleMask: NSWindow.StyleMask = [.nonactivatingPanel, .titled, .fullSizeContentView]
        if allowResize {
            styleMask.insert(.resizable)
        }

        super.init(
            contentRect: CGRect(origin: .zero, size: defaultSize),
            styleMask: styleMask,
            backing: .buffered,
            defer: false
        )

        isFloatingPanel = true
        level = .floating
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        collectionBehavior = [.transient, .moveToActiveSpace]
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        isMovableByWindowBackground = true
        standardWindowButton(.closeButton)?.isHidden = true
        standardWindowButton(.miniaturizeButton)?.isHidden = true
        standardWindowButton(.zoomButton)?.isHidden = true
        backgroundColor = .windowBackgroundColor
        hasShadow = true
        minSize = CGSize(width: 220, height: 140)

        let rootView = content()
            .ignoresSafeArea(SafeAreaRegions.all)

        contentView = NSHostingView(rootView: rootView)

        delegate = self
    }

    public var isPresented: Bool {
        isVisible
    }

    public override func close() {
        dismiss()
    }

    public func updateOnClose(_ onClose: (() -> Void)?) {
        onPanelClose = onClose
    }

    var resolvedSourceAnchorInScreen: CGPoint? {
        guard let frame = sourceViewFrameInScreen, let anchor = presentationAnchorInSourceView else {
            return nil
        }
        return CGPoint(x: frame.minX + anchor.x, y: frame.minY + anchor.y)
    }

    public override var canBecomeKey: Bool { true }
    public override var canBecomeMain: Bool { true }

    public func windowDidMove(_ notification: Notification) {
        persistFrameIfAppropriate()
    }

    public func windowDidResize(_ notification: Notification) {
        persistFrameIfAppropriate()
    }

    public func windowDidEndLiveResize(_ notification: Notification) {
        persistFrameIfAppropriate()
    }

    public func windowDidResignKey(_ notification: Notification) {
        dismiss()
    }

    public func windowDidResignMain(_ notification: Notification) {
        // Non-activating panels can resign main during normal interactions.
        // Only key-resign should trigger dismissal.
    }
}
