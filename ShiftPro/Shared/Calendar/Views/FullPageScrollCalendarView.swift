//
//  FullPageScrollCalendarView.swift
//  ShiftPro
//
//  Created by Doris Wen on 2025/7/9.
//

import SwiftUI

public struct FullPageScrollCalendarView<PageContent: View>: View {

    private let pageContent: (CalendarMonth) -> PageContent
    @ObservedObject private var controller: CalendarController

    public init(
        _ controller: CalendarController = CalendarController(),
        @ViewBuilder pageContent: @escaping (CalendarMonth) -> PageContent
    ) {
        self.controller = controller
        self.pageContent = pageContent
    }

    public var body: some View {
        InfiniteScrollView(controller) { month, _ in
            pageContent(month)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
