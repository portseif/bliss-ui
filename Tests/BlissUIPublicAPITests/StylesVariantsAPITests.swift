import SwiftUI
import Testing
import BlissUI

/// Compiles only against BlissUI's public API: the variant parameters the
/// button, toggle and link styles gained in the consistency pass, used the way
/// an app would.
@MainActor
@Suite struct StylesVariantsAPITests {
    @Test func textButtonVariantsAreReachable() {
        _ = Button { } label: { Image(systemName: "plus") }
            .buttonStyle(PrimaryButtonStyle(compact: true, iconOnly: true))
        _ = Button("Continue") {}.buttonStyle(PrimaryButtonStyle(fullWidth: true, cornerRadiusOverride: Sizing.radiusLarge))
        _ = Button { } label: { Image(systemName: "plus") }
            .buttonStyle(OutlineButtonStyle(iconOnly: true))
        _ = Button("New") {}.buttonStyle(OutlineButtonStyle(compact: false, iconOnly: false, fullWidth: true, cornerRadiusOverride: nil))
        _ = Button("Cancel") {}.buttonStyle(SecondaryButtonStyle(fullWidth: true))
        _ = Button("Connect") {}.buttonStyle(SecondaryButtonStyle(compact: true, iconOnly: false, accent: true, fullWidth: false, cornerRadiusOverride: Sizing.radiusSmall))
        _ = Button { } label: { Image(systemName: "ellipsis") }
            .buttonStyle(GhostButtonStyle(compact: true, iconOnly: true))
        _ = Button("Back") {}.buttonStyle(GhostButtonStyle(hugsLabel: true, cornerRadiusOverride: Sizing.radiusSmall))
        _ = Button { } label: { Image(systemName: "trash") }
            .buttonStyle(DestructiveButtonStyle(compact: true, iconOnly: true))
        _ = Button("Delete") {}.buttonStyle(DestructiveButtonStyle(prominent: true, cornerRadiusOverride: Sizing.radiusFull))
        _ = Button("Delete") {}.buttonStyle(DestructiveButtonStyle(compact: true, prominent: true))
    }

    @Test func pillIconAndCardVariantsAreReachable() {
        _ = Button("Open") {}.buttonStyle(SmallPillButtonStyle(isSelected: true))
        _ = Button("Open") {}.buttonStyle(SmallPillButtonStyle(color: Success.success500, isSelected: false, compact: true))
        _ = Button { } label: { Image(systemName: "stop.fill") }
            .buttonStyle(ToolbarIconButtonStyle(tint: Danger.danger500))
        _ = Button { } label: { Image(systemName: "play.fill") }
            .buttonStyle(ToolbarIconButtonStyle(isActive: true, fill: nil, tint: Success.success500, compact: true))
        _ = Button("Card") {}.buttonStyle(SelectableCardButtonStyle(cornerRadius: Sizing.radiusLarge, isSelected: true))
        _ = Button("Card") {}.buttonStyle(SelectableCardButtonStyle(isSelected: false))
        _ = Button { } label: { Image(systemName: "plus") }
            .buttonStyle(AnimatedGradientBorderButtonStyle(iconOnly: true))
        _ = Button { } label: { Image(systemName: "plus") }
            .buttonStyle(AnimatedGradientBorderButtonStyle(size: .mini, iconOnly: true))
        _ = Button("New") {}
            .buttonStyle(AnimatedGradientBorderButtonStyle(compact: true))
            .buttonLoading(true)
    }

    @Test func switchVariantsAreReachable() {
        _ = Toggle("Danger zone", isOn: .constant(true))
            .toggleStyle(FlatSwitchToggleStyle(showsLabel: true, tint: Danger.danger500, labelPlacement: .trailing))
        _ = Toggle("On", isOn: .constant(true))
            .toggleStyle(.flatSwitch(showsLabel: true, tint: nil, labelPlacement: .leading))
        _ = Toggle("On", isOn: .constant(true))
            .toggleStyle(.flatSwitch(showsLabel: true))
        let placements: [FlatSwitchLabelPlacement] = [.leading, .trailing]
        #expect(placements.count == 2)
    }

    @Test func checkboxStyleIsReachable() {
        _ = Toggle("I agree", isOn: .constant(false)).toggleStyle(.flatCheckbox)
        _ = Toggle("Tinted", isOn: .constant(true)).toggleStyle(.flatCheckbox(tint: Success.success500))
        _ = Toggle("Styled", isOn: .constant(true)).toggleStyle(FlatCheckboxToggleStyle(tint: nil))
    }

    @Test func textLinkVariantsAreReachable() {
        _ = TextLink("Read the notes", tone: .primary, showsUnderline: false) {}
        _ = TextLink("example.com", font: Typography.codeSmall, truncationMode: .middle, hoverSymbol: "arrow.up.right", tone: .dimmed, showsUnderline: true) {}
        let tones: [TextLinkTone] = [.dimmed, .primary]
        #expect(tones.count == 2)
    }
}
