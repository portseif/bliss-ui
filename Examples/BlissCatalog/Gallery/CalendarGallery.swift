//
//  CalendarGallery.swift
//  BlissCatalog
//
//  The "Calendar & Dates" components in the README index. One `GalleryEntry` per
//  component (or per small group that reads as one picture).
//
//  The pickers' popovers are separate windows, so the index shows each
//  picker's calendar inline next to its closed field.
//

import BlissUI
import SwiftUI

extension Gallery {
    static let calendar: [GalleryEntry] = [
        GalleryEntry("month-calendar", width: 800, height: 420) {
            MonthCalendar(
                selection: .constant(Calendar.current.startOfDay(for: Date())),
                markers: { CalendarSampleEvents.markers(on: $0) },
                legend: CalendarSampleEvents.legend
            ) { day in
                CalendarSampleDayPanel(day: day)
            }
        },
        GalleryEntry("date-picker-field", width: 640, height: 330) {
            HStack(alignment: .top, spacing: Spacing.xl) {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    DatePickerField(selection: .constant(GallerySampleDates.dueDate))
                    DatePickerField(selection: .constant(GallerySampleDates.reminder), showsTime: true)
                    DatePickerField(selection: .constant(nil), placeholder: "No end date")
                }
                .fixedSize()
                MonthCalendar(selection: .constant(GallerySampleDates.dueDate), style: .compact)
            }
        },
        GalleryEntry("date-range-picker-field", width: 640, height: 400) {
            VStack(alignment: .leading, spacing: Spacing.md) {
                DateRangePickerField(selection: .constant(GallerySampleDates.midMonthRange))
                    .fixedSize()
                DateRangeCalendar(selection: .constant(GallerySampleDates.midMonthRange), presets: DateRangePreset.standard + [.lastMonth])
                    .background {
                        RoundedRectangle(cornerRadius: Sizing.radiusLarge, style: .continuous)
                            .strokeBorder(Color.menuBorder, lineWidth: 1)
                    }
            }
        },
    ]
}

/// Fixed-offset sample dates so the pictures read the same every month.
private enum GallerySampleDates {
    private static var today: Date { Calendar.current.startOfDay(for: Date()) }

    static var dueDate: Date { Calendar.current.date(byAdding: .day, value: 3, to: today) ?? today }

    static var reminder: Date {
        Calendar.current.date(bySettingHour: 9, minute: 30, second: 0, of: today) ?? today
    }

    /// The 10th through the 19th of this month: the band wraps a week row,
    /// so its capped ends show.
    static var midMonthRange: ClosedRange<Date> {
        let calendar = Calendar.current
        let firstOfMonth = calendar.dateInterval(of: .month, for: today)?.start ?? today
        let start = calendar.date(byAdding: .day, value: 9, to: firstOfMonth) ?? today
        let end = calendar.date(byAdding: .day, value: 18, to: firstOfMonth) ?? today
        return start...end
    }
}
