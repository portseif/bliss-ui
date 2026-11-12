//
//  DockIcon.swift
//  BlissUI
//
//  Alternate Dock icons: the app lists its options, `AppearanceSettings` shows
//  them, and the pick is kept under `BlissAppearance.Keys.dockIcon`. The Dock
//  shows it while the app runs; macOS shows the bundle's icon otherwise.
//

import AppKit
import SwiftUI

/// One Dock icon the user can pick.
public struct DockIconOption: Identifiable, Hashable {
    public let id: String
    /// What VoiceOver and the tooltip call it.
    public let name: String
    /// The icon; nil is the app's own (bundle) icon.
    public let image: NSImage?

    public init(id: String, name: String, image: NSImage?) {
        self.id = id
        self.name = name
        self.image = image
    }

    /// The app's own icon, as the first option; `name` defaults to "Default".
    public static func appIcon(name: String? = nil) -> DockIconOption {
        DockIconOption(id: "app", name: name ?? String(localized: "Default", bundle: .module), image: nil)
    }

    /// What the option looks like: its image, or the app's icon.
    var displayImage: NSImage {
        image ?? NSImage(named: NSImage.applicationIconName) ?? NSImage()
    }

    public static func == (lhs: DockIconOption, rhs: DockIconOption) -> Bool { lhs.id == rhs.id }
    public func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

extension BlissAppearance {
    /// The picked Dock icon's id; nil for the app's own.
    public static var dockIconID: String? {
        get { UserDefaults.standard.string(forKey: Keys.dockIcon) }
        set { UserDefaults.standard.set(newValue, forKey: Keys.dockIcon) }
    }

    /// Shows the picked icon in the Dock, or the app's own when none (or one
    /// no longer offered) is picked. Call it at launch with the same options
    /// the settings page shows.
    public static func applyDockIcon(from options: [DockIconOption]) {
        let picked = options.first { $0.id == dockIconID }
        // `applicationIconImage` is null-resettable: nil restores the bundle icon.
        NSApp?.applicationIconImage = picked?.image
    }
}

/// The Dock icon row's tiles: each option's icon, ringed in the accent when picked.
struct DockIconPicker: View {
    let options: [DockIconOption]
    @Binding var selection: String

    var body: some View {
        HStack(spacing: Spacing.sm) {
            ForEach(options) { option in
                DockIconTile(option: option, isSelected: option.id == selection) {
                    withAnimation(Animations.selection) { selection = option.id }
                }
            }
        }
    }
}

private struct DockIconTile: View {
    let option: DockIconOption
    let isSelected: Bool
    let onSelect: () -> Void

    @State private var isHovering = false
    @Environment(\.colorScheme) private var colorScheme

    private static let size: CGFloat = 40
    private static let cornerRadius: CGFloat = Sizing.radiusMedium

    var body: some View {
        Button(action: onSelect) {
            Image(nsImage: option.displayImage)
                .resizable()
                .interpolation(.high)
                .frame(width: Self.size, height: Self.size)
                .padding(4)
                .background {
                    RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous)
                        .fill(isHovering && !isSelected ? RowTint.hover(colorScheme) : Color.clear)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous)
                        .strokeBorder(isSelected ? Color.accent : Color.clear, lineWidth: 2)
                }
                .contentShape(RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous))
        }
        .buttonStyle(FocusablePlainButtonStyle(cornerRadius: Self.cornerRadius))
        .onHover { isHovering = $0 }
        .animation(Animations.hover, value: isHovering)
        .tooltip(.verbatim(option.name), position: .below)
        .accessibilityLabel(Text(verbatim: option.name))
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

#Preview("Dock icons", traits: .fixedLayout(width: 200, height: 80)) {
    @Previewable @State var selection = "app"
    DockIconPicker(options: [.appIcon(), DockIconOption(id: "alt", name: "Alternate", image: NSImage(systemSymbolName: "star.fill", accessibilityDescription: nil))], selection: $selection)
        .padding()
        .blissTheme()
}
