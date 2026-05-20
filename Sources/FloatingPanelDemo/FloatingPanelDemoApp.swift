import SwiftUI
import FloatingPanel

@available(macOS 13.0, *)
@main
struct FloatingPanelDemoApp: App {

    var body: some Scene {
        WindowGroup {
            DemoContentView()
        }
        .windowToolbarStyle(.unified)
    }
}

@available(macOS 13.0, *)
struct DemoContentView: View {
    @State private var isPanelPresented = false

    var body: some View {
        VStack(spacing: 14) {
            Text("FloatingPanel Demo")
                .font(.title2)
            Text("Use the toolbar button to toggle the floating panel.")
                .foregroundColor(.secondary)
            HStack {
                Button("Close Panel (state variable)") {
                    isPanelPresented = false
                }
                .disabled(isPanelPresented == false)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button {
                    isPanelPresented.toggle()
                } label: {
                    Label("Toggle Panel", systemImage: "rectangle.topthird.inset.filled")
                }
            }
        }
        .floatingPanel(isPresented: $isPanelPresented,
                       defaultSize: .init(width: 200, height: 500),
                       animationDuration: 0.98,
                       allowResize: false) {
            PanelContent(isPanelPresented: $isPanelPresented)
        }
        .task(id: isPanelPresented) {
            guard isPanelPresented == true else { return }
            try? await Task.sleep(for: .seconds(5))
            isPanelPresented = false
        }
    }
}

@available(macOS 13.0, *)
private struct PanelContent: View {
    @Binding var isPanelPresented: Bool

    var body: some View {
        ZStack {
            Color.secondary
            VStack(alignment: .leading, spacing: 12) {
                Text("Floating Panel")
                    .font(.headline)

                Text("This content is presented inside the FloatingPanel package panel.\n\nIt will be automatically closed in 5 seconds")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                HStack {
                    Spacer()
                    Button("Close") {
                        isPanelPresented = false
                    }.buttonStyle(.borderedProminent)
                    Spacer()
                }
                .keyboardShortcut(.cancelAction)
            }
            .padding(.horizontal, 8)
        }
    }
}
