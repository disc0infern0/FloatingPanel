//  FloatingPanelContentSizer.swift
//  FloatingPanel

import SwiftUI

/// Wraps panel content and reports layout changes so the panel can auto-size.
///
/// The *given* size from `onGeometryChange` is intentionally ignored — what matters
/// is that something laid out. The panel responds by measuring the hosting view's
/// `fittingSize` (its ideal size) after layout, which is why the callback takes
/// no size argument.
struct FloatingPanelContentSizer<Content: View>: View {
    let content: Content
    let onSizeChange: () -> Void

    init(@ViewBuilder content: @escaping () -> Content, onSizeChange: @escaping () -> Void) {
        self.content = content()
        self.onSizeChange = onSizeChange
    }

    var body: some View {
        content
            .onGeometryChange(for: CGSize.self) { $0.size } action: { _ in
                onSizeChange()
            }
    }
}

/// Pure sizing rule shared by both platforms: take the larger of what the content
/// reported (the size it was given) and what it would take (its ideal size),
/// independently per axis.
public enum FloatingPanelSizing {
    /// Height of the visible drag strip on iPadOS (HIG 44-pt touch minimum).
    /// Included in the measured content height when `allowMove` is on.
    public static let dragStripHeight: CGFloat = 44

    public static func windowSize(reporting reported: CGSize, fitting: CGSize) -> CGSize {
        CGSize(
            width: max(reported.width, fitting.width),
            height: max(reported.height, fitting.height)
        )
    }
}
