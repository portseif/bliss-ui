//
//  SelectionBar.swift
//  BlissUI
//
//  The bulk-action bar that appears while rows are selected: "3 selected", a
//  tight cluster of neutral ghost actions, a divider, and a clear button. No
//  accent on the bar — it's chrome, not content. It floats as an island at
//  the bottom center, or docks flush under the table.
//

import SwiftUI

/// Where a `SelectionBar` sits.
public nonisolated enum SelectionBarPlacement: Sendable {
    /// A capsule island floating over the content, with the panel shadow.
    case floating
    /// A flush strip with a hairline on top — docked under a table.
    case attached
}

/// A bar of bulk actions for the current selection.
///
/// Usually shown with `.selectionBar(count:onClear:actions:)`, which floats it
/// at the bottom center, slides it in and out, and lifts toasts above it.
public struct SelectionBar<Actions: View>: View {
    private let count: Int
    private let total: Int?
    private let placement: SelectionBarPlacement
    private let onClear: () -> Void
    private let onSelectAll: (() -> Void)?
    private let actions: Actions

    /// - Parameters:
    ///   - count: How many rows are selected.
    ///   - total: How many there are in all; shown as "3 of 120 selected".
    ///   - placement: An island floating over the content, or a strip docked under it.
    ///   - onClear: The ✕ that clears the selection.
    ///   - onSelectAll: Shows a "Select all" action beside the count.
    ///   - actions: `SelectionBarButton`s.
    public init(
        count: Int,
        total: Int? = nil,
        placement: SelectionBarPlacement = .floating,
        onClear: @escaping () -> Void,
        onSelectAll: (() -> Void)? = nil,
        @ViewBuilder actions: () -> Actions
    ) {
        self.count = count
        self.total = total
        self.placement = placement
        self.onClear = onClear
        self.onSelectAll = onSelectAll
        self.actions = actions()
    }

    public var body: some View {
        switch placement {
        case .floating:
            bar
                // Hugs its contents instead of stretching.
                .fixedSize(horizontal: true, vertical: false)
                .background {
                    Capsule(style: .continuous)
                        .fill(Color.controlBackground)
                }
                .overlay {
                    Capsule(style: .continuous)
                        .strokeBorder(Color.menuBorder, lineWidth: 1)
                }
                .clipShape(Capsule(style: .continuous))
                .elevation(.panel)
        case .attached:
            bar
                .frame(maxWidth: .infinity)
                .background(Color.windowBackground)
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(Color.menuBorder)
                        .frame(height: 1)
                }
        }
    }

    private var bar: some View {
        HStack(spacing: Spacing.sm) {
            countLabel
                .font(Typography.labelMedium)
                .foregroundStyle(.primary)
                .monospacedDigit()
                .contentTransition(.numericText())

            if let onSelectAll {
                Button(action: onSelectAll) {
                    Text("Select all", bundle: .module)
                }
                .buttonStyle(GhostButtonStyle(compact: true))
            }

            Spacer(minLength: Spacing.xl)

            // Tight spacing for a segmented feel.
            HStack(spacing: Spacing.hairline) {
                actions
            }

            Divider()
                .frame(height: Sizing.iconDefault)
                .padding(.horizontal, Spacing.xs)

            SelectionBarClearButton(action: onClear)
        }
        .padding(.leading, Spacing.lg)
        .padding(.trailing, Spacing.sm)
        .padding(.vertical, Spacing.sm)
    }

    private var countLabel: Text {
        if let total {
            return Text("\(count) of \(total) selected", bundle: .module)
        }
        return Text("\(count) selected", bundle: .module)
    }
}

/// A neutral ghost action for a `SelectionBar`: icon + label on the compact
/// ghost button, and an optional chevron for a menu trigger. `isDestructive`
/// paints the label red (Delete); the hover fill stays neutral.
public struct SelectionBarButton: View {
    private let title: LocalizedStringKey
    private let systemImage: String
    private let showsChevron: Bool
    private let isDestructive: Bool
    private let action: () -> Void

    public init(
        _ title: LocalizedStringKey,
        systemImage: String,
        showsChevron: Bool = false,
        isDestructive: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.showsChevron = showsChevron
        self.isDestructive = isDestructive
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.xs) {
                BlissSymbol(systemImage)
                Text(title)
                if showsChevron {
                    BlissSymbol("chevron.down")
                        .font(Typography.captionTiny)
                        .foregroundStyle(.tertiary)
                }
            }
            .foregroundStyle(isDestructive ? AnyShapeStyle(Danger.danger500) : AnyShapeStyle(.primary))
        }
        .buttonStyle(GhostButtonStyle(compact: true))
    }
}

/// The bar's clear affordance — a bare ✕ that gains a circular hover chip.
private struct SelectionBarClearButton: View {
    let action: () -> Void

    @Environment(\.colorScheme) private var scheme
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            BlissSymbol("xmark")
                .font(Typography.labelTinySemibold)
                .foregroundStyle(isHovering ? Color.textPrimary : Color.textSecondary)
                .frame(width: Sizing.controlSmall, height: Sizing.controlSmall)
                .background {
                    Circle().fill(isHovering ? RowTint.hover(scheme) : Color.clear)
                }
                .contentShape(Circle())
        }
        .buttonStyle(FocusablePlainButtonStyle(cornerRadius: Sizing.radiusFull))
        .accessibilityLabel(Text("Clear selection", bundle: .module))
        .onHover { hovering in
            withAnimation(Animations.hover) { isHovering = hovering }
        }
    }
}

// MARK: - Presentation

private struct SelectionBarModifier<Actions: View>: ViewModifier {
    let count: Int
    let total: Int?
    let placement: SelectionBarPlacement
    let bottomPadding: CGFloat
    let onClear: () -> Void
    let onSelectAll: (() -> Void)?
    @ViewBuilder let actions: () -> Actions

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottom) {
                if count > 0 {
                    SelectionBar(count: count, total: total, placement: placement, onClear: onClear, onSelectAll: onSelectAll, actions: actions)
                        // Toasts rest at the same bottom-center spot; this lifts them clear.
                        .toastsRestAbove()
                        .padding(.bottom, placement == .floating ? bottomPadding : 0)
                        .transition(.motion(.move(edge: .bottom).combined(with: .opacity)))
                }
            }
            .animation(Animations.selection, value: count > 0)
    }
}

extension View {
    /// Shows a `SelectionBar` at the bottom while `count` is above zero,
    /// sliding it in and out (a fade under Reduce Motion). Floating, it rests
    /// `bottomPadding` up from the edge — the same gap toasts keep — and toasts
    /// lift to rest above it; attached, it docks flush to the bottom edge.
    public func selectionBar<Actions: View>(
        count: Int,
        total: Int? = nil,
        placement: SelectionBarPlacement = .floating,
        bottomPadding: CGFloat = Spacing.xl,
        onClear: @escaping () -> Void,
        onSelectAll: (() -> Void)? = nil,
        @ViewBuilder actions: @escaping () -> Actions
    ) -> some View {
        modifier(SelectionBarModifier(
            count: count,
            total: total,
            placement: placement,
            bottomPadding: bottomPadding,
            onClear: onClear,
            onSelectAll: onSelectAll,
            actions: actions
        ))
    }
}

// MARK: - Preview

#Preview(traits: .fixedLayout(width: 560, height: 240)) {
    VStack(spacing: 0) {
        Color.clear
            .selectionBar(count: 3, total: 120, onClear: {}, onSelectAll: {}) {
                SelectionBarButton("Open", systemImage: "arrow.up.forward.app") {}
                SelectionBarButton("Archive", systemImage: "archivebox") {}
                SelectionBarButton("Delete", systemImage: "trash", isDestructive: true) {}
            }
        Color.clear
            .selectionBar(count: 2, placement: .attached, onClear: {}) {
                SelectionBarButton("Actions", systemImage: "ellipsis.circle", showsChevron: true) {}
            }
    }
}
