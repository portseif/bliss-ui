//
//  ControlShapeTests.swift
//  BlissUITests
//
//  The corners each control shape gives: square is sharp, rounded keeps the
//  control's own radius, round is a capsule on a single line and a generous
//  radius on a box.
//

import SwiftUI
import Testing
@testable import BlissUI

struct ControlShapeTests {
    @Test func roundedIsTheDefault() {
        #expect(EnvironmentValues().controlShape == .rounded)
    }

    @Test func singleLineControlsGoSharpOrCapsule() {
        #expect(ControlShape.square.radius(rounded: Sizing.radiusMedium) == 0)
        #expect(ControlShape.rounded.radius(rounded: Sizing.radiusMedium) == Sizing.radiusMedium)
        #expect(ControlShape.round.radius(rounded: Sizing.radiusMedium) == Sizing.radiusFull)
    }

    @Test func boxesNeverBecomeCapsules() {
        #expect(ControlShape.square.boxRadius(rounded: Sizing.textBoxCornerRadius) == 0)
        #expect(ControlShape.rounded.boxRadius(rounded: Sizing.textBoxCornerRadius) == Sizing.textBoxCornerRadius)
        #expect(ControlShape.round.boxRadius(rounded: Sizing.textBoxCornerRadius) == Sizing.radiusXLarge)
    }
}
