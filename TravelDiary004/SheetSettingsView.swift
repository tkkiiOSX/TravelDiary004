import SwiftUI

struct SheetSettingsView: View {
    let sheet: TravelSheet
    @Binding var editingSheetTitle: String
    @Binding var editingSheetColor: Color
    @Binding var editingSheetDefaultCardBackgroundColor: Color
    @Binding var editingSheetTravelDateTextColor: Color
    @Binding var editingSheetTitleTextColor: Color
    @Binding var editingSheetTitleBackgroundColor: Color
    @Binding var editingSheetStartDate: Date?
    @Binding var editingSheetEndDate: Date?
    @Binding var editingSheetDateSelection: DateSelectionTarget?
    @Binding var editingSheetDraftSelectedDate: Date
    @Binding var editingSheetPrintTitleOnAllPages: Bool
    let onCancel: () -> Void
    let onSave: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("旅程名", text: $editingSheetTitle)
                    Toggle("全ページに旅程名を印刷", isOn: $editingSheetPrintTitleOnAllPages)
                } header: {
                    Text("旅程名")
                }
                Section {
                    ColorPicker("旅程の色", selection: $editingSheetColor)
                    ColorPicker("カード背景色（デフォルト）", selection: $editingSheetDefaultCardBackgroundColor)
                    ColorPicker("旅行日付テキスト色", selection: $editingSheetTravelDateTextColor)
                    ColorPicker("旅程名テキスト色", selection: $editingSheetTitleTextColor)
                    ColorPicker("旅程名背景色", selection: $editingSheetTitleBackgroundColor)
                } header: {
                    Text("色")
                }
                Section {
                    HStack {
                        Text("開始日")
                        Spacer()
                        if let start = editingSheetStartDate {
                            Text(formattedDate(start))
                                .foregroundColor(.secondary)
                        }
                        Button {
                            editingSheetDateSelection = .start
                            editingSheetDraftSelectedDate = editingSheetStartDate ?? Date()
                        } label: {
                            Label("変更", systemImage: "calendar")
                        }
                        .buttonStyle(.bordered)
                        .help("開始日を変更します")
                        if editingSheetStartDate != nil {
                            Button {
                                editingSheetStartDate = nil
                            } label: {
                                Label("クリア", systemImage: "xmark.circle.fill")
                            }
                            .buttonStyle(.plain)
                            .foregroundColor(.secondary)
                            .help("開始日をクリアします")
                        }
                    }
                    HStack {
                        Text("終了日")
                        Spacer()
                        if let end = editingSheetEndDate {
                            Text(formattedDate(end))
                                .foregroundColor(.secondary)
                        }
                        Button {
                            editingSheetDateSelection = .end
                            editingSheetDraftSelectedDate = editingSheetEndDate ?? Date()
                        } label: {
                            Label("変更", systemImage: "calendar")
                        }
                        .buttonStyle(.bordered)
                        .help("終了日を変更します")
                        if editingSheetEndDate != nil {
                            Button {
                                editingSheetEndDate = nil
                            } label: {
                                Label("クリア", systemImage: "xmark.circle.fill")
                            }
                            .buttonStyle(.plain)
                            .foregroundColor(.secondary)
                            .help("終了日をクリアします")
                        }
                    }
                    Button {
                        // Reload dates from sheet, assuming method exists on TravelSheet
                        if let loadedStart = sheet.startDate { editingSheetStartDate = loadedStart }
                        if let loadedEnd = sheet.endDate { editingSheetEndDate = loadedEnd }
                    } label: {
                        Label("旅程の開始・終了日を再読込", systemImage: "arrow.clockwise")
                    }
                } header: {
                    Text("旅行期間")
                }
            }
            .navigationTitle("旅程編集")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル", role: .cancel, action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存", action: onSave)
                        .disabled(editingSheetTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .keyboardShortcut(.defaultAction)
                }
            }
            .sheet(item: $editingSheetDateSelection) { selection in
                DateSelectionView(
                    selectedDate: $editingSheetDraftSelectedDate,
                    title: selection.title,
                    onCancel: { editingSheetDateSelection = nil },
                    onDone: {
                        switch selection {
                        case .start: editingSheetStartDate = editingSheetDraftSelectedDate
                        case .end: editingSheetEndDate = editingSheetDraftSelectedDate
                        }
                        editingSheetDateSelection = nil
                    }
                )
            }
        }
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

struct DateSelectionView: View {
    @Binding var selectedDate: Date
    let title: String
    let onCancel: () -> Void
    let onDone: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                DatePicker(selection: $selectedDate, displayedComponents: .date) {
                    Text(title)
                }
                .datePickerStyle(.graphical)
            }
            .navigationTitle(title)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル", role: .cancel, action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("完了", action: onDone)
                        .keyboardShortcut(.defaultAction)
                }
            }
        }
    }
}

enum DateSelectionTarget: Identifiable {
    case start
    case end

    var id: Int {
        switch self {
        case .start: return 0
        case .end: return 1
        }
    }

    var title: String {
        switch self {
        case .start: return "開始日選択"
        case .end: return "終了日選択"
        }
    }
}

#Preview {
    SheetSettingsView(
        sheet: TravelSheet(
            id: UUID(),
            title: "テスト旅程",
            color: .blue,
            defaultCardBackgroundColor: .white,
            travelDateTextColor: .black,
            titleTextColor: .black,
            titleBackgroundColor: .gray,
            startDate: Date(),
            endDate: Calendar.current.date(byAdding: .day, value: 5, to: Date()),
            printTitleOnAllPages: false
        ),
        editingSheetTitle: .constant("テスト旅程"),
        editingSheetColor: .constant(.blue),
        editingSheetDefaultCardBackgroundColor: .constant(.white),
        editingSheetTravelDateTextColor: .constant(.black),
        editingSheetTitleTextColor: .constant(.black),
        editingSheetTitleBackgroundColor: .constant(.gray),
        editingSheetStartDate: .constant(Date()),
        editingSheetEndDate: .constant(Calendar.current.date(byAdding: .day, value: 5, to: Date())),
        editingSheetDateSelection: .constant(nil),
        editingSheetDraftSelectedDate: .constant(Date()),
        editingSheetPrintTitleOnAllPages: .constant(false),
        onCancel: {},
        onSave: {}
    )
    .environmentObject(TravelDataModel())
}
