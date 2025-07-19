//
//  CalendarGridView.swift
//  ShiftPro
//
//  Created by Doris Wen on 2025/7/19.
//

import SwiftUI

struct CalendarGridView: View {
    let date: CalendarDate
    let isSelected: Bool
    let isVacationSelected: Bool
    let canSelect: Bool
    let action: () -> Void

    private var dayNumber: Int {
        date.day
    }

    private var isInCurrentMonth: Bool {
        date.isCurrentMonth ?? true
    }

    var body: some View {
        Button(action: action) {
            ZStack {
                // Background
                RoundedRectangle(cornerRadius: 8)
                    .fill(backgroundColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(borderColor, lineWidth: borderWidth)
                    )

                VStack(spacing: 4) {
                    // Day number
                    Text("\(dayNumber)")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(textColor)

                    // Indicators
                    HStack(spacing: 2) {
                        if isSelected {
                            Circle()
                                .fill(Color.blue)
                                .frame(width: 6, height: 6)
                        }

                        if isVacationSelected {
                            Circle()
                                .fill(Color.orange)
                                .frame(width: 6, height: 6)
                        }
                    }
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(!canSelect || !isInCurrentMonth)
        .opacity(isInCurrentMonth ? 1.0 : 0.3)
    }

    // MARK: - Style Properties

    private var backgroundColor: Color {
        if isVacationSelected {
            return Color.orange.opacity(0.2)
        } else if isSelected {
            return Color.blue.opacity(0.2)
        } else {
            return Color.gray.opacity(0.1)
        }
    }

    private var borderColor: Color {
        if isVacationSelected {
            return Color.orange
        } else if isSelected {
            return Color.blue
        } else {
            return Color.clear
        }
    }

    private var borderWidth: CGFloat {
        (isSelected || isVacationSelected) ? 1 : 0
    }

    private var textColor: Color {
        if !isInCurrentMonth {
            return .gray
        } else if isVacationSelected {
            return .orange
        } else if isSelected {
            return .blue
        } else {
            return .white
        }
    }
}

#Preview {
    let calendar = Calendar.current
    let today = Date()
    let calendarDate = CalendarDate(
        year: calendar.component(.year, from: today),
        month: calendar.component(.month, from: today),
        day: calendar.component(.day, from: today),
        isCurrentMonth: true
    )

    return VStack(spacing: 20) {
        CalendarGridView(
            date: calendarDate,
            isSelected: false,
            isVacationSelected: false,
            canSelect: true
        ) {
            print("Normal cell tapped")
        }

        CalendarGridView(
            date: calendarDate,
            isSelected: true,
            isVacationSelected: false,
            canSelect: true
        ) {
            print("Selected cell tapped")
        }

        CalendarGridView(
            date: calendarDate,
            isSelected: false,
            isVacationSelected: true,
            canSelect: true
        ) {
            print("Vacation cell tapped")
        }
    }
    .padding()
    .background(Color.black)
}
