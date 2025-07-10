//
//  CalendarController.swift
//  ShiftPro
//
//  Created by Doris Wen on 2025/7/9.
//

import SwiftUI
import Combine

public enum CalendarOrientation {
    case horizontal
    case vertical
}

public class CalendarController: ObservableObject {
    @Published public var yearMonth: CalendarMonth
    @Published public var selectedDate: CalendarDate?
    @Published internal var position: Int = CalendarConstants.centerPage
    @Published internal var internalYearMonth: CalendarMonth

    public let orientation: CalendarOrientation
    internal let scrollDetector: CurrentValueSubject<CGFloat, Never>
    internal var cancellables = Set<AnyCancellable>()

    public init(orientation: CalendarOrientation = .vertical, month: CalendarMonth = .current) {
        let detector = CurrentValueSubject<CGFloat, Never>(0)

        self.orientation = orientation
        self.scrollDetector = detector
        self.internalYearMonth = month
        self.yearMonth = month
        self.selectedDate = CalendarDate.today

        detector
            .debounce(for: .seconds(0.2), scheduler: DispatchQueue.main)
            .dropFirst()
            .sink { [weak self] value in
                if let self = self {
                    let move = self.position - CalendarConstants.centerPage
                    self.internalYearMonth = self.internalYearMonth.addMonths(move)
                    self.yearMonth = self.internalYearMonth
                    self.position = CalendarConstants.centerPage
                    self.objectWillChange.send()
                }
            }
            .store(in: &cancellables)
    }

    public func setYearMonth(year: Int, month: Int) {
        self.setYearMonth(CalendarMonth(year: year, month: month))
    }

    public func setYearMonth(_ month: CalendarMonth) {
        self.yearMonth = month
        self.internalYearMonth = month
        self.position = CalendarConstants.centerPage
        self.objectWillChange.send()
    }

    public func selectDate(_ date: CalendarDate) {
        self.selectedDate = date
    }

    public func isDateSelected(_ date: CalendarDate) -> Bool {
        guard let selected = selectedDate else { return false }
        return selected == date
    }
}

extension CalendarController {
    func navigateToMonth(year: Int, month: Int) {
        self.setYearMonth(year: year, month: month)

        print("Navigate to: \(year)年\(month)月")
    }
}
