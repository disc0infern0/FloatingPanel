//
//  FloatingPanelModifier.swift
//  FloatingPanel
//
//  Created by Andrew on 19/05/2026.
//

import SwiftUI
import AsyncAlgorithms

#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif

/// The public interface of how a floating panel is displayed
public extension View {
    /// Presents a floating panel anchored to this view.
    /// - Parameters:
    ///   - id: Stable identifier for the panel's frame persistence. When `nil`,
    ///     a random ID is generated once for the lifetime of this view.
    ///   - isPresented: Controls panel presentation.
    ///   - defaultSize: Initial panel size. Uses the package default when `nil`.
    ///   - allowMove: Whether the panel can be moved by the user.
    ///   - allowResize: Whether the panel can be resized by the user.
    ///   - autoSizeToContent: When `true`, the panel resizes to fit its content
    ///     (top-edge anchored) instead of staying at `defaultSize`.
    ///   - content: Panel content view builder.
    func floatingPanel<PanelContent: View>(
        id: String? = nil,
        isPresented: Binding<Bool>,
        defaultSize: CGSize? = nil,
        allowMove: Bool = true,
        allowResize: Bool = true,
        autoSizeToContent: Bool = false,
        @ViewBuilder content: @escaping () -> PanelContent
    ) -> some View {
        modifier(
            FloatingPanelModifier(
                suppliedID: id,
                isPresented: isPresented,
                defaultSize: defaultSize,
                allowMove: allowMove,
                allowResize: allowResize,
                autoSizeToContent: autoSizeToContent,
                panelContent: content
            )
        )
    }
}

/// Routes the shared floating panel API to the platform-specific backend.
private struct FloatingPanelModifier<PanelContent: View>: ViewModifier {
    let suppliedID: String?
    @State private var generatedID = UUID().uuidString
    @Binding var isPresented: Bool
    let defaultSize: CGSize?
    let allowMove: Bool
    let allowResize: Bool
    let autoSizeToContent: Bool
    let panelContent: () -> PanelContent

    /// The ID actually used for frame persistence: the caller's if supplied,
    /// otherwise one generated for the lifetime of this modifier.
    private var resolvedID: String { suppliedID ?? generatedID }

    func body(content: Content) -> some View {
#if os(macOS)
        content.modifier(
            MacFloatingPanelModifier(
                id: resolvedID,
                isPresented: $isPresented,
                defaultSize: defaultSize,
                allowMove: allowMove,
                allowResize: allowResize,
                autoSizeToContent: autoSizeToContent,
                panelContent: panelContent
            )
        )
#elseif os(iOS)
        content.modifier(
            IOSFloatingPanelModifier(
                id: resolvedID,
                isPresented: $isPresented,
                defaultSize: defaultSize,
                allowMove: allowMove,
                allowResize: allowResize,
                autoSizeToContent: autoSizeToContent,
                panelContent: panelContent
            )
        )
#else
        content
#endif
    }
}

#if os(macOS)
/// macOS backend: hosts the panel in an `NSPanel` window.
private struct MacFloatingPanelModifier<PanelContent: View>: ViewModifier {
    let id: String
    @Binding var isPresented: Bool
    let defaultSize: CGSize?
    let allowMove: Bool
    let allowResize: Bool
    let autoSizeToContent: Bool
    let panelContent: () -> PanelContent

    @Environment(\.floatingPanelStyle) private var floatingPanelStyle

    @State private var panel: FloatingPanel<PanelContent>?
    @State private var sourceViewFrameInScreen: CGRect?
    @State private var presentationAnchorInSourceView: CGPoint?
    @State private var frameChannel = AsyncChannel<CGRect?>()

    func body(content: Content) -> some View {
        content
            .background(
                /// Match the geometry of content with an AppKit view that reports its frame updates into `frameChannel`.
                SourceViewFrameReader(frameChannel: frameChannel)
            )
            .task {
                await consumeFrameUpdates()
            }
            .onAppear {
                if panel == nil {
                    panel = makePanel()
                }
                if isPresented {
                    capturePresentationAnchor()
                    panel?.present()
                }
            }
            .onChange(of: floatingPanelStyle) {
                panel = nil
                panel = makePanel()
            }
            .onChange(of: isPresented) { _, shouldPresent in
                guard let panel else { return }
                if shouldPresent {
                    if !panel.isPresented {
                        capturePresentationAnchor()
                        panel.present()
                    }
                } else if panel.isPresented {
                    panel.dismiss()
                }
            }
            .onDisappear {
                panel?.dismiss()
            }
    }

    private func makePanel() -> FloatingPanel<PanelContent> {
        let isPresented = _isPresented
        let resolvedDefaultSize = defaultSize ?? CGSize(width: 360, height: 320)
        return FloatingPanel(
            id: id,
            defaultSize: resolvedDefaultSize,
            style: floatingPanelStyle,
            allowMove: allowMove,
            allowResize: allowResize,
            autoSizeToContent: autoSizeToContent,
            sourceViewFrameInScreen: $sourceViewFrameInScreen,
            presentationAnchorInSourceView: $presentationAnchorInSourceView,
            onClose: {
                if isPresented.wrappedValue {
                    isPresented.wrappedValue = false
                }
            },
            content: panelContent
        )
    }

    /// Anchor updates needed for the close animation to go into the right place
    private func capturePresentationAnchor() {
        guard let frame = sourceViewFrameInScreen else {
            presentationAnchorInSourceView = nil
            return
        }

        let mouse = NSEvent.mouseLocation
        presentationAnchorInSourceView = CGPoint(
            x: mouse.x - frame.minX,
            y: mouse.y - frame.minY
        )
    }

    /// Debounces frame updates before writing SwiftUI state.
    @MainActor
    private func consumeFrameUpdates() async {
        for await frameInScreen in frameChannel.debounce(for: .milliseconds(42)) {
            guard sourceViewFrameInScreen != frameInScreen else { continue }
            sourceViewFrameInScreen = frameInScreen
        }
    }
}
#endif

#if os(iOS)
/// iPadOS backend: hosts the panel in a `UIWindow` — the UIKit equivalent of
/// the macOS `NSPanel`. The window is draggable over the whole scene, including
/// outside the bounds of the view that presented it.
private struct IOSFloatingPanelModifier<PanelContent: View>: ViewModifier {
    let id: String
    @Binding var isPresented: Bool
    let defaultSize: CGSize?
    let allowMove: Bool
    let allowResize: Bool
    let autoSizeToContent: Bool
    let panelContent: () -> PanelContent

    @Environment(\.floatingPanelStyle) private var floatingPanelStyle

    @State private var panel: FloatingPanel<PanelContent>?
    @State private var sourceViewFrameInWindow: CGRect?
    @State private var presentationAnchorInWindow: CGPoint?
    @State private var frameChannel = AsyncChannel<CGRect?>()

    func body(content: Content) -> some View {
        content
            .background(
                /// Reports the source view's frame in window coordinates.
                SourceViewFrameReader(frameChannel: frameChannel)
            )
            .task {
                await consumeFrameUpdates()
            }
            .onAppear {
                if panel == nil {
                    panel = makePanel()
                }
                if isPresented {
                    panel?.present()
                }
            }
            .onChange(of: floatingPanelStyle) {
                panel = nil
                panel = makePanel()
            }
            .onChange(of: isPresented) { _, shouldPresent in
                guard let panel else { return }
                if shouldPresent {
                    if !panel.isPresented {
                        panel.present()
                    }
                } else if panel.isPresented {
                    panel.dismiss()
                }
            }
            .onDisappear {
                panel?.dismiss()
            }
    }

    private func makePanel() -> FloatingPanel<PanelContent>? {
        guard let windowScene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene else {
            return nil
        }

        let isPresented = _isPresented
        let resolvedDefaultSize = defaultSize ?? CGSize(width: 360, height: 320)
        return FloatingPanel(
            windowScene: windowScene,
            id: id,
            defaultSize: resolvedDefaultSize,
            style: floatingPanelStyle,
            allowMove: allowMove,
            allowResize: allowResize,
            autoSizeToContent: autoSizeToContent,
            sourceViewFrameInWindow: $sourceViewFrameInWindow,
            presentationAnchorInWindow: $presentationAnchorInWindow,
            onClose: {
                if isPresented.wrappedValue {
                    isPresented.wrappedValue = false
                }
            },
            content: panelContent
        )
    }

    /// Debounces frame updates before writing SwiftUI state.
    @MainActor
    private func consumeFrameUpdates() async {
        for await frameInWindow in frameChannel.debounce(for: .milliseconds(42)) {
            guard sourceViewFrameInWindow != frameInWindow else { continue }
            sourceViewFrameInWindow = frameInWindow
        }
    }
}
#endif
