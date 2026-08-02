//
//  SheetNewSettingsView.swift
//  旅行予定日記
//
//  Created by Xcode2021 on 2026/08/02.
//

import SwiftUI
import UniformTypeIdentifiers

struct SheetNewSettingsView: View {
    @EnvironmentObject var model: TravelDataModel
    @Binding var showingAddSheet: Bool
    @State var newSheetTitle: String = ""
    @State var newSheetPrintTitleOnAllPages: Bool = false
    @State var newSheetTitleTextColor: Color = .black
    @State var newSheetTitleBackgroundColor: Color = .white
    @State var newSheetColor: Color = .white
    @State var newSheetDefaultCardBackgroundColor: Color = .white
    @State var newSheetDefaultCardTextColor: Color = .black
    @State var newSheetDefaultCardBorderColor: Color = .red
    @State var newSheetStartDate: Date? = nil
    @State var newSheetEndDate: Date? = nil
    @State var newSheetIsPublic: Bool = false
    @State var newSheetIsPublicText: String = "非公開"
    @State var newSheetIsPublicColor: Color = .white
    @State var newSheetIsPublicIsOn: Bool = false
    @State var draftSelectedDate = Date()

    @State var selectingDateFor: DateSelectionTarget? = nil
    @State var newSheetTravelDateTextColor: Color = .black
    
    // インポート用
    @State private var isImportingSheet = false
    @State private var importError: String?
    @State private var clearImportFeedbackTask: Task<Void, Never>? = nil
    
    var body: some View {
        // シート追加&インポート画面
        NavigationStack {
            Form {
                Section("旅行プラン名") {
                    TextField("例: 東京旅行", text: $newSheetTitle)
                    /*Toggle("2ページ目以降もタイトルを印刷する", isOn: $newSheetPrintTitleOnAllPages)
                        .font(.subheadline)
                        .foregroundColor(.secondary)*/
                    ColorPicker("旅行プラン名の文字色", selection: $newSheetTitleTextColor, supportsOpacity: false)
                    ColorPicker("旅行プラン名の背景色", selection: $newSheetTitleBackgroundColor, supportsOpacity: false)
                }
                Section("背景色") {
                    ColorPicker("旅行プランシートの背景色", selection: $newSheetColor, supportsOpacity: false)
                    ColorPicker("カードの背景色（デフォルト）", selection: $newSheetDefaultCardBackgroundColor, supportsOpacity: false)
                }
                Section("旅行期間") {
                    HStack {
                        Text("旅行開始日")
                        Spacer()
                        if let start = newSheetStartDate {
                            Text(formattedDate(start))
                                .foregroundColor(.secondary)
                        }
                        Button {
                            draftSelectedDate = newSheetStartDate ?? Date()
                            selectingDateFor = .start
                        } label: {
                            Label("", systemImage: "calendar")
                        }
                        .help("開始日を変更します")
                        if newSheetStartDate != nil {
                            Button {
                                newSheetStartDate = nil
                            } label: {
                                Label("", systemImage: "xmark.circle.fill")
                            }
                            .buttonStyle(.plain)
                            .foregroundColor(.secondary)
                            .help("開始日をクリアします")
                        }
                    }
                    HStack {
                        Text("旅行終了日")
                        Spacer()
                        if let end = newSheetEndDate {
                            Text(formattedDate(end))
                                .foregroundColor(.secondary)
                        }
                        Button {
                            draftSelectedDate = newSheetEndDate ?? newSheetStartDate ?? Date()
                            selectingDateFor = .end
                        } label: {
                            Label("", systemImage: "calendar")
                        }
                        .help("終了日を変更します")
                        if newSheetEndDate != nil {
                            Button {
                                newSheetEndDate = nil
                            } label: {
                                Label("", systemImage: "xmark.circle.fill")
                            }
                            .buttonStyle(.plain)
                            .foregroundColor(.secondary)
                            .help("終了日をクリアします")
                        }
                    }
                    ColorPicker("旅行日程の文字色", selection: $newSheetTravelDateTextColor, supportsOpacity: false)
                }
                Section {
                    Button {
                        isImportingSheet = true
                    } label: {
                        Label("シートをインポート", systemImage: "square.and.arrow.down")
                    }
                    .fileImporter(
                        isPresented: $isImportingSheet,
                        allowedContentTypes: [.json],
                        allowsMultipleSelection: false
                    ) { result in
                        Task { @MainActor in
                            do {
                                guard let url = try result.get().first else { return }
                                if let error = model.importSheet(from: url) {
                                    importError = error
                                } else {
                                    importError = nil
                                    showingAddSheet = false
                                }
                            } catch {
                                importError = "インポートに失敗しました: \(error.localizedDescription)"
                            }
                        }
                    }
                    if let err = importError {
                        Text(err)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                } footer: {
                    Text("他の端末で書き出した .json ファイルを読み込めます。")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("新規旅行シートの設定")
            .sheet(item: $selectingDateFor) { target in
                NavigationStack {
                    Form {
                        Section("日付を選択") {
                            DatePicker("日付", selection: Binding(
                                get: { draftSelectedDate },
                                set: { draftSelectedDate = $0 }
                            ), displayedComponents: [.date])
                        }
                    }
                    .navigationTitle(target == .start ? "開始予定日" : "終了予定日")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("キャンセル") {
                                selectingDateFor = nil
                            }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("決定") {
                                if target == .start {
                                    newSheetStartDate = draftSelectedDate
                                } else {
                                    newSheetEndDate = draftSelectedDate
                                }
                                selectingDateFor = nil
                            }
                        }
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        resetAddSheet()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        model.addSheet(
                            title: newSheetTitle,
                            backgroundColor: newSheetColor,
                            startDate: newSheetStartDate,
                            endDate: newSheetEndDate,
                            travelDateTextColor: newSheetTravelDateTextColor,
                            defaultCardBackgroundColor: newSheetDefaultCardBackgroundColor,
                            titleTextColor: newSheetTitleTextColor,
                            titleBackgroundColor: newSheetTitleBackgroundColor,
                            printTitleOnAllPages: newSheetPrintTitleOnAllPages
                        )
                        resetAddSheet()
                    }
                    .disabled(newSheetTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
    
    private func formattedDate(_ date: Date?) -> String {
        guard let date else { return "未設定" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
    
    private func resetAddSheet() {
        showingAddSheet = false
        newSheetTitle = ""
        newSheetColor = .white
        newSheetDefaultCardBackgroundColor = .white
        newSheetTravelDateTextColor = .secondary
        newSheetTitleTextColor = .primary
        newSheetTitleBackgroundColor = .white
        newSheetStartDate = nil
        newSheetEndDate = nil
        selectingDateFor = nil
        importError = nil
        newSheetPrintTitleOnAllPages = true
    }
}

#Preview {
    SheetNewSettingsView(showingAddSheet: .constant(true))
}
