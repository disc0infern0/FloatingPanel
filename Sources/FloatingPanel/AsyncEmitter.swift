//
//  AsyncEmitter.swift
//  FloatingPanel
//
//  Created by Andrew on 19/05/2026.
//

import Foundation

/// A lightweight async event emitter intended for a single consumer task.
internal final class AsyncEmitter<T: Sendable> {
    private let stream: AsyncStream<T>
    private var continuation: AsyncStream<T>.Continuation?
    private var isFinished = false

    init() {
        var capturedContinuation: AsyncStream<T>.Continuation?
        self.stream = AsyncStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
            capturedContinuation = continuation
        }
        guard let continuation = capturedContinuation else {
            fatalError("Failed to initialize async stream continuation")
        }
        self.continuation = continuation
    }

    deinit {
        finish()
    }

    /// Returns a sequence of values to consume from this emitter.
    var values: AsyncStream<T> {
        stream
    }

    func send(_ value: T) {
        guard !isFinished else { return }
        guard let continuation else { return }
        continuation.yield(value)
    }

    func finish() {
        guard !isFinished else { return }
        isFinished = true
        continuation?.finish()
        continuation = nil
    }
}
