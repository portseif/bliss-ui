//
//  Animations.swift
//  BlissUI
//
//  Motion tokens, picked by intent, and the Reduce Motion fallback.
//

import AppKit
import SwiftUI

// MARK: - Shared Animations

/// Centralized motion tokens. Inspired by Emil Kowalski's design-engineering
/// principles: spring physics for almost everything organic, short easeOut
/// curves for cursor-driven micro-interactions, no linear timing on UI
/// (reserved for indeterminate progress only).
///
/// **Naming convention:** semantic, not parametric. Pick by *intent*, not by
/// "what spring values do I want." If you find yourself wanting a one-off
/// `.spring(...)` inline, add it as a token here and reuse it.
///
/// **Spring tuning rules of thumb:**
/// - `dampingFraction`: 0.7 = slight bounce, 0.85 = controlled, 0.95 = no bounce
/// - `response`: 0.2 = snappy, 0.35 = standard, 0.5 = languid
/// - Open / appear: medium damping, lets it settle gracefully
/// - Close / dismiss: high damping, short response — must feel immediate
/// - Hover / focus / press: easeOut at 100–150ms (not spring — cursor-driven)
public enum Animations {
    // MARK: - Disclosure / Container

    /// Disclosure section expand / collapse, accordion rows.
    public static let accordion: Animation = .spring(response: 0.25, dampingFraction: 0.8)

    /// Toggle / option reveal inside forms and wizards — a section of controls
    /// appearing or rearranging in response to a deliberate click (sync option
    /// toggles, onboarding step advance, "Customize" expanders). A hair softer
    /// than `accordion` so grouped content settles rather than snaps.
    public static let disclosure: Animation = .spring(response: 0.3, dampingFraction: 0.8)

    /// Sidebar collapse, panel reveal — pane-level layout changes.
    public static let pane: Animation = .spring(response: 0.3, dampingFraction: 0.85)

    // MARK: - Navigation

    /// Opening a detail page from a list: camera-push-into-card. Medium
    /// response so the morph is perceptible, high damping so it settles
    /// without bounce.
    public static let detailOpen: Animation = .spring(response: 0.32, dampingFraction: 0.85)

    /// Leaving a detail page: collapse-into-thumbnail. Tighter than open —
    /// "fast and out of the way" instead of "lingering". High damping keeps
    /// the morph stable against any in-flight teardown of heavy children.
    public static let detailClose: Animation = .spring(response: 0.26, dampingFraction: 0.92)

    /// Cross-fade between sibling detail pages (a breadcrumb switcher). Stays
    /// inside the detail view, so it's a flat transition rather than a morph.
    public static let detailSwitch: Animation = .easeOut(duration: 0.18)

    // MARK: - Cursor / Micro-Interactions

    /// Hover state, focus ring fade — feels instant without snapping.
    public static let hover: Animation = .easeOut(duration: 0.15)

    /// Press / release feedback. Slightly shorter than `hover` so the
    /// scale-down on press doesn't lag behind the click.
    public static let press: Animation = .easeOut(duration: 0.1)

    /// Selection change inside menus, segmented pickers, tab swaps.
    public static let selection: Animation = .easeOut(duration: 0.18)

    /// Snappy cursor-driven reveal — hover lift on cards, checkbox/row select
    /// toggles. Short response with a touch of underdamping so the change pops
    /// without reading as a layout shift.
    public static let interactionReveal: Animation = .spring(response: 0.2, dampingFraction: 0.7)

    /// Transient state feedback — a copy button flipping to a checkmark and
    /// back, brief confirmation flashes. As quick as `interactionReveal` but
    /// fully settled (no bounce) since the state swap is the message.
    public static let feedback: Animation = .spring(response: 0.2, dampingFraction: 0.8)

    /// Liquid "droplet" reveal — path-hover action buttons springing into a
    /// glass chip (the macOS Tahoe Spotlight feel). A lively spring with a
    /// touch of bounce so the controls pop into being rather than fade in;
    /// buttons stagger ~40ms apart for the cascading liquid look.
    public static let droplet: Animation = .spring(response: 0.34, dampingFraction: 0.66)

    // MARK: - Notification / Overlay

    /// Toast slide-in. Snap-in feel.
    public static let toast: Animation = .spring(response: 0.3, dampingFraction: 0.85)

    /// App sheet present (card, scrim and the backdrop blur).
    public static let sheet: Animation = .spring(response: 0.35, dampingFraction: 0.85)

    /// App sheet dismiss: faster than the entrance and not springy, so a sheet
    /// you're done with gets out of the way (the menus' strong ease-out).
    public static let sheetClose: Animation = .timingCurve(0.23, 1, 0.32, 1, duration: 0.2)

    /// An app sheet reshaping when its content grows / shrinks (auto-height /
    /// tab switches). FULLY damped — a morph is on-screen movement, so it should
    /// read as one surface deliberately reshaping (ease-in-out character): at 0.9
    /// damping a large delta (a 650→300pt tab switch) visibly overshot at the
    /// bottom edge. A spring (not a curve) so rapid tab switches retarget from
    /// current velocity instead of restarting. Pairs with `AppSheetCard`'s blur
    /// mask over the content while the frame morphs.
    public static let sheetMorph: Animation = .spring(response: 0.35, dampingFraction: 1.0)

    /// Subtle dropdown / inline panel — softer than `toast`, gentler entry.
    public static let dropdown: Animation = .spring(response: 0.28, dampingFraction: 0.82)

    /// Panel / overlay DISMISSAL. Exits are faster than entries and never
    /// bounce (Emil Kowalski's asymmetric-timing rule): the user is done with
    /// the element — get it out of the way crisply. Pair with `dropdown` /
    /// `toast` entries.
    public static let exit: Animation = .easeOut(duration: 0.14)

    /// A search field expanding/collapsing — field width + results panel materializing.
    /// Smooth, lightly-damped spring (barely any overshoot) so the grow + drop
    /// reads fluid rather than clunky.
    public static let searchExpand: Animation = .spring(response: 0.34, dampingFraction: 0.9)

    /// A command palette's backdrop (the page's blur + dim) coming and
    /// going. The palette itself appears at once — ⌘K is a keyboard action, used
    /// all day — so only the page behind it eases, and quickly.
    public static let paletteBackdrop: Animation = .easeOut(duration: 0.12)

    // MARK: - Menus / Popovers

    /// A menu appearing (floating menus, fly-out submenus, right-click popups).
    /// Emil Kowalski's strong ease-out, `cubic-bezier(0.23, 1, 0.32, 1)`, over
    /// 180ms: an entering element moves fast at the start, the moment the eye
    /// is on it, and settles without a spring's tail. Inside the 150–250ms
    /// range for dropdowns; menus are opened often, so it stays short.
    public static let menuOpen: Animation = .timingCurve(0.23, 1, 0.32, 1, duration: 0.18)

    /// A menu dismissing. Same curve, faster than `menuOpen` — exits get out of
    /// the way, so switching between sibling fly-outs doesn't leave a lingering
    /// fade of the panel you just left.
    public static let menuClose: Animation = .timingCurve(0.23, 1, 0.32, 1, duration: 0.12)

    // MARK: - Streaming / Reveal

    /// Streamed rows landing (a transcript, a live log). Enter = ease-out so
    /// each row that lands while you're reading feels immediate rather than
    /// laggy; streamed rows are seen many times, so keep it short.
    public static let stream: Animation = .easeOut(duration: 0.2)

    /// A thin scroll indicator showing while you hover or scroll, and hiding
    /// once you stop (`ScrollViewWithThinIndicator`).
    public static let scrollIndicator: Animation = .easeOut(duration: 0.2)

    /// The "answer arrived" moment — the AI-fix proposal + diff cards settling
    /// in. A soft, fully-damped spring so the result lands deliberately. It's an
    /// occasional, meaningful moment, so a touch of settle is welcome.
    public static let reveal: Animation = .spring(response: 0.38, dampingFraction: 0.82)

    // MARK: - Generic Fallback

    /// Use only when no semantic token fits. If you reach for this twice,
    /// add a named token instead.
    public static let standard: Animation = .spring(response: 0.3, dampingFraction: 0.85)
}

// MARK: - Platform & Accessibility

/// Returns true if running on macOS 26 (Tahoe) or later
public var isTahoeOrLater: Bool {
    if #available(macOS 26, *) {
        return true
    }
    return false
}

/// System Settings → Accessibility → Display → Reduce motion. Read where a
/// view scales, slides or loops so it can fall back to a plain fade (menus do
/// the same through `MenuPresentationMotion`). Re-read on every render, so a
/// change applies from the next one.
public var prefersReducedMotion: Bool {
    NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
}

extension AnyTransition {
    /// `transition`, or a plain fade under Reduce Motion.
    public static func motion(_ transition: AnyTransition) -> AnyTransition {
        prefersReducedMotion ? .opacity : transition
    }
}

