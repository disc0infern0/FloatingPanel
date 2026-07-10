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
        defaultSize: CGSize? = nil,    // Optional. Uses package default when nil.
        allowResize: Bool = true,      // Optional, toggle panel resizing
        @ViewBuilder content: @escaping () -> PanelContent
    ) -> some View
}
```

Parameters:
- `isPresented`: Binding that presents (`true`) or dismisses (`false`) the panel.
- `defaultSize`: Initial panel size used on first presentation (`nil` uses package default).
- `allowResize`: Controls whether the panel can be resized by the user.
- `content`: SwiftUI content shown inside the floating panel.

Animation settings are configured through `floatingPanelStyle(...)`:

```swift
.floatingPanelStyle(
    FloatingPanelStyle(
        animationOptions: .both,     // .both, .openOnly, .closeOnly, .none
        animationDuration: 0.24
    )
)
```

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
            allowResize: true
        ) {
            Color.blue
        }
        .floatingPanelStyle(.openAnimationOnly)
    }
}
```

## Quick Start + Recipes

### Quick Start

```swift
import SwiftUI
import FloatingPanel

struct QuickStartView: View {
    @State private var isPanelPresented = false

    var body: some View {
        Button("Toggle Panel") {
            isPanelPresented.toggle()
        }
        .floatingPanel(isPresented: $isPanelPresented) {
            Text("Hello from FloatingPanel")
                .padding()
        }
    }
}
```

### Recipe: Toolbar Panel

```swift
struct ToolbarPanelExample: View {
    @State private var isPanelPresented = false

    var body: some View {
        Text("Main Content")
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button {
                        isPanelPresented.toggle()
                    } label: {
                        Label("Toggle Panel", systemImage: "rectangle.topthird.inset.filled")
                    }
                }
            }
            .floatingPanel(isPresented: $isPanelPresented) {
                Text("Toolbar-triggered panel")
                    .padding()
            }
            .floatingPanelStyle(.openAnimationOnly)
    }
}
```

### Recipe: Inspector Panel

```swift
struct InspectorPanelExample: View {
    @State private var showInspector = false

    var body: some View {
        Text("Editor Surface")
            .floatingPanel(
                isPresented: $showInspector,
                defaultSize: .init(width: 320, height: 420),
                allowResize: true
            ) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Inspector").font(.headline)
                    Text("Controls go here").foregroundColor(.secondary)
                }
                .padding()
            }
            .floatingPanelStyle(FloatingPanelStyle(animationOptions: .both, animationDuration: 0.2))
    }
}
```

### Recipe: Non-Resizable Pop Panel

```swift
struct PopPanelExample: View {
    @State private var showPanel = false

    var body: some View {
        Button("Show Pop Panel") {
            showPanel = true
        }
        .floatingPanel(
            isPresented: $showPanel,
            defaultSize: .init(width: 260, height: 160),
            allowResize: false
        ) {
            VStack(spacing: 10) {
                Text("Quick Actions")
                Button("Close") { showPanel = false }
            }
            .padding()
        }
        .floatingPanelStyle(.noAnimation)
    }
}
```

## Notes

- The panel is non-activating, titled, and full-size-content; resizability is controlled by `allowResize`.
- Dismissing by updating `isPresented = false` is the canonical control path from the presenting view.
- See `FloatingPanelDemo` and `UsageExample` in this package for complete integration examples.
