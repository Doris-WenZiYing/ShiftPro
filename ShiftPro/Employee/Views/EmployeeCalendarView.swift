//
//  EmployeeCalendarView.swift
//  ShiftPro
//
//  Created by Doris Wen on 2025/7/8.
//

import SwiftUI

struct EmployeeCalendarView: View {
    @ObservedObject var controller: CalendarController = CalendarController(orientation: .vertical)

    var body: some View {
        ZStack {
            // Background and scrollable calendar content
            FullPageScrollCalendarView(controller) { month in
                VStack(spacing: 0) {
                    // Month title
                    monthTitleView(month: month)

                    // Weekday headers
                    weekdayHeadersView()

                    // Calendar grid with rounded background
                    calendarGridView(month: month)

                    Spacer()
                }
            }
            .background(Color.black.ignoresSafeArea())

            // FLOATING: Top buttons overlay
            topButtonsOverlay()

            // FLOATING: Edit button overlay
            editButtonOverlay()
        }
    }

    private func monthTitleView(month: CalendarMonth) -> some View {
        HStack {
            Text(month.monthName)
                .font(.system(size: 34, weight: .bold))
                .foregroundColor(.white)
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 20)
    }

    private func weekdayHeadersView() -> some View {
        HStack(spacing: 0) {
            ForEach(0..<7, id: \.self) { i in
                Text(DateFormatter().shortWeekdaySymbols[i].prefix(1))
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
    }

    private func calendarGridView(month: CalendarMonth) -> some View {
        let dates = month.getDaysInMonth(offset: 0)
        let gridItems = Array(repeating: GridItem(.flexible(), spacing: 1), count: 7)

        return LazyVGrid(columns: gridItems, alignment: .center, spacing: 1) {
            ForEach(0..<42, id: \.self) { index in
                calendarCellView(date: dates[index])
            }
        }
        .background(Color.gray.opacity(0.15))
        .cornerRadius(12)
        .padding(.horizontal, 20)
        .padding(.top, 12)
    }

    private func calendarCellView(date: CalendarDate) -> some View {
        let isSelected = controller.isDateSelected(date) && date.isCurrentMonth == true

        return ZStack {
            // Cell background
            Rectangle()
                .fill(Color.gray.opacity(0.15))
                .frame(height: 70)

            // Selection background
            if isSelected {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white)
                    .frame(width: 60, height: 60)
            }

            // Day number
            Text("\(date.day)")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(textColor(for: date, isSelected: isSelected))
        }
        .onTapGesture {
            if date.isCurrentMonth == true {
                controller.selectDate(date)
            }
        }
    }

    private func textColor(for date: CalendarDate, isSelected: Bool) -> Color {
        if isSelected {
            return .black
        } else if date.isCurrentMonth == true {
            return .white
        } else {
            return .gray.opacity(0.5)
        }
    }

    private func topButtonsOverlay() -> some View {
        VStack {
            HStack {
                Spacer()
                Button(action: {
                    // Share action
                }) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 20))
                        .foregroundColor(.white)
                }
                Button(action: {
                    // Menu action
                }) {
                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: 20))
                        .foregroundColor(.white)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)

            Spacer()
        }
    }

    private func editButtonOverlay() -> some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                Button(action: {
                    // Edit Action
                }) {
                    Image(systemName: "pencil")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.black)
                        .padding()
                        .background(Color.white)
                        .clipShape(Circle())
                        .shadow(radius: 3)
                }
                .padding(.bottom, 24)
                .padding(.trailing, 24)
            }
        }
    }
}

#Preview {
    EmployeeCalendarView()
}
