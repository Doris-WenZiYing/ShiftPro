//
//  WeekdayHeaderView.swift
//  ShiftPro
//
//  Created by Doris Wen on 2025/7/9.
//

import SwiftUI

struct WeekdayHeaderView: View {
    private let days = ["S", "M", "T", "W", "T", "F", "S"]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(days, id: \.self) { day in
                Text(day)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, minHeight: 30)
            }
        }
        .padding(.horizontal, 20)
    }
}

#Preview {
    WeekdayHeaderView()
}
