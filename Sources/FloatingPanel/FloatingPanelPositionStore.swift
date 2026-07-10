//
//  FloatingPanelPositionStore.swift
//  FloatingPanel
//
//  Created by Andrew on 19/05/2026.
//



import CoreGraphics // for CGRect definition

@MainActor
struct FloatingPanelPositionStore: Identifiable {
    let id: String
    private static var sessionFrames: [String: CGRect] = [:]

    func save(frame: CGRect) {
        Self.sessionFrames[id] = frame
    }

    func loadFrame() -> CGRect? {
        Self.sessionFrames[id]
    }
}
