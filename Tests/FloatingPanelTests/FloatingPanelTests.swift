import Testing
import SwiftUI
import AsyncAlgorithms
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
@Suite("Debounce Pipeline")
struct DebouncePipelineTests {
    @Test("rapid burst emits only final debounced value")
    func burstCollapsesToLatest() async {
        let emitter = AsyncEmitter<Int>()

        let collector = Task { @MainActor in
            var values: [Int] = []
            for await value in emitter.values.debounce(for: .milliseconds(40)) {
                values.append(value)
                break
            }
            return values
        }

        emitter.send(1)
        emitter.send(2)
        emitter.send(3)
        try? await Task.sleep(for: .milliseconds(70))
        emitter.finish()

        let received = await collector.value
        #expect(received == [3])
    }

    @Test("values separated beyond debounce interval are both emitted")
    func spacedValuesBothEmit() async {
        let emitter = AsyncEmitter<Int>()

        let collector = Task { @MainActor in
            var values: [Int] = []
            for await value in emitter.values.debounce(for: .milliseconds(30)) {
                values.append(value)
                if values.count == 2 { break }
            }
            return values
        }

        await Task.yield()
        emitter.send(10)
        try? await Task.sleep(for: .milliseconds(50))
        emitter.send(20)
        try? await Task.sleep(for: .milliseconds(50))
        emitter.finish()

        let received = await collector.value
        #expect(received == [10, 20])
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
            style: .noAnimation,
            sourceViewFrameInScreen: sourceFrame,
            presentationAnchorInSourceView: sourceAnchor
        ) {
            Text("Test")
        }

        #expect(panel.resolvedSourceAnchorInScreen == CGPoint(x: 112, y: 234))
    }

    @Test("canBecomeKey and canBecomeMain are true")
    func canBecomeWindowRoles() {
        let panel = FloatingPanel(id: "panel.roles", style: .noAnimation) {
            Text("Test")
        }

        #expect(panel.canBecomeKey)
        #expect(panel.canBecomeMain)
    }

    @Test("windowDidResignMain does not dismiss panel")
    func resignMainDoesNotDismiss() {
        let panel = FloatingPanel(id: "panel.resign.main", style: .noAnimation) {
            Text("Test")
        }
        panel.present()
        #expect(panel.isPresented)

        panel.windowDidResignMain(Notification(name: NSWindow.didResignMainNotification))

        #expect(panel.isPresented)
        panel.dismiss()
    }

    @Test("windowDidResignKey dismisses panel")
    func resignKeyDismisses() {
        let panel = FloatingPanel(id: "panel.resign.key", style: .noAnimation) {
            Text("Test")
        }
        panel.present()
        #expect(panel.isPresented)

        panel.windowDidResignKey(Notification(name: NSWindow.didResignKeyNotification))

        #expect(!panel.isPresented)
    }

    @Test("persistFrameIfAppropriate saves valid frame when visible")
    func persistFrameWhenVisible() {
        let panel = FloatingPanel(id: "panel.persist.visible", style: .noAnimation) {
            Text("Test")
        }
        panel.present()

        let savedFrame = CGRect(x: 40, y: 50, width: 320, height: 280)
        panel.setFrame(savedFrame, display: false)
        panel.windowDidMove(Notification(name: NSWindow.didMoveNotification))

        #expect(panel.positionStore.loadFrame() == savedFrame)
        panel.dismiss()
    }

    @Test("persistFrameIfAppropriate ignores too-small frames")
    func persistIgnoresTooSmallFrames() {
        let panel = FloatingPanel(id: "panel.persist.small", style: .noAnimation) {
            Text("Test")
        }
        panel.present()

        let baseline = CGRect(x: 10, y: 20, width: 320, height: 280)
        panel.setFrame(baseline, display: false)
        panel.windowDidMove(Notification(name: NSWindow.didMoveNotification))
        #expect(panel.positionStore.loadFrame() == baseline)

        let tooSmall = CGRect(x: 99, y: 88, width: 100, height: 80)
        panel.setFrame(tooSmall, display: false)
        panel.windowDidMove(Notification(name: NSWindow.didMoveNotification))

        #expect(panel.positionStore.loadFrame() == baseline)
        panel.dismiss()
    }

    @Test("persistFrameIfAppropriate ignores animation phase")
    func persistIgnoresDuringAnimation() {
        let panel = FloatingPanel(id: "panel.persist.animating", style: .noAnimation) {
            Text("Test")
        }
        panel.present()

        let baseline = CGRect(x: 21, y: 22, width: 321, height: 281)
        panel.setFrame(baseline, display: false)
        panel.windowDidMove(Notification(name: NSWindow.didMoveNotification))
        #expect(panel.positionStore.loadFrame() == baseline)

        panel.isAnimatingPresentation = true
        let changed = CGRect(x: 55, y: 66, width: 333, height: 299)
        panel.setFrame(changed, display: false)
        panel.windowDidMove(Notification(name: NSWindow.didMoveNotification))
        panel.isAnimatingPresentation = false

        #expect(panel.positionStore.loadFrame() == baseline)
        panel.dismiss()
    }
}
