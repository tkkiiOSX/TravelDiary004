import SwiftUI
import UniformTypeIdentifiers

struct SheetListView: View {
    @EnvironmentObject var model: TravelDataModel
    @State private var showingAddSheet = false
    @State private var newSheetTitle = ""
    @State private var newSheetColor: Color = .white
    @State private var newSheetDefaultCardBackgroundColor: Color = .white
    @State private var newSheetTravelDateTextColor: Color = .secondary
    @State private var newSheetTitleTextColor: Color = .primary
    @State private var newSheetTitleBackgroundColor: Color = .white
    @State private var newSheetStartDate: Date? = nil
    @State private var newSheetEndDate: Date? = nil
    @State private var selectingDateFor: DateSelectionTarget? = nil 
    @State private var draftSelectedDate = Date()
    @State private var editingSheetSettings: TravelSheet? = nil
    @State private var editingSheetTitle = ""
    @State private var editingSheetColor: Color = .white
    @State private var editingSheetDefaultCardBackgroundColor: Color = .white
    @State private var editingSheetTravelDateTextColor: Color = .secondary
    @State private var editingSheetTitleTextColor: Color = .primary
    @State private var editingSheetTitleBackgroundColor: Color = .white
    @State private var editingSheetStartDate: Date? = nil
    @State private var editingSheetEndDate: Date? = nil
    @State private var editingSheetDateSelection: DateSelectionTarget? = nil
    @State private var editingSheetDraftSelectedDate = Date()
    @State private var sheetPendingDeletion: TravelSheet? = nil
    @State private var showDeleteAlert = false

    // 追加: 2ページ目以降もタイトルを印刷する設定
    @State private var newSheetPrintTitleOnAllPages: Bool = true
    @State private var editingSheetPrintTitleOnAllPages: Bool = true

    // 共有用
    @State private var shareItem: ShareItem?
    @State private var shareFileURL: URL?
    @State private var shareErrorMessage: String?

    // インポート用
    @State private var isImportingSheet = false
    @State private var importError: String?
    @State private var clearImportFeedbackTask: Task<Void, Never>? = nil

    var body: some View {
        ZStack(alignment: .top) {
            NavigationStack {
                List {
                    if model.sheets.isEmpty {
                        Section("旅行テーマを追加してください") {
                            Text("右上の「＋」ボタンで新しいシートを作成")
                                .foregroundColor(.secondary)
                        }
                    }
                    ForEach(model.sheets) { sheet in
                        SheetRowView(
                            sheet: sheet,
                            onExport: {
                                prepareShare(for: sheet)
                            },
                            onOpenSettings: {
                                startEditingSheet(sheet)
                            }
                        )
                        .listRowBackground(sheet.backgroundColor.opacity(0.08))
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                sheetPendingDeletion = sheet
                                showDeleteAlert = true
                            } label: {
                                Label("削除", systemImage: "trash")
                            }
                        }
                    }
                }
                .navigationTitle("旅行予定日記")
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            showingAddSheet = true
                        } label: {
                            Image(systemName: "plus")
                        }
                        .accessibilityLabel("新しい旅行シートを追加")
                    }
                }
                .sheet(isPresented: $showingAddSheet) {
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
                                ColorPicker("旅行シートの背景色", selection: $newSheetColor, supportsOpacity: false)
                                ColorPicker("デフォルトのカード色", selection: $newSheetDefaultCardBackgroundColor, supportsOpacity: false)
                            }
                            Section("旅行日程") {
                                ColorPicker("旅行日程の文字色", selection: $newSheetTravelDateTextColor, supportsOpacity: false)
                                
                                VStack {
                                    Button {
                                        draftSelectedDate = newSheetStartDate ?? Date()
                                        selectingDateFor = .start
                                    } label: {
                                        HStack {
                                            Text("旅行開始予定日")
                                            Spacer()
                                            Text(newSheetStartDate == nil ? "未設定" : formattedDate(newSheetStartDate))
                                                .foregroundColor(.secondary)
                                            
                                            Label("", systemImage: "calendar")
                                            
                                            
                                            Button {
                                                newSheetStartDate = nil
                                            } label: {
                                                HStack {
                                                    Image(systemName: "xmark.circle")
                                                    Text("")
                                                }
                                        }
                                    }
                                        
                                    Button {
                                        draftSelectedDate = newSheetEndDate ?? newSheetStartDate ?? Date()
                                        selectingDateFor = .end
                                    } label: {
                                        HStack {
                                            Text("旅行終了予定日")
                                            Spacer()
                                            Text(newSheetEndDate == nil ? "未設定" : formattedDate(newSheetEndDate))
                                                .foregroundColor(.secondary)
                                            
                                            Label("", systemImage: "calendar")
                                        
                                            Button {
                                                newSheetEndDate = nil
                                            } label: {
                                                HStack {
                                                    Image(systemName: "xmark.circle")
                                                    Text("")
                                                }
                                            }
                                }
                                
                                        
                                        }
                                    }
                                }

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
                        .navigationTitle("旅行シートの設定")
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
                .sheet(item: $editingSheetSettings) { sheet in
                    SheetSettingsView(
                        sheet: sheet,
                        editingSheetTitle: $editingSheetTitle,
                        editingSheetColor: $editingSheetColor,
                        editingSheetDefaultCardBackgroundColor: $editingSheetDefaultCardBackgroundColor,
                        editingSheetTravelDateTextColor: $editingSheetTravelDateTextColor,
                        editingSheetTitleTextColor: $editingSheetTitleTextColor,
                        editingSheetTitleBackgroundColor: $editingSheetTitleBackgroundColor,
                        editingSheetStartDate: $editingSheetStartDate,
                        editingSheetEndDate: $editingSheetEndDate,
                        editingSheetDateSelection: $editingSheetDateSelection,
                        editingSheetDraftSelectedDate: $editingSheetDraftSelectedDate,
                        editingSheetPrintTitleOnAllPages: $editingSheetPrintTitleOnAllPages,
                        onCancel: { editingSheetSettings = nil },
                        onSave: {
                            model.updateSheetTitle(sheetID: sheet.id, newTitle: editingSheetTitle)
                            model.updateSheetColor(sheetID: sheet.id, color: editingSheetColor)
                            model.updateSheetDefaultCardBackgroundColor(sheetID: sheet.id, color: editingSheetDefaultCardBackgroundColor)
                            model.updateSheetTravelDateTextColor(sheetID: sheet.id, color: editingSheetTravelDateTextColor)
                            model.updateSheetTravelDates(sheetID: sheet.id, startDate: editingSheetStartDate, endDate: editingSheetEndDate)
                            model.updateSheetTitleTextColor(sheetID: sheet.id, color: editingSheetTitleTextColor)
                            model.updateSheetTitleBackgroundColor(sheetID: sheet.id, color: editingSheetTitleBackgroundColor)
                            model.updateSheetPrintTitleOnAllPages(sheetID: sheet.id, value: editingSheetPrintTitleOnAllPages)
                            editingSheetSettings = nil
                        }
                    )
                }
                .navigationDestination(for: TravelSheet.self) { sheet in
                    CardListView(initialSheet: sheet)
                }
                .sheet(item: $shareItem, onDismiss: {
                    if let url = shareFileURL {
                        try? FileManager.default.removeItem(at: url)
                    }
                    shareFileURL = nil
                    shareItem = nil
                }) { item in
                    ActivityView(activityItems: [item.url])
                }
                .alert("共有画面を表示できませんでした", isPresented: Binding(
                    get: { shareErrorMessage != nil },
                    set: { if !$0 { shareErrorMessage = nil } }
                )) {
                    Button("やり直す", role: .cancel) {
                        shareErrorMessage = nil
                    }
                } message: {
                    Text(shareErrorMessage ?? "もう一度「シートを書き出し」を押してください。")
                }
                .alert("このシートを削除しますか？", isPresented: $showDeleteAlert, presenting: sheetPendingDeletion) { pending in
                    Button("削除", role: .destructive) {
                        model.deleteSheet(pending)
                        sheetPendingDeletion = nil
                    }
                    Button("キャンセル", role: .cancel) {
                        sheetPendingDeletion = nil
                    }
                } message: { pending in
                    Text(pending.title)
                }
            }

            if let feedback = model.importFeedback {
                ImportToastView(message: feedback.message, isSuccess: feedback.isSuccess)
                    .padding(.top, 12)
                    .padding(.horizontal, 16)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: model.importFeedback?.id)
        .onChange(of: model.importFeedback?.id) { _, newValue in
            clearImportFeedbackTask?.cancel()
            guard let newValue else { return }
            clearImportFeedbackTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                if model.importFeedback?.id == newValue {
                    model.clearImportFeedback()
                }
            }
        }
    }
}

private struct ShareItem: Identifiable {
    let id = UUID()
    let url: URL
}

extension SheetListView {
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

    /*private func startEditingSheet(_ sheet: TravelSheet) {
        print("startEditingSheetA=\(editingSheetStartDate)")
        print("startEditingSheetB=\(sheet.startDate)")
        editingSheetSettings = sheet
        editingSheetTitle = sheet.title
        editingSheetColor = sheet.backgroundColor
        editingSheetDefaultCardBackgroundColor = Color(hex: sheet.effectiveDefaultCardBackgroundColorHex)
        editingSheetTravelDateTextColor = sheet.travelDateTextColor
        editingSheetTitleTextColor = sheet.titleTextColor
        editingSheetTitleBackgroundColor = sheet.titleBackgroundColor
        editingSheetStartDate = sheet.startDate
        editingSheetEndDate = sheet.endDate
        editingSheetDateSelection = nil
        editingSheetDraftSelectedDate = Date()
        editingSheetPrintTitleOnAllPages = sheet.printTitleOnAllPages ?? true
        print("startEditingSheetA2=\(editingSheetStartDate)")
        print("startEditingSheetB2=\(sheet.startDate)")
    }*/
    private func startEditingSheet(_ sheet: TravelSheet) {
        // 先に全ての編集用 State をセット
        editingSheetTitle = sheet.title
        editingSheetColor = sheet.backgroundColor
        editingSheetDefaultCardBackgroundColor = Color(hex: sheet.effectiveDefaultCardBackgroundColorHex)
        editingSheetTravelDateTextColor = sheet.travelDateTextColor
        editingSheetTitleTextColor = sheet.titleTextColor
        editingSheetTitleBackgroundColor = sheet.titleBackgroundColor

        editingSheetStartDate = sheet.startDate
        editingSheetEndDate = sheet.endDate

        editingSheetDateSelection = nil
        // ドラフトは開始日に寄せる（nil の場合だけ Date()）
        editingSheetDraftSelectedDate = sheet.startDate ?? Date()

        editingSheetPrintTitleOnAllPages = sheet.printTitleOnAllPages ?? true

        // 最後に表示トリガー
        editingSheetSettings = sheet
    }


    private func formattedDate(_ date: Date?) -> String {
        guard let date else { return "未設定" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }

    private func prepareShare(for sheet: TravelSheet) {
        do {
            let data = try JSONEncoder().encode(sheet)
            let tempDir = FileManager.default.temporaryDirectory
            let fileName = defaultExportFileName(for: sheet)
            let fileURL = tempDir.appendingPathComponent(fileName)
            try data.write(to: fileURL, options: [.atomic])
            shareFileURL = fileURL
            shareItem = ShareItem(url: fileURL)
        } catch {
            shareFileURL = nil
            shareItem = nil
            shareErrorMessage = "書き出しに失敗しました。もう一度お試しください。"
        }
    }

    private func defaultExportFileName(for sheet: TravelSheet) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "ja_JP")
        dateFormatter.timeZone = TimeZone.current
        dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
        let nowString = dateFormatter.string(from: Date())
        // ファイル名に使用できない文字を除去
        let invalidChars = CharacterSet(charactersIn: "/\\?%*:|\"<>")
        let sanitized = sheet.title.components(separatedBy: invalidChars).joined()
        let base = sanitized.isEmpty ? "TravelSheet" : sanitized
        return "\(base)_\(nowString).json"
    }
}

private struct ImportToastView: View {
    let message: String
    let isSuccess: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: isSuccess ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(.white)
            Text(message)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(2)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(isSuccess ? Color.green.opacity(0.92) : Color.red.opacity(0.92))
        )
        .shadow(color: .black.opacity(0.15), radius: 14, x: 0, y: 6)
    }
}

#Preview {
    SheetListView().environmentObject(TravelDataModel())
}

import UniformTypeIdentifiers

struct TravelSheetDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    static var writableContentTypes: [UTType] { [.json] }
    var data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else { throw CocoaError(.fileReadCorruptFile) }
        self.data = data
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        return FileWrapper(regularFileWithContents: data)
    }
}

private struct SheetRowView: View {
    let sheet: TravelSheet
    let onExport: () -> Void
    let onOpenSettings: () -> Void

    @EnvironmentObject private var model: TravelDataModel
    @State private var isEditingTitle = false
    @State private var draftTitle = ""
    @FocusState private var isTitleFocused: Bool

    var body: some View {
        HStack(spacing: 12) {
            Group {
                if isEditingTitle {
                    HStack(spacing: 12) {
                        Circle()
                            .fill(sheet.backgroundColor)
                            .frame(width: 16, height: 16)
                            .overlay(
                                Circle()
                                    .stroke(Color.black.opacity(0.08), lineWidth: 1)
                            )
                        TextField("シート名", text: $draftTitle)
                            .font(.headline)
                            .textFieldStyle(.roundedBorder)
                            .focused($isTitleFocused)
                            .submitLabel(.done)
                            .onSubmit { finishEditingTitle() }
                            .onAppear { isTitleFocused = true }
                            .onChange(of: draftTitle) { _, newValue in
                                let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                                if !trimmed.isEmpty {
                                    model.updateSheetTitle(sheetID: sheet.id, newTitle: trimmed)
                                }
                            }
                        Spacer(minLength: 0)
                    }
                } else {
                    NavigationLink(value: sheet) {
                        HStack(spacing: 12) {
                            Circle()
                                .fill(sheet.backgroundColor)
                                .frame(width: 16, height: 16)
                                .overlay(
                                    Circle()
                                        .stroke(Color.black.opacity(0.08), lineWidth: 1)
                                )
                            VStack(alignment: .leading, spacing: 4) {
                                Text(sheet.title)
                                    .foregroundColor(sheet.titleTextColor)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                                            .fill(sheet.titleBackgroundColor.opacity(0.9))
                                    )
                                    .font(.headline)
                                    .onLongPressGesture(minimumDuration: 0.5) {
                                        draftTitle = sheet.title
                                        isEditingTitle = true
                                        isTitleFocused = true
                                    }
                                Text("カード数: \(sheet.cards.count)")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            Spacer(minLength: 0)
                        }
                    }
                }
            }
            Button(action: onOpenSettings) {
                Label("シートの設定", systemImage: "slider.horizontal.3")
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(.borderless)
            .help("このシートの設定を変更します")

            Button(action: onExport) {
                Label("シートを書き出し", systemImage: "square.and.arrow.up")
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(.borderless)
            .help("このシートを書き出して他の端末でインポートできます")
        }
    }

    private func finishEditingTitle() {
        let trimmed = draftTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            draftTitle = sheet.title
        } else {
            model.updateSheetTitle(sheetID: sheet.id, newTitle: trimmed)
            draftTitle = trimmed
        }
        isEditingTitle = false
        isTitleFocused = false
    }
}
