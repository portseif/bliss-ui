//
//  SelectionBar.swift
//  BlissUI
//
//  The floating bulk-action island that rises from the bottom while rows are
//  selected: "3 selected", a tight cluster of neutral ghost actions, a divider,
//  and a clear button. No accent on the bar — it's chrome, not content.
//

import SwiftUI

/// A pill-shaped bar of bulk actions for the current selection.
///
/// Usually shown with `.selectionBar(count:onClear:actions:)`, which floats it
/// at the bottom center, slides it in and out, and lifts toasts above it.
public struct SelectionBar<Actions: View>: View {
    private let count: Int
    private let onClear: () -> Void
    private let actions: Actions

    public init(count: Int, onClear: @escaping () -> Void, @ViewBuilder actions: () -> Actions) {
        self.count = count
        self.onClear = onClear
        self.actions = actions()
    }

    /// The themed raised surface under a color theme; the vibrant material
    /// for System.
    private var islandSurface: AnyShapeStyle {
        ThemeColors.activePalette != nil
            ? AnyShapeStyle(Color.controlBackground)
            : AnyShapeStyle(.regularMaterial)
    }

    public var body: some View {
        HStack(spacing: Spacing.sm) {
            Text("\(count) selected")
                .font(Typography.labelMedium)
                .foregroundStyle(.primary)
                .monospacedDigit()
                .contentTransition(.numericText())

            Spacer(minLength: Spacing.xl)

            // Tight spacing for a segmented feel.
            HStack(spacing: 2) {
                actions
            }

            Divider()
                .frame(height: 18)
                .padding(.horizontal, Spacing.xs)

            SelectionBarClearButton(action: onClear)
        }
        // Hugs its contents instead of stretching.
        .fixedSize(horizontal: true, vertical: false)
        .padding(.leading, Spacing.lg)
        .padding(.trailing, Spacing.sm)
        .padding(.vertical, Spacing.sm)
        .background {
            RoundedRectangle(cornerRadius: Sizing.radiusFull, style: .continuous)
                .fill(islandSurface)
        }
        .overlay {
            RoundedRectangle(cornerRadius: Sizing.radiusFull, style: .continuous)
                .strokeBorder(Color.menuBorder, lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: Sizing.radiusFull, style: .continuous))
        .shadow(color: Color.black.opacity(0.22), radius: 18, x: 0, y: 6)
    }
}

/// A neutral ghost action for a `SelectionBar`: icon + label, a subtle hover
/// fill, and an optional chevron for a menu trigger. The label lifts from
/// secondary to primary on hover (Finder/Linear-style).
public struct SelectionBarButton: View {
    private let title: LocalizedStringKey
    private let systemImage: String
    private let showsChevron: Bool
    private let action: () -> Void

    @Environment(\.colorScheme) private var scheme
    @State private var isHovering = false

    public init(
        _ title: LocalizedStringKey,
        systemImage: String,
        showsChevron: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.showsChevron = showsChevron
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.xs) {
                Image(systemName: systemImage)
                Text(title)
                if showsChevron {
                    Image(systemName: "chevron.down")
                        .font(Typography.captionTiny)
                        .foregroundStyle(.tertiary)
                }
            }
            .font(Typography.labelSmall)
            .foregroundStyle(isHovering ? Color.primary : Color.secondary)
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.xs)
            .background {
                RoundedRectangle(cornerRadius: Sizing.radiusDefault, style: .continuous)
                    .fill(isHovering ? RowTint.hover(scheme) : Color.clear)
            }
            .contentShape(RoundedRectangle(cornerRadius: Sizing.radiusDefault, style: .continuous))
        }
        .buttonStyle(FocusablePlainButtonStyle(cornerRadius: Sizing.radiusDefault))
        .onHover { isHovering = $0 }
    }
}

/// The bar's clear affordance — a bare ✕ that gains a circular hover chip.
private struct SelectionBarClearButton: View {
    let action: () -> Void

    @Environment(\.colorScheme) private var scheme
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .font(Typography.labelSmallBold)
                .foregroundStyle(isHovering ? Color.primary : Color.secondary)
                .frame(width: 24, height: 24)
                .background {
                    Circle().fill(isHovering ? RowTint.hover(scheme) : Color.clear)
                }
                .contentShape(Circle())
        }
        .buttonStyle(FocusablePlainButtonStyle(cornerRadius: 12))
        .accessibilityLabel(Text("Clear selection"))
        .onHover { isHovering = $0 }
    }
}

// MARK: - Presentation

private struct SelectionBarModifier<Actions: View>: ViewModifier {
    let count: Int
    let bottomPadding: CGFloat
    let onClear: () -> Void
    @ViewBuilder let actions: () -> Actions

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottom) {
                if count > 0 {
                    SelectionBar(count: count, onClear: onClear, actions: actions)
                        // Toasts rest at the same bottom-center spot; this lifts them clear.
                        .toastsRestAbove()
                        .padding(.bottom, bottomPadding)
                        .transition(.motion(.move(edge: .bottom).combined(with: .opacity)))
                }
            }
            .animation(Animations.selection, value: count > 0)
    }
}

extension View {
    /// Floats a `SelectionBar` at the bottom center while `count` is above
    /// zero, sliding it in and out (a fade under Reduce Motion). Toasts lift
    /// to rest above it.
    public func selectionBar<Actions: View>(
        count: Int,
        bottomPadding: CGFloat = Spacing.lg,
        onClear: @escaping () -> Void,
        @ViewBuilder actions: @escaping () -> Actions
    ) -> some View {
        modifier(SelectionBarModifier(count: count, bottomPadding: bottomPadding, onClear: onClear, actions: actions))
    }
}

// MARK: - Preview

#Preview(traits: .fixedLayout(width: 520, height: 140)) {
    Color.clear
        .selectionBar(count: 3, onClear: {}) {
            SelectionBarButton("Open", systemImage: "arrow.up.forward.app") {}
            SelectionBarButton("Archive", systemImage: "archivebox") {}
            SelectionBarButton("Actions", systemImage: "ellipsis.circle", showsChevron: true) {}
        }
}
