import SwiftUI
import UIKit

@main
struct MyApp: App {
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @StateObject private var gallery = GalleryStore()

    init() {
        // ← Remove this block when you're done testing
        UserDefaults.standard.removeObject(forKey: "hasSeenOnboarding")

        patchSplitViewToggleButton()
    }

    var body: some Scene {
        WindowGroup {
            if hasSeenOnboarding {
                ContentView()
                    .environmentObject(gallery)
            } else {
                OnboardingView(hasSeenOnboarding: $hasSeenOnboarding)
                    .environmentObject(gallery)
            }
        }
    }
}

// MARK: - Sidebar toggle button patcher

/// The NavigationSplitView sidebar toggle is a private
/// `_UISplitViewControllerPanelToggleButton`. Its glass pill background
/// lives in a subview whose class name contains "Background".
/// UIAppearance can't reach it, so we walk the live hierarchy.

func patchSplitViewToggleButton() {
    let purple = UIColor(red: 0.40, green: 0.33, blue: 0.85, alpha: 1.0)

    // Runs once the first window is available
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { applyPatch(purple) }
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.20) { applyPatch(purple) }
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.60) { applyPatch(purple) }
    DispatchQueue.main.asyncAfter(deadline: .now() + 1.20) { applyPatch(purple) }
}

private func applyPatch(_ purple: UIColor) {
    guard let window = UIApplication.shared.connectedScenes
        .compactMap({ $0 as? UIWindowScene })
        .flatMap({ $0.windows })
        .first(where: { $0.isKeyWindow }) else { return }

    walkAndPatch(view: window, purple: purple)
}

private func walkAndPatch(view: UIView, purple: UIColor) {
    let className = NSStringFromClass(type(of: view))

    // Target: the toggle button itself
    if className.contains("PanelToggle") || className.contains("SidebarToggle") ||
       className.contains("ColumnToggle") {
        view.backgroundColor = .clear
        view.layer.backgroundColor = UIColor.clear.cgColor
        view.tintColor = purple
        // Hide every background-looking child
        for child in view.subviews { hideBackground(child, purple: purple) }
    }

    // Also catch the standard UIButton that wraps it
    if let btn = view as? UIButton {
        let img = btn.image(for: .normal)
        let isSidebarIcon = img?.accessibilityIdentifier?.contains("sidebar") == true ||
            className.contains("PanelToggle") || className.contains("ColumnToggle")
        if isSidebarIcon {
            btn.backgroundColor = .clear
            btn.layer.backgroundColor = UIColor.clear.cgColor
            btn.tintColor = purple
            btn.subviews.forEach { hideBackground($0, purple: purple) }
        }
    }

    view.subviews.forEach { walkAndPatch(view: $0, purple: purple) }
}

private func hideBackground(_ view: UIView, purple: UIColor) {
    let name = NSStringFromClass(type(of: view))
    if view is UIVisualEffectView ||
       name.contains("Background") ||
       name.contains("Backdrop") ||
       name.contains("Material") ||
       name.contains("Capsule") ||
       name.contains("Highlight") ||
       name.contains("Shadow") {
        view.isHidden = true
        view.alpha = 0
        view.layer.backgroundColor = UIColor.clear.cgColor
    }
    // Recurse into children too
    view.subviews.forEach { hideBackground($0, purple: purple) }
}
