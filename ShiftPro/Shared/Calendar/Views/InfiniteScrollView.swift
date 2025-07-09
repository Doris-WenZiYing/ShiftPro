//
//  InfiniteScrollView.swift
//  ShiftPro
//
//  Created by Doris Wen on 2025/7/9.
//

import SwiftUI
import Combine

internal struct InfiniteScrollView<Content: View>: View {
    private let content: (CalendarMonth, Int) -> Content
    @ObservedObject private var controller: CalendarController

    init(_ controller: CalendarController, @ViewBuilder content: @escaping (CalendarMonth, Int) -> Content) {
        self.controller = controller
        self.content = content
    }

    var body: some View {
        GeometryReader { geometry in
            TabView(selection: $controller.position) {
                ForEach(0..<CalendarConstants.maxPages, id: \.self) { i in
                    let month = controller.internalYearMonth.addMonths(i - CalendarConstants.centerPage)
                    self.content(month, i)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .rotationEffect(.degrees(-90))
                        .background(GeometryReader {
                            Color.clear.preference(key: ScrollOffsetKey.self, value: -$0.frame(in: .named("scroll")).origin.y)
                        })
                        .onPreferenceChange(ScrollOffsetKey.self) { controller.scrollDetector.send($0) }
                        .tag(i)
                }
            }
            .frame(width: geometry.size.height, height: geometry.size.width)
            .rotationEffect(.degrees(90), anchor: .topLeading)
            .offset(x: geometry.size.width)
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            .coordinateSpace(name: "scroll")
        }
    }
}

fileprivate struct ScrollOffsetKey: PreferenceKey {
    typealias Value = CGFloat
    static var defaultValue = CGFloat.zero
    static func reduce(value: inout Value, nextValue: () -> Value) {
        value += nextValue()
    }
}
