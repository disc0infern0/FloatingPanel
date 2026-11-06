//
//  FloatingPanelAnimation.swift
//  FloatingPanel
//
//  Created by Andrew on 19/05/2026.
//



#if os(macOS)
import SwiftUI
extension FloatingPanel  {
    
    public func present() {
        let anchor = resolvedSourceAnchorInScreen ?? NSEvent.mouseLocation
        lastPresentationAnchor = anchor

        let targetFrame = resolvedFrame(anchor: anchor)
        setFrame(targetFrame, display: false)
        orderFrontRegardless()
        makeKey()

        animatePresentation(from: anchor, to: targetFrame)

        if autoSizeToContent {
            // Defer past the open animation: resizeToFitContent bails while animating.
            let delay = style.animatesOnOpen ? style.animationDuration : 0
            Task { @MainActor [weak self] in
                if delay > 0 {
                    try? await Task.sleep(for: .seconds(delay))
                }
                self?.resizeToFitContent()
            }
        }
    }

    public func dismiss() {
        animateClose()
    }

    private func resolvedFrame(anchor: CGPoint) -> CGRect {
        // `setFrameUsingName` was already applied in init, so `frame` here reflects a restored frame if one exists.
        if frame.origin != .zero || frame.size != defaultSize {
            return clampToVisibleScreen(frame, anchor: anchor)
        }

        let proposedOrigin = CGPoint(
            x: anchor.x - (defaultSize.width / 2),
            y: anchor.y + 12
        )

        return clampToVisibleScreen(CGRect(origin: proposedOrigin, size: defaultSize), anchor: anchor)
    }

    private func clampToVisibleScreen(_ frame: CGRect, anchor: CGPoint) -> CGRect {
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(anchor) }) ?? NSScreen.main else {
            return frame
        }

        let visibleFrame = screen.visibleFrame
        let clampedSize = CGSize(
            width: min(frame.width, visibleFrame.width),
            height: min(frame.height, visibleFrame.height)
        )
        var clampedOrigin = frame.origin
        clampedOrigin.x = min(max(clampedOrigin.x, visibleFrame.minX), visibleFrame.maxX - clampedSize.width)
        clampedOrigin.y = min(max(clampedOrigin.y, visibleFrame.minY), visibleFrame.maxY - clampedSize.height)

        return CGRect(origin: clampedOrigin, size: clampedSize)
    }

    private func animatePresentation(from anchor: CGPoint, to finalFrame: CGRect) {
        isAnimatingPresentation = true
        let startFrame = CGRect(x: anchor.x, y: anchor.y, width: 1, height: 1)
        alphaValue = 0
        setFrame(startFrame, display: true)
        orderFrontRegardless()

        guard style.animatesOnOpen, style.animationDuration > 0 else {
            alphaValue = 1
            setFrame(finalFrame, display: true)
            isAnimatingPresentation = false
            return
        }

        let runAnimation = { [weak self] in
            guard let self else { return }
            NSAnimationContext.runAnimationGroup { context in
                context.duration = self.style.animationDuration
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                context.completionHandler = { [weak self] in
                    self?.isAnimatingPresentation = false
                }
                self.animator().alphaValue = 1
                self.animator().setFrame(finalFrame, display: true)
            }
        }
        runAnimation()
    }

    private func animateClose() {
        guard isVisible, !isAnimatingClose else { return }
        isAnimatingClose = true

        let anchor = resolvedSourceAnchorInScreen ?? lastPresentationAnchor ?? NSEvent.mouseLocation
        let endFrame = CGRect(x: anchor.x, y: anchor.y, width: 1, height: 1)

        guard style.animatesOnClose, style.animationDuration > 0 else {
            alphaValue = 0
            setFrame(endFrame, display: true)
            orderOut(nil)
            alphaValue = 1
            isAnimatingClose = false
            onPanelClose?()
            return
        }

        let runAnimation = { [weak self] in
            guard let self else { return }
            NSAnimationContext.runAnimationGroup { context in
                context.duration = self.style.animationDuration
                context.timingFunction = CAMediaTimingFunction(name: .easeIn)
                context.completionHandler = { [weak self] in
                    guard let self else { return }
                    self.alphaValue = 0
                    self.orderOut(nil)
                    self.alphaValue = 1
                    self.isAnimatingClose = false
                    self.onPanelClose?()
                }

                // Keep the panel more visible until late in the close animation.
                self.animator().alphaValue = 0.18
                self.animator().setFrame(endFrame, display: true)
            }
        }
        runAnimation()
    }

    /// Stop the animation triggering storage of intermediate frame sizes
    func persistFrameIfAppropriate() {
        guard isVisible, !isAnimatingPresentation, !isAnimatingClose else { return }
        guard frame.width >= minSize.width, frame.height >= minSize.height else { return }
        guard frame.origin.x.isFinite, frame.origin.y.isFinite, frame.width.isFinite, frame.height.isFinite else { return }
        saveFrame(usingName: panelID)
    }

    /// Resizes the panel to fit its content, holding the top edge still.
    ///
    /// No-ops while animating, matching `persistFrameIfAppropriate`: mid-transition
    /// frame sizes are the animation's, not the content's.
    func resizeToFitContent() {
        guard autoSizeToContent, isVisible, !isAnimatingPresentation, !isAnimatingClose else { return }
        guard let contentView else { return }

        contentView.layoutSubtreeIfNeeded()
        let fitting = contentView.fittingSize
        let target = FloatingPanelSizing.windowSize(reporting: frame.size, fitting: fitting)
        guard target != frame.size else { return }

        let old = frame
        // AppKit origin is bottom-left; moving the origin up by the height delta
        // keeps the top edge (and the control that triggered the panel) still.
        var newFrame = NSRect(origin: CGPoint(x: old.origin.x, y: old.origin.y + old.height - target.height), size: target)
        newFrame = clampToVisibleScreen(newFrame, anchor: NSPoint(x: newFrame.midX, y: newFrame.maxY))
        // Clamping can shrink the panel to the visible area; re-derive height
        // target so a clamped panel does not report itself as fitting.
        guard newFrame.size != old.size || newFrame.origin != old.origin else { return }
        // If clamping shrank the size, keep the top edge but re-clamp origin.
        newFrame.origin.y = max(newFrame.origin.y, NSScreen.main?.visibleFrame.minY ?? newFrame.origin.y)
        setFrame(newFrame, display: true)
        saveFrame(usingName: panelID)
    }
}
#endif
