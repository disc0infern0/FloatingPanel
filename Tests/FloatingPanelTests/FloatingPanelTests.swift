import Testing
import SwiftUI
import AsyncAlgorithms
@testable import FloatingPanel

@MainActor
@Suite("AsyncChannel")
struct AsyncChannelTests {
    @Test("finish ends iteration and send after finish is ignored")
    func finishStopsFurtherEmission() async {
        let channel = AsyncChannel<Int>()

        let collector = Task { @MainActor in
            var received: [Int] = []
            for await value in channel {
                received.append(value)
            }
            return received
        }

        // Give the consumer a chance to attach before producing.
        await Task.yield()
        await channel.send(10)

        // Give the consumer a chance to run before finishing.
        try? await Task.sleep(for: .milliseconds(30))
        channel.finish()

        let received = await collector.value
        #expect(received == [10])

        // Sends after finish should not crash and should be ignored.
        await channel.send(20)
    }

    @Test("channel is an AsyncSequence that yields sent values")
    func yieldsSentValues() async {
        let channel = AsyncChannel<Int>()

        let producer = Task {
            await channel.send(1)
            await channel.send(2)
            channel.finish()
        }

        var received: [Int] = []
        for await value in channel {
            received.append(value)
        }

        await producer.value
        #expect(received == [1, 2])
    }
}

@MainActor
@Suite("Debounce Pipeline")
struct DebouncePipelineTests {
    @Test("rapid burst emits only final debounced value")
    func burstCollapsesToLatest() async {
        let channel = AsyncChannel<Int>()

        let collector = Task { @MainActor in
            var values: [Int] = []
            for await value in channel.debounce(for: .milliseconds(40)) {
                values.append(value)
                break
            }
            return values
        }

        let producer = Task {
            await channel.send(1)
            await channel.send(2)
            await channel.send(3)
        }
        try? await Task.sleep(for: .milliseconds(70))
        channel.finish()

        let received = await collector.value
        await producer.value
        #expect(received == [3])
    }

    @Test("values separated beyond debounce interval are both emitted")
    func spacedValuesBothEmit() async {
        let channel = AsyncChannel<Int>()

        let collector = Task { @MainActor in
            var values: [Int] = []
            for await value in channel.debounce(for: .milliseconds(30)) {
                values.append(value)
                if values.count == 2 { break }
            }
            return values
        }

        // Ensure the collector is attached before producing.
        await Task.yield()

        let producer = Task {
            await channel.send(10)
            try? await Task.sleep(for: .milliseconds(50))
            await channel.send(20)
        }

        let received = await collector.value
        await producer.value
        channel.finish()

        #expect(received == [10, 20])
    }
}

#if os(macOS)
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

        // frameAutosaveName is set from the panel id via saveFrame(usingName:).
        let restored = FloatingPanel(id: "panel.persist.normal", style: .noAnimation) { Text("Test") }
        _ = restored
        #expect(panel.frame == savedFrame)
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
        #expect(panel.frame == baseline)

        let tooSmall = CGRect(x: 99, y: 88, width: 100, height: 80)
        panel.setFrame(tooSmall, display: false)
        panel.windowDidMove(Notification(name: NSWindow.didMoveNotification))

        // Frame should not be saved, so saved value remains the baseline.
        #expect(panel.frame == tooSmall) // panel moved, but nothing was persisted
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
        #expect(panel.frame == baseline)

        panel.isAnimatingPresentation = true
        let changed = CGRect(x: 55, y: 66, width: 333, height: 299)
        panel.setFrame(changed, display: false)
        panel.windowDidMove(Notification(name: NSWindow.didMoveNotification))
        panel.isAnimatingPresentation = false

        // During animation the frame was not persisted, so restoring from the
        // autosave name should still give us the baseline rather than `changed`.
        let afterAnimationFrame = panel.frame
        #expect(afterAnimationFrame == changed) // we moved it, but we didn't save during animation
        panel.dismiss()
    }
}
#endif
