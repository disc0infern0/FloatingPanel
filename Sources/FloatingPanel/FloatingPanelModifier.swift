//
//  FloatingPanelModifier.swift
//  FloatingPanel
//
//  Created by Andrew on 19/05/2026.
//

import SwiftUI
import AppKit
import AsyncAlgorithms

/// The public interface of how a floating panel is displayed
public extension View {
    /// Presents a floating panel anchored to this view.
    /// - Parameters:
    ///   - isPresented: Controls panel presentation.
    ///   - defaultSize: Initial panel size. Uses the package default when `nil`.
    ///   - allowResize: Whether the panel can be resized by the user.
    ///   - content: Panel content view builder.
    func floatingPanel<PanelContent: View>(
        isPresented: Binding<Bool>,
        defaultSize: CGSize? = nil,
        allowResize: Bool = true,
        @ViewBuilder content: @escaping () -> PanelContent
    ) -> some View {
        modifier(
            FloatingPanelModifier(
                isPresented: isPresented,
                defaultSize: defaultSize,
                allowResize: allowResize,
                panelContent: content
            )
        )
    }
}

/// The view modifier that makes all the magic happen.
private struct FloatingPanelModifier<PanelContent: View>: ViewModifier {
    @Environment(\.floatingPanelStyle) private var floatingPanelStyle
    let id: String = UUID().uuidString
    @Binding var isPresented: Bool
    let defaultSize: CGSize?
    let allowResize: Bool
    let panelContent: () -> PanelContent

    @State private var panel: FloatingPanel<PanelContent>?
    @State private var sourceViewFrameInScreen: CGRect?
    @State private var presentationAnchorInSourceView: CGPoint?
    @State private var frameEmitter = AsyncEmitter<CGRect?>()

    func body(content: Content) -> some View {
        content
            .background(
                /// Match the geomtry of content with an AppKit view that reports its frame updates into `frameEmitter`.
                SourceViewFrameReader(frameEmitter: frameEmitter)
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
//        let panelID = "FloatingPanel.Default"
        let isPresented = _isPresented
        let resolvedDefaultSize = defaultSize ?? CGSize(width: 360, height: 320)
        return FloatingPanel(
//            id: panelID,
            id: id,
            defaultSize: resolvedDefaultSize,
            style: floatingPanelStyle,
            allowResize: allowResize,
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
    ///
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
        for await frameInScreen in frameEmitter.values.debounce(for: .milliseconds(42)) {
            guard sourceViewFrameInScreen != frameInScreen else { continue }
            sourceViewFrameInScreen = frameInScreen
        }
    }
}
