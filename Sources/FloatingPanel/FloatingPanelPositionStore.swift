//
//  FloatingPanelPositionStore.swift
//  FloatingPanel
//
//  Created by Andrew on 19/05/2026.
//



import SwiftUI
@MainActor
struct FloatingPanelPositionStore {
    private static var sessionFrames: [String: CGRect] = [:]
    private let id: String

    init(id: String) {
        self.id = id
    }

    func save(frame: CGRect) {
        Self.sessionFrames[id] = frame
    }

    func loadFrame() -> CGRect? {
        Self.sessionFrames[id]
    }
}
