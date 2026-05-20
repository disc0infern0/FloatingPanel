# FloatingPanel

`FloatingPanel` is a SwiftUI modifier for macOS that presents a movable, resizable floating utility panel.

## Overview

Use a `Binding<Bool>` to control presentation, similar to `popover`/`sheet`, while the content is rendered in a macOS utility window (`NSPanel`).

## Usage

The floating panel is presented via a SwiftUI view modifier defined as:-

```swift
public extension View {
    func floatingPanel<PanelContent: View>(
        isPresented: Binding<Bool>,
        defaultSize: CGSize = CGSize(width: 360, height: 320),  // Optional, override if your content is also fixed.
        animationDuration: TimeInterval = 0.18,                 // Optional, sensible default
        allowResize: Bool = true,                               // Optional, toggle panel resizing
        @ViewBuilder content: @escaping () -> PanelContent
    ) -> some View
}
```

Parameters:
- `isPresented`: Binding that presents (`true`) or dismisses (`false`) the panel.
- `defaultSize`: Initial panel size used on first presentation.
- `animationDuration`: Open/close animation duration in seconds. Use `0` to disable animation.
- `allowResize`: Controls whether the panel can be resized by the user.
- `content`: SwiftUI content shown inside the floating panel.

Example:

```swift
import SwiftUI
import FloatingPanel

struct ContentView: View {
    @State private var isPanelPresented = false

    var body: some View {
        VStack {
            Button("Toggle Panel") {
                isPanelPresented.toggle()
            }
        }
        .floatingPanel(
            isPresented: $isPanelPresented,
            defaultSize: CGSize(width: 420, height: 320),
            animationDuration: 0.18,
            allowResize: true
        ) {
            Color.blue
        }
    }
}
```

## Notes

- The panel is non-activating, titled, and full-size-content; resizability is controlled by `allowResize`.
- Dismissing by updating `isPresented = false` is the canonical control path from the presenting view.
- See `FloatingPanelDemo` and `UsageExample` in this package for complete integration examples.
