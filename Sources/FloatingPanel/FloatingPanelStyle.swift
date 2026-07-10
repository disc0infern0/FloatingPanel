//
//  FloatingPanelStyle.swift
//  FloatingPanel
//
//  Created by Andrew on 20/05/2026.
//

import SwiftUI

/// Styling configuration for floating panel animations.
public struct FloatingPanelStyle: Sendable, Equatable {
    /// Controls which panel transitions animate.
    public enum AnimationOptions: String, Sendable, Equatable, Identifiable, CaseIterable {
        /// Animate both open and close transitions.
        case both
        /// Animate only panel open transitions.
        case openOnly
        /// Animate only panel close transitions.
        case closeOnly
        /// Disable open and close animations.
        case none

        public var id: String {self.rawValue}
    }

    /// Which transitions should animate.
    public var animationOptions: AnimationOptions
    
    /// Duration of enabled animations.
    public var animationDuration: TimeInterval

    /// Creates a floating panel style.
    public init(
        animationOptions: AnimationOptions = .both,
        animationDuration: TimeInterval = 0.18
    ) {
        self.animationOptions = animationOptions
        self.animationDuration = animationDuration
    }
}

public extension FloatingPanelStyle {
    /// Default style: animate open and close with default timing.
    static let `default` = FloatingPanelStyle()
    /// Disables all panel animations.
    static let noAnimation = FloatingPanelStyle(animationOptions: .none, animationDuration: 0)
    /// Animates open only; close is immediate.
    static let openAnimationOnly = FloatingPanelStyle(animationOptions: .openOnly)
    /// Animates close only; open is immediate.
    static let closeAnimationOnly = FloatingPanelStyle(animationOptions: .closeOnly)
}

extension FloatingPanelStyle {
    var animatesOnOpen: Bool {
        animationOptions == .both || animationOptions == .openOnly
    }

    var animatesOnClose: Bool {
        animationOptions == .both || animationOptions == .closeOnly
    }
}

extension EnvironmentValues {
    @Entry var floatingPanelStyle: FloatingPanelStyle = .default
}
//private struct FloatingPanelStyleEnvironmentKey: EnvironmentKey {
//    static let defaultValue: FloatingPanelStyle = .default
//}
//
//extension EnvironmentValues {
//    var floatingPanelStyle: FloatingPanelStyle {
//        get { self[FloatingPanelStyleEnvironmentKey.self] }
//        set { self[FloatingPanelStyleEnvironmentKey.self] = newValue }
//    }
//}

public extension View {
    /// Sets the floating panel style for this view hierarchy.
    func floatingPanelStyle(_ style: FloatingPanelStyle) -> some View {
        environment(\.floatingPanelStyle, style)
    }
}
