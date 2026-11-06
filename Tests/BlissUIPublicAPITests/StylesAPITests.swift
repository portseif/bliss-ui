import SwiftUI
import Testing
import BlissUI

/// Compiles only against BlissUI's public API: every style, modifier and service
/// in Themes/Styles, Effects and the focus / shortcut-hint services, used the
/// way an app would.
@MainActor
@Suite struct StylesAPITests {
    @Test func buttonStylesAreReachable() {
        _ = Button("Save") {}.buttonStyle(PrimaryButtonStyle())
        _ = Button("Save") {}.buttonStyle(PrimaryButtonStyle(compact: true, cornerRadiusOverride: Sizing.radiusSmall))
        _ = Button("New") {}.buttonStyle(OutlineButtonStyle(compact: true, cornerRadiusOverride: 4))
        _ = Button("Cancel") {}.buttonStyle(SecondaryButtonStyle())
        _ = Button("Connect") {}.buttonStyle(SecondaryButtonStyle(compact: true, iconOnly: false, accent: true, cornerRadiusOverride: nil))
        _ = Button("Skip") {}.buttonStyle(GhostButtonStyle(compact: true, hugsLabel: true))
        _ = Button("Remove") {}.buttonStyle(DestructiveButtonStyle())
        _ = Button("Delete") {}.buttonStyle(DestructiveButtonStyle(compact: true, prominent: true))
        _ = Button("Upgrade") {}.buttonStyle(SmallPillButtonStyle(color: Warning.warning500))
        _ = Button("Info") {}.buttonStyle(
            ToolbarIconButtonStyle(isActive: true, extraLeadingPadding: 2, extraTrailingPadding: 2, fill: .primary, compact: true)
        )
        _ = Button("Row") {}.buttonStyle(FocusablePlainButtonStyle(cornerRadius: Sizing.radiusSmall, outset: 3, bleed: Spacing.sm))
        _ = Button("Card") {}.buttonStyle(SelectableCardButtonStyle(cornerRadius: Sizing.radiusFull))
        _ = Button("Copy") {}.buttonStyle(InlineIconButtonStyle(chipRadius: Sizing.radiusSmall))
        _ = Button("New") {}.buttonStyle(AnimatedGradientBorderButtonStyle())
        _ = Button("New") {}.buttonStyle(AnimatedGradientBorderButtonStyle(compact: true))
        _ = Button("New") {}.buttonStyle(AnimatedGradientBorderButtonStyle(size: .mini))
        let sizes: [AnimatedGradientBorderButtonStyle.Size] = [.regular, .compact, .mini]
        #expect(sizes.count == 3)
    }

    @Test func toggleStylesAreReachable() {
        _ = Toggle("On", isOn: .constant(true)).toggleStyle(.flatSwitch)
        _ = Toggle("On", isOn: .constant(true)).toggleStyle(.flatSwitch(showsLabel: true))
        _ = Toggle("On", isOn: .constant(false)).toggleStyle(FlatSwitchToggleStyle(showsLabel: false))
    }

    @Test func textFieldStylesAreReachable() {
        _ = TextField("Name", text: .constant("")).textFieldStyle(.largePadded)
        _ = TextField("Name", text: .constant("")).textFieldStyle(.compact)
        _ = TextField("Search", text: .constant("")).textFieldStyle(.search)
        _ = TextField("Search", text: .constant("")).textFieldStyle(.toolbarSearch)
        _ = TextField("Name", text: .constant("")).textFieldStyle(LargePaddedTextFieldStyle())
        _ = TextField("Name", text: .constant("")).textFieldStyle(CompactTextFieldStyle())
        _ = TextField("Search", text: .constant("")).textFieldStyle(SearchTextFieldStyle())
        _ = TextField("Search", text: .constant("")).textFieldStyle(ToolbarSearchTextFieldStyle())
    }

    @Test func formModifiersAndViewsAreReachable() {
        _ = Color.clear
            .focusRing(isFocused: true)
            .focusRing(isFocused: true, cornerRadius: Sizing.radiusMedium, color: .red, lineWidth: 2, padding: -2, showsOnPointerFocus: true)
            .focusRingCapsule(isFocused: true, color: .blue, lineWidth: 1, padding: 0, showsOnPointerFocus: true)
            .bottomBorder()
            .bottomBorder(color: .gray, height: 2)
            .inputBox(isFocused: false)
            .inputBox(isFocused: true, cornerRadius: Sizing.radiusLarge)
            .emptyState(isEmpty: true, icon: "tray", title: "Nothing here", description: "Add an item to get started")
            .clearFocusOnBackgroundTap()

        _ = SettingsForm {
            Text("Row")
        }
        .environment(\.settingsFormPlain, true)
        #expect(EnvironmentValues().settingsFormPlain == false)
    }

    @Test func linksAreReachable() {
        _ = TextLink("example.com") {}
        _ = TextLink("example.com/docs", font: Typography.code, truncationMode: .middle, hoverSymbol: "arrow.up.right") {}
        _ = Text("example.com").linkCursor()
    }

    @Test func effectsAreReachable() {
        _ = Color.clear
            .glassBorder()
            .glassBorder(cornerRadius: 20, lineWidth: 2, opacity: 0.5)
            .dimmedOverlay(isPresented: true) { Text("Loading") }
            .dimmedOverlay(isPresented: false, dimOpacity: 0.5) { Text("Loading") }
        _ = Text("Scanning").shimmer()
        _ = Text("Scanning").shimmer(baseColor: .gray, shimmerColor: .white, duration: 2)
        _ = ShimmerTextOverlay(text: "Scanning")
        _ = ShimmerTextOverlay(text: "Scanning", font: .caption, baseColor: .gray, shimmerColor: .white, duration: 1.5, shimmerWidth: 0.4)
    }

    @Test func focusVisibilityServiceIsReachable() {
        let service = FocusVisibilityService.shared
        // Referenced, not called: it installs an app-wide event monitor.
        _ = service.startIfNeeded
        service.noteKeyboardInput()
        #expect(service.showsFocusRings)
        service.notePointerInput()
        #expect(!service.showsFocusRings)
    }

    @Test func shortcutHintServiceIsReachable() {
        let service = ShortcutHintService.shared
        // Referenced, not called: it installs an app-wide event monitor.
        _ = service.startIfNeeded
        service.isSuppressed = { false }
        service.controlKeyIsReserved = { false }
        #expect(!service.isShowingHints)
        #expect(!service.isSuppressed())
        #expect(ShortcutHintService.revealDelay > 0)
    }
}
