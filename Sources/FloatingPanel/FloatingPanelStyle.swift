//
//  FloatingPanelStyle.swift
//  FloatingPanel
//
//  Created by Andrew on 20/05/2026.
//

import SwiftUI

public struct FloatingPanelStyle: Sendable, Equatable {
    public enum AnimationOptions: Sendable, Equatable {
        case both
        case openOnly
        case closeOnly
        case none
    }

    public var animationOptions: AnimationOptions
    public var animationDuration: TimeInterval
    public var animationDelay: TimeInterval

    public init(
        animationOptions: AnimationOptions = .both,
        animationDuration: TimeInterval = 0.18,
        animationDelay: TimeInterval = 0
    ) {
        self.animationOptions = animationOptions
        self.animationDuration = animationDuration
        self.animationDelay = animationDelay
    }
}

public extension FloatingPanelStyle {
    static let `default` = FloatingPanelStyle()
    static let noAnimation = FloatingPanelStyle(animationOptions: .none, animationDuration: 0, animationDelay: 0)
    static let openAnimationOnly = FloatingPanelStyle(animationOptions: .openOnly)
    static let closeAnimationOnly = FloatingPanelStyle(animationOptions: .closeOnly)
    static let delayed = FloatingPanelStyle(animationOptions: .both, animationDuration: 0.18, animationDelay: 0.12)
}

extension FloatingPanelStyle {
    var animatesOnOpen: Bool {
        animationOptions == .both || animationOptions == .openOnly
    }

    var animatesOnClose: Bool {
        animationOptions == .both || animationOptions == .closeOnly
    }

    func withFallbackDuration(_ duration: TimeInterval) -> FloatingPanelStyle {
        var copy = self
        if copy == .default {
            copy.animationDuration = duration
        }
        return copy
    }
}

private struct FloatingPanelStyleEnvironmentKey: EnvironmentKey {
    static let defaultValue: FloatingPanelStyle = .default
}

extension EnvironmentValues {
    var floatingPanelStyle: FloatingPanelStyle {
        get { self[FloatingPanelStyleEnvironmentKey.self] }
        set { self[FloatingPanelStyleEnvironmentKey.self] = newValue }
    }
}

public extension View {
    func floatingPanelStyle(_ style: FloatingPanelStyle) -> some View {
        environment(\.floatingPanelStyle, style)
    }
}
