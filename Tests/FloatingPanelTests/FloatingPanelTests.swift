import Testing
import SwiftUI
@testable import FloatingPanel

@MainActor
@Suite("AsyncEmitter")
struct AsyncEmitterTests {
    @Test("buffer keeps newest value when producer outruns consumer")
    func keepsNewestValueUnderBurst() async {
        let emitter = AsyncEmitter<Int>()

        emitter.send(1)
        emitter.send(2)
        emitter.send(3)
        emitter.finish()

        var received: [Int] = []
        for await value in emitter.values {
            received.append(value)
        }

        #expect(received == [3])
    }

    @Test("finish ends iteration and send after finish is ignored")
    func finishStopsFurtherEmission() async {
        let emitter = AsyncEmitter<Int>()
        emitter.send(10)
        emitter.finish()
        emitter.send(20)

        var iterator = emitter.values.makeAsyncIterator()
        let first = await iterator.next()
        let second = await iterator.next()

        #expect(first == 10)
        #expect(second == nil)
    }
}

@MainActor
@Suite("FloatingPanelPositionStore")
struct FloatingPanelPositionStoreTests {
    @Test("saved frame can be loaded by matching id")
    func saveThenLoad() {
        let store = FloatingPanelPositionStore(id: "store.save.load")
        let frame = CGRect(x: 11, y: 22, width: 333, height: 444)

        store.save(frame: frame)

        #expect(store.loadFrame() == frame)
    }

    @Test("different ids do not share frames")
    func differentIDsAreIsolated() {
        let first = FloatingPanelPositionStore(id: "store.isolation.one")
        let second = FloatingPanelPositionStore(id: "store.isolation.two")
        let frame = CGRect(x: 1, y: 2, width: 3, height: 4)

        first.save(frame: frame)

        #expect(second.loadFrame() == nil)
    }
}

@MainActor
@Suite("FloatingPanel")
struct FloatingPanelCoreTests {
    @Test("resolved source anchor uses frame and local anchor")
    func resolvedSourceAnchorComputation() {
        let sourceFrame = Binding<CGRect?>.constant(CGRect(x: 100, y: 200, width: 300, height: 400))
        let sourceAnchor = Binding<CGPoint?>.constant(CGPoint(x: 12, y: 34))

        let panel = FloatingPanel(
            id: "panel.anchor",
            animationDuration: 0,
            sourceViewFrameInScreen: sourceFrame,
            presentationAnchorInSourceView: sourceAnchor
        ) {
            Text("Test")
        }

        #expect(panel.resolvedSourceAnchorInScreen == CGPoint(x: 112, y: 234))
    }

    @Test("canBecomeKey and canBecomeMain are true")
    func canBecomeWindowRoles() {
        let panel = FloatingPanel(id: "panel.roles", animationDuration: 0) {
            Text("Test")
        }

        #expect(panel.canBecomeKey)
        #expect(panel.canBecomeMain)
    }
}
