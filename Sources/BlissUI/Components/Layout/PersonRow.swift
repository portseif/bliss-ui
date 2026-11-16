//
//  PersonRow.swift
//  BlissUI
//
//  A person in a list: their avatar, their name over a detail line, and a
//  trailing slot (a badge, a role, a button). It draws no hover of its own —
//  put it in a list row or a table cell.
//

import SwiftUI

/// Avatar + name + detail, with a trailing slot.
///
/// ```swift
/// PersonRow(name: "Ada Lovelace", detail: "ada@example.com", status: .online) {
///     Badge("Owner").badgeSize(.small)
/// }
/// PersonRow(name: "Design Team", image: teamLogo, size: .large, shape: .rounded)
/// ```
public struct PersonRow<Trailing: View>: View {
    private let name: String
    private let detail: String?
    private let image: Image?
    private let size: AvatarSize
    private let shape: AvatarShape
    private let status: AvatarStatus?
    private let trailing: Trailing

    /// - Parameters:
    ///   - name: The person's name — the avatar's initials and color come from
    ///     it. Shown as-is, never looked up as a string key.
    ///   - detail: A line under the name (an email, a role, "Last seen…").
    ///   - image: Their picture; nil shows the initials.
    ///   - size: The avatar's size. At `.large` and up the text steps up a
    ///     size with it, so a profile header isn't list-row text beside a big avatar.
    ///   - shape: The avatar's outline — a rounded square for a team or a workspace.
    ///   - status: A presence dot on the avatar.
    ///   - trailing: What sits at the trailing edge.
    public init(
        name: String,
        detail: String? = nil,
        image: Image? = nil,
        size: AvatarSize = .medium,
        shape: AvatarShape = .circle,
        status: AvatarStatus? = nil,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.name = name
        self.detail = detail
        self.image = image
        self.size = size
        self.shape = shape
        self.status = status
        self.trailing = trailing()
    }

    /// A row's text follows its avatar: list-row text up to `.medium`, a
    /// step up from `.large`.
    private var isLarge: Bool {
        size == .large || size == .xlarge
    }

    public var body: some View {
        HStack(spacing: Spacing.sm) {
            Avatar(name: name, image: image, size: size, shape: shape, status: status)
                // The name is visible beside it; the status is said below.
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: Spacing.hairline) {
                Text(verbatim: name)
                    .font(isLarge ? Typography.bodyMedium : Typography.bodySmall)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                if let detail {
                    Text(verbatim: detail)
                        .font(isLarge ? Typography.caption : Typography.captionSmall)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: Spacing.sm)

            trailing
        }
        .accessibilityElement(children: .combine)
        .accessibilityValue(status?.label ?? Text(verbatim: ""))
    }
}

extension PersonRow where Trailing == EmptyView {
    /// A person row with nothing trailing.
    public init(
        name: String,
        detail: String? = nil,
        image: Image? = nil,
        size: AvatarSize = .medium,
        shape: AvatarShape = .circle,
        status: AvatarStatus? = nil
    ) {
        self.init(name: name, detail: detail, image: image, size: size, shape: shape, status: status, trailing: { EmptyView() })
    }
}

// MARK: - Preview

#Preview("Person rows", traits: .fixedLayout(width: 420, height: 200)) {
    VStack(alignment: .leading, spacing: Spacing.md) {
        PersonRow(name: "Ada Lovelace", detail: "ada@example.com", status: .online) {
            Badge("Owner").badgeStyle(.primary).badgeSize(.small)
        }
        PersonRow(name: "Grace Hopper", detail: "Reviewer", status: .away)
        PersonRow(name: "Alan Turing", detail: "Invited", size: .large) {
            Text(verbatim: "Invited")
                .font(Typography.captionSmall)
                .foregroundStyle(.secondary)
        }
        PersonRow(name: "Design Team", detail: "4 members", size: .large, shape: .rounded)
    }
    .padding(Spacing.xl)
}
