//
//  ControlHeightTests.swift
//  BlissUITests
//
//  The control tiers, measured: a compact button and a single-line field are
//  `Sizing.controlDefault` tall, a regular button and the search field
//  `Sizing.controlMedium`, and the pills share `BadgeSize`'s heights. Padding
//  math drifts; a rendered height doesn't.
//

import AppKit
import SwiftUI
import Testing
@testable import BlissUI

@Suite @MainActor struct ControlHeightTests {
    private func height<V: View>(_ view: V) -> CGFloat {
        let host = NSHostingView(rootView: view.fixedSize())
        host.layoutSubtreeIfNeeded()
        return host.fittingSize.height
    }

    @Test func compactButtonsAreTheDefaultTier() {
        #expect(height(Button("Save") {}.buttonStyle(PrimaryButtonStyle(compact: true))) == Sizing.controlDefault)
        #expect(height(Button("Cancel") {}.buttonStyle(SecondaryButtonStyle(compact: true))) == Sizing.controlDefault)
        #expect(height(Button("Edit") {}.buttonStyle(OutlineButtonStyle(compact: true))) == Sizing.controlDefault)
        #expect(height(Button("More") {}.buttonStyle(GhostButtonStyle(compact: true))) == Sizing.controlDefault)
        #expect(height(Button("Delete") {}.buttonStyle(DestructiveButtonStyle(compact: true))) == Sizing.controlDefault)
        #expect(height(Button { } label: { Image(systemName: "plus") }.buttonStyle(SecondaryButtonStyle(compact: true, iconOnly: true))) == Sizing.controlDefault)
        #expect(height(Button { } label: { Image(systemName: "gear") }.buttonStyle(ToolbarIconButtonStyle())) == Sizing.controlDefault)
    }

    @Test func regularButtonsAreTheMediumTier() {
        #expect(height(Button("Save") {}.buttonStyle(PrimaryButtonStyle())) == Sizing.controlMedium)
        #expect(height(Button("Cancel") {}.buttonStyle(SecondaryButtonStyle())) == Sizing.controlMedium)
        #expect(height(Button("Edit") {}.buttonStyle(OutlineButtonStyle())) == Sizing.controlMedium)
        #expect(height(Button("More") {}.buttonStyle(GhostButtonStyle())) == Sizing.controlMedium)
        #expect(height(Button("Delete") {}.buttonStyle(DestructiveButtonStyle())) == Sizing.controlMedium)
    }

    @Test func singleLineFieldsAreTheDefaultTier() {
        #expect(height(TextField("Name", text: .constant("Bliss")).textFieldStyle(.compact).frame(width: 200)) == Sizing.controlDefault)
        #expect(height(TextField("Search", text: .constant("")).textFieldStyle(.toolbarSearch).frame(width: 200)) == Sizing.controlDefault)
        #expect(height(InputField("Name", text: .constant("Bliss")).frame(width: 200)) == Sizing.controlDefault)
        #expect(height(ComboBox("City", text: .constant("lo"), options: ["London"], title: { $0 }).frame(width: 200)) == Sizing.controlDefault)
        #expect(height(NumberField("Days", value: .constant(30), in: 0...100)) == Sizing.controlDefault)
        #expect(height(SecretField("Key", text: .constant("abc")).frame(width: 200)) == Sizing.controlDefault)
        #expect(height(TokenField("Tags", tokens: .constant(["a"]), title: { $0 }, makeToken: { $0 }).frame(width: 200)) == Sizing.controlDefault)
        #expect(height(ShortcutRecorder(shortcut: .constant(nil))) == Sizing.controlDefault)
        #expect(height(FloatingMenuPicker("Size", selection: .constant("M"), options: ["S", "M"], optionTitle: { $0 })) == Sizing.controlDefault)
        #expect(height(DatePickerField("Date", selection: .constant(Date()))) == Sizing.controlDefault)
        #expect(height(MultiSelectPicker("Teams", selection: .constant(Set(["a"])), options: ["a", "b"], optionTitle: { $0 })) == Sizing.controlDefault)
        #expect(height(FilterMenuButton("Filter", systemImage: "line.3.horizontal.decrease", isActive: true, count: 3) {}) == Sizing.controlDefault)
        #expect(height(Pagination(page: .constant(1), pageCount: 5)) == Sizing.controlDefault)
        #expect(height(Rating("Stars", value: .constant(3))) == Sizing.controlDefault)
        #expect(height(IconPickerButton(selectedIcon: .constant("star"))) == Sizing.controlDefault)
    }

    @Test func regularFieldsAreTheMediumTier() {
        #expect(height(TextField("Name", text: .constant("Bliss")).textFieldStyle(.largePadded).frame(width: 200)) == Sizing.controlMedium)
        #expect(height(TextField("Search", text: .constant("")).textFieldStyle(.search).frame(width: 200)) == Sizing.controlMedium)
        #expect(height(SegmentedPills(options: ["Day", "Week"], selection: .constant("Day"), title: { $0 })) == Sizing.controlMedium)
        #expect(height(SegmentedPills(options: ["Day", "Week"], selection: .constant("Day"), style: .compact, title: { $0 })) == Sizing.controlDefault)
    }

    @Test func pillsShareTheBadgeHeights() {
        #expect(height(Badge("Default").badgeSize(.small)) == BadgeSize.small.minHeight)
        #expect(height(Badge("Default")) == BadgeSize.regular.minHeight)
        #expect(height(Badge("Default").badgeSize(.large)) == BadgeSize.large.minHeight)
        // Every pill defaults to the regular badge.
        #expect(height(StatusPill("Running", isActive: true)) == BadgeSize.regular.minHeight)
        #expect(height(StatusDotPill(label: "Running", color: .green)) == BadgeSize.regular.minHeight)
        #expect(height(Badge.status("Healthy", color: .green)) == BadgeSize.regular.minHeight)
        #expect(height(ShortcutKey("⌘K")) == BadgeSize.regular.minHeight)
        #expect(height(ShortcutKey("⌘K", compact: true)) == BadgeSize.small.minHeight)
        #expect(height(KeyHintPill("esc")) == BadgeSize.regular.minHeight)
    }

    @Test func smallControlsAreTheSmallTier() {
        // The small pill button is the compact tier, for room around its label.
        #expect(height(Button("Tag") {}.buttonStyle(SmallPillButtonStyle(color: .blue))) == Sizing.controlDefault)
        #expect(height(Button { } label: { Image(systemName: "gear") }.buttonStyle(ToolbarIconButtonStyle(compact: true))) == Sizing.controlSmall)
    }
}
