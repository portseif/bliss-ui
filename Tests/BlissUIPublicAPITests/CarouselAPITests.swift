import SwiftUI
import Testing
import BlissUI

/// Compiles only against BlissUI's public API: the carousel and its page
/// control, built the way an app would build them.
@MainActor
@Suite struct CarouselAPITests {
    private struct Slide: Identifiable {
        let id: Int
        let title: String
    }

    @Test func carouselIsReachable() {
        let slides = [Slide(id: 1, title: "Welcome"), Slide(id: 2, title: "Sync"), Slide(id: 3, title: "Themes")]
        _ = Carousel(slides) { slide in Text(verbatim: slide.title) }
        _ = Carousel(slides, selection: .constant(2), showsArrows: false, showsPageControl: false) { slide in
            Text(verbatim: slide.title)
        }
        _ = Carousel(slides, autoplayInterval: 5) { slide in
            Text(verbatim: slide.title)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(height: 240)
    }

    @Test func pageControlIsReachable() {
        _ = PageControl(count: 5, current: .constant(1))
        _ = PageControl(count: 0, current: .constant(0))
    }
}
