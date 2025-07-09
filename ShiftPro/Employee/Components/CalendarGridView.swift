//
//  CalendarGridView.swift
//  ShiftPro
//
//  Created by Doris Wen on 2025/7/8.
//

import SwiftUI

struct CalendarGridView: View {
    @ObservedObject var viewModel: CalendarViewModel
    let monthOffset: Int
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(viewModel.getDaysForOffset(monthOffset)) { day in
                calendarCell(for: day)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
    }

    @ViewBuilder
    func calendarCell(for day: CalendarDay) -> some View {
        let dayNumber = Calendar.current.component(.day, from: day.date)
        let isSelected = monthOffset == 0 && viewModel.isSameDayInCurrentMonth(day.date)
        let isInMonth = day.isWithinDisplayedMonth

        Text("\(dayNumber)")
            .font(.system(size: 18, weight: .medium))
            .frame(maxWidth: .infinity, minHeight: 80)
            .background(
                isSelected ?
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white.opacity(0.9)) :
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.clear)
            )
            .foregroundColor(
                isSelected ? .black : (isInMonth ? .white : .gray.opacity(0.5))
            )
            .onTapGesture {
                // Allow selection of dates from any visible month
                if isInMonth {
                    viewModel.selectedDate = day.date
                    // Update current month if selecting from a different month
                    if monthOffset != 0 {
                        viewModel.currentMonth = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: day.date)) ?? viewModel.currentMonth
                    }
                }
            }
    }
}

#Preview {
    CalendarGridView(viewModel: CalendarViewModel(), monthOffset: 0)
}
