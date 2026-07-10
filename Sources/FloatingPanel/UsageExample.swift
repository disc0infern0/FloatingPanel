import SwiftUI

public struct FloatingPanelUsageExampleView: View {
    @State private var isPanelPresented = false

    public init() {}

    public var body: some View {
        VStack(spacing: 16) {
            Button {
                isPanelPresented.toggle()
            } label: {
                Label("Toggle Panel", systemImage: "rectangle.topthird.inset.filled")
            }
            .buttonStyle(.bordered)

            Text("Use this button like a toolbar trigger.")
                .foregroundColor(.secondary)
        }
        .padding(24)
        .floatingPanelStyle(
            FloatingPanelStyle(
                animationOptions: .both,
                animationDuration: 0.24
            )
        )
        .floatingPanel(isPresented: $isPanelPresented) {
            ExamplePanelContent(isPresented: $isPanelPresented)
        }
    }
}

private struct ExamplePanelContent: View {
    @Binding var isPresented: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Floating Panel")
                .font(.headline)

            Text("This content is presented inside the FloatingPanel package panel.")
                .font(.subheadline)
                .foregroundColor(.secondary)

            HStack {
                Spacer()
                Button("Close") {
                    isPresented = false
                }
                .keyboardShortcut(.cancelAction)
            }
        }
        .padding(16)
        .frame(width: 320)
    }
}
