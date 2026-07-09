import Combine

// NSHostingController.rootView stays assigned even while the popover itself
// isn't on screen (render() updates it on every state change regardless of
// popover.isShown), so SwiftUI's onAppear/onDisappear on the view tree do
// NOT reliably track actual popover visibility. Anything with a real side
// effect that should only run while the popover is actually open (like
// engaging the system audio tap for the visualizer) needs an explicit
// signal instead.
final class PopoverVisibility: ObservableObject {
    @Published var isVisible = false
}
