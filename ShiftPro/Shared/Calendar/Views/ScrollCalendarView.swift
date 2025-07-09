//
//  ScrollCalendarView.swift
//  ShiftPro
//
//  Created by Doris Wen on 2025/7/9.
//

import SwiftUI

public struct ScrollCalendarView<DateCell: View>: View {

    private var gridItems: [GridItem] = Array(repeating: .init(.flexible(), spacing: 8), count: 7)
    private let dateCell: (CalendarDate) -> DateCell
    @ObservedObject private var controller: CalendarController

    public init(
        _ controller: CalendarController = CalendarController(),
        @ViewBuilder dateCell: @escaping (CalendarDate) -> DateCell
    ) {
        self.controller = controller
        self.dateCell = dateCell
    }

    public var body: some View {
        InfiniteScrollView(controller) { month, _ in
            LazyVGrid(columns: gridItems, alignment: .center, spacing: 8) {
                ForEach(0..<42, id: \.self) { index in
                    let dates = month.getDaysInMonth(offset: 0)
                    let date = dates[index]

                    dateCell(date)
                        .onTapGesture {
                            if date.isCurrentMonth == true {
                                controller.selectDate(date)
                            }
                        }
                }
            }
            .padding(.horizontal, 20)
        }
    }
}
