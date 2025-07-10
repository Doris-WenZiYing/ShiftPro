//
//  EnhancedDatePickerSheet.swift
//  ShiftPro
//
//  Created by Doris Wen on 2025/7/10.
//

import SwiftUI

struct EnhancedDatePickerSheet: View {
    @Binding var selectedYear: Int
    @Binding var selectedMonth: Int
    @Binding var isPresented: Bool
    let controller: CalendarController

    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(.systemBackground),
                        Color(.systemGray6).opacity(0.3)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                VStack(spacing: 0) {
                    VStack(spacing: 0) {
                        HStack(spacing: 0) {
                            VStack(spacing: 12) {
                                HStack {
                                    Image(systemName: "calendar")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.blue)
                                    Text("年份")
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundColor(.primary)
                                }
                                .padding(.top, 16)

                                Picker("年份", selection: $selectedYear) {
                                    ForEach(1900...2100, id: \.self) { year in
                                        Text(String(year))
                                            .font(.system(size: 22, weight: .medium))
                                            .tag(year)
                                    }
                                }
                                .pickerStyle(WheelPickerStyle())
                                .frame(height: 200)
                                .clipped()
                            }
                            .frame(maxWidth: .infinity)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color(.systemBackground))
                                    .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
                            )
                            .padding(.leading, 20)
                            .padding(.trailing, 8)

                            VStack(spacing: 12) {
                                HStack {
                                    Image(systemName: "calendar.circle")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.green)
                                    Text("月份")
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundColor(.primary)
                                }
                                .padding(.top, 16)

                                Picker("月份", selection: $selectedMonth) {
                                    ForEach(1...12, id: \.self) { month in
                                        Text("\(month)月")
                                            .font(.system(size: 22, weight: .medium))
                                            .tag(month)
                                    }
                                }
                                .pickerStyle(WheelPickerStyle())
                                .frame(height: 200)
                                .clipped()
                            }
                            .frame(maxWidth: .infinity)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color(.systemBackground))
                                    .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
                            )
                            .padding(.trailing, 20)
                            .padding(.leading, 8)
                        }
                        .padding(.bottom, 20)
                    }

                    VStack(spacing: 12) {
                        Text("快速選擇")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)

                        HStack(spacing: 12) {
                            quickSelectButton(title: "本月", action: {
                                let now = Date()
                                selectedYear = Calendar.current.component(.year, from: now)
                                selectedMonth = Calendar.current.component(.month, from: now)
                            })

                            quickSelectButton(title: "下月", action: {
                                let calendar = Calendar.current
                                let nextMonth = calendar.date(byAdding: .month, value: 1, to: Date()) ?? Date()
                                selectedYear = calendar.component(.year, from: nextMonth)
                                selectedMonth = calendar.component(.month, from: nextMonth)
                            })

                            quickSelectButton(title: "上月", action: {
                                let calendar = Calendar.current
                                let lastMonth = calendar.date(byAdding: .month, value: -1, to: Date()) ?? Date()
                                selectedYear = calendar.component(.year, from: lastMonth)
                                selectedMonth = calendar.component(.month, from: lastMonth)
                            })
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 30)

                    Spacer()
                }
            }
            .navigationTitle("選擇日期")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden()
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            isPresented = false
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 16))
                            Text("取消")
                                .font(.system(size: 16))
                        }
                        .foregroundColor(.secondary)
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        controller.navigateToMonth(year: selectedYear, month: selectedMonth)
                        withAnimation(.easeInOut(duration: 0.3)) {
                            isPresented = false
                        }
                    }) {
                        HStack(spacing: 6) {
                            Text("前往")
                                .font(.system(size: 16, weight: .semibold))
                            Image(systemName: "arrow.right.circle.fill")
                                .font(.system(size: 16))
                        }
                        .foregroundColor(.blue)
                    }
                }
            }
        }
        .presentationDetents([.fraction(0.55)])
        .presentationDragIndicator(.visible)
    }

    private func quickSelectButton(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.blue)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.blue.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                        )
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    EnhancedDatePickerSheet(selectedYear: .constant(2025), selectedMonth: .constant(2025), isPresented: .constant(true), controller: CalendarController())
}
