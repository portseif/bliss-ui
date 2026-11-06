import CoreGraphics
import Foundation
import SwiftUI
import Testing
@testable import BlissUI

/// The settings scroll-spy, the option grid's rows and the skeleton sweep's
/// geometry.
@MainActor
@Suite struct FormsTests {
    // MARK: Scroll-spy

    private func frame(minY: CGFloat, height: CGFloat = 200) -> CGRect {
        CGRect(x: 0, y: minY, width: 400, height: height)
    }

    @Test func topmostIsTheLastSectionAboveTheFold() {
        let frames: [AnyHashable: CGRect] = [
            "general": frame(minY: -300),
            "appearance": frame(minY: 40),
            "privacy": frame(minY: 300),
        ]
        #expect(SettingsScrollSpy.topmostSection(in: frames) == AnyHashable("appearance"))
    }

    @Test func topmostFallsBackToTheClosestSectionBelowTheFold() {
        let frames: [AnyHashable: CGRect] = [
            "general": frame(minY: 200),
            "appearance": frame(minY: 450),
        ]
        #expect(SettingsScrollSpy.topmostSection(in: frames) == AnyHashable("general"))
        #expect(SettingsScrollSpy.topmostSection(in: [:]) == nil)
    }

    @Test func bottomLatchNeedsTheFormToHaveScrolled() {
        // Everything fits: the last section is inside the viewport but nothing
        // has scrolled, so the first section stays the active one.
        let shortForm: [AnyHashable: CGRect] = ["general": frame(minY: 0), "privacy": frame(minY: 210)]
        #expect(!SettingsScrollSpy.isAtBottom(wasAtBottom: false, frames: shortForm, lastSection: "privacy", viewportHeight: 600))
    }

    @Test func bottomLatchHasHysteresis() {
        let viewport: CGFloat = 500
        let scrolledToBottom: [AnyHashable: CGRect] = ["general": frame(minY: -400), "privacy": frame(minY: 200, height: 290)]
        #expect(SettingsScrollSpy.isAtBottom(wasAtBottom: false, frames: scrolledToBottom, lastSection: "privacy", viewportHeight: viewport))

        // A little past the bottom edge: keeps whatever it was.
        let nearBottom: [AnyHashable: CGRect] = ["general": frame(minY: -380), "privacy": frame(minY: 220, height: 300)]
        #expect(SettingsScrollSpy.isAtBottom(wasAtBottom: true, frames: nearBottom, lastSection: "privacy", viewportHeight: viewport))
        #expect(!SettingsScrollSpy.isAtBottom(wasAtBottom: false, frames: nearBottom, lastSection: "privacy", viewportHeight: viewport))

        // Well below the viewport again: lets go.
        let scrolledUp: [AnyHashable: CGRect] = ["general": frame(minY: -100), "privacy": frame(minY: 500, height: 300)]
        #expect(!SettingsScrollSpy.isAtBottom(wasAtBottom: true, frames: scrolledUp, lastSection: "privacy", viewportHeight: viewport))
    }

    // MARK: Option grid

    @Test func gridRowsChunkByColumns() {
        #expect(OptionCardGridLayout.rows(count: 5, columns: 2) == [0..<2, 2..<4, 4..<5])
        #expect(OptionCardGridLayout.rows(count: 3, columns: 3) == [0..<3])
        #expect(OptionCardGridLayout.rows(count: 0, columns: 2).isEmpty)
        #expect(OptionCardGridLayout.rows(count: 2, columns: 0) == [0..<1, 1..<2])
    }

    // MARK: Skeleton sweep

    @Test func sweepCrossesTheTravelOncePerPeriod() {
        #expect(SkeletonSweep.bandCenter(at: 0) == -SkeletonSweep.bandWidth)
        let halfway = SkeletonSweep.bandCenter(at: SkeletonSweep.period / 2)
        #expect(abs(halfway - SkeletonSweep.travel / 2) < 0.001)
        // It starts over each period.
        #expect(abs(SkeletonSweep.bandCenter(at: SkeletonSweep.period * 3) - SkeletonSweep.bandCenter(at: 0)) < 0.001)
    }

    @Test func sweepGradientIsPlacedInWindowSpace() {
        // Two blocks side by side see the band at the same window x: the
        // band's start, mapped back out of each block's unit space, matches.
        let center: CGFloat = 300
        let left = SkeletonSweep.gradientPoints(bandCenter: center, minX: 100, width: 200)
        let right = SkeletonSweep.gradientPoints(bandCenter: center, minX: 300, width: 100)
        let leftStartInWindow = 100 + left.start.x * 200
        let rightStartInWindow = 300 + right.start.x * 100
        #expect(abs(leftStartInWindow - rightStartInWindow) < 0.001)
        #expect(abs(leftStartInWindow - (center - SkeletonSweep.bandWidth / 2)) < 0.001)
        // A zero-width view gets a plain gradient instead of dividing by zero.
        #expect(SkeletonSweep.gradientPoints(bandCenter: center, minX: 0, width: 0).start == .leading)
    }

    // MARK: Banner

    @Test func bannerStylesHaveTheirOwnIcons() {
        let icons = Set(BannerStyle.allCases.map(\.defaultIcon))
        #expect(icons.count == BannerStyle.allCases.count)
    }
}
