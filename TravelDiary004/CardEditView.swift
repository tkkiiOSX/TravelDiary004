import SwiftUI
import PhotosUI
import MapKit

struct CardEditView: View {
    @EnvironmentObject var model: TravelDataModel
    @Environment(\.dismiss) private var dismiss
    @State private var card: TravelCard
    let sheet: TravelSheet
    let onSave: (TravelCard) -> Void

    @State private var selectedItem: PhotosPickerItem? = nil
    @State private var showMapSelection = false
    @State private var showWebPreview = false
    @State private var previewURL: URL? = nil
    @State private var webSearchQuery = ""
    @State private var editMapPosition: MapCameraPosition = .automatic
    @State private var showColorAlert = false
    @State private var showPatternColorAlert = false
    @State private var lastHandledImportFeedbackID: UUID? = nil
    @State private var showStyleEditor = false

    init(card: TravelCard, sheet: TravelSheet, onSave: @escaping (TravelCard) -> Void) {
        _card = State(initialValue: card)
        self.sheet = sheet
        self.onSave = onSave
    }

    private func resetLocation() {
        card.locationName = ""
        card.address = ""
        card.latitude = 0.0
        card.longitude = 0.0
        editMapPosition = .automatic
    }

    private func resetWebPage() {
        card.url = ""
        previewURL = nil
        showWebPreview = false
    }

    private func resetPhoto() {
        card.imageData = nil
        selectedItem = nil
    }

    var body: some View {
        Form {
            Section {
                Picker("カテゴリ", selection: $card.category) {
                    ForEach(TravelCard.categoryOptions, id: \.0) { option in
                        Label(option.1, systemImage: option.2)
                            .tag(option.0)
                    }
                }
                .pickerStyle(.menu)
            }
            Section("タイトル") {
                TextField("カードタイトルを入力", text: $card.title)
            }
            Section("日時") {
                Toggle("シートに日時を表示", isOn: $card.showDate)
                    .toggleStyle(.switch)
                DatePicker("日付", selection: $card.date, displayedComponents: [.date, .hourAndMinute])
            }
            Section("メモ") {
                TextEditor(text: $card.memo)
                    .frame(minHeight: 120)
            }
            Section("Map") {
                Toggle("Mapを印刷する", isOn: $card.printLocation)
                    .toggleStyle(.switch)
                TextField("地名・施設名", text: $card.locationName)
                TextField("住所", text: $card.address)

                if card.hasLocation {
                    Map(position: $editMapPosition) {
                        Marker(card.locationName.isEmpty ? "位置" : card.locationName,
                               coordinate: CLLocationCoordinate2D(latitude: card.latitude, longitude: card.longitude))
                            .tint(.red)
                    }
                    .frame(height: 180)
                    .cornerRadius(12)
                    .onAppear {
                        updateEditMapPosition()
                    }
                    .onChange(of: card.latitude) { _, _ in
                        updateEditMapPosition()
                    }
                    .onChange(of: card.longitude) { _, _ in
                        updateEditMapPosition()
                    }

                    HStack {
                        Image(systemName: "mappin.circle.fill")
                            .foregroundColor(.red)
                        Text(String(format: "%.4f, %.4f", card.latitude, card.longitude))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Button(action: { showMapSelection = true }) {
                        Label("地点の選択表示", systemImage: "map")
                    }
                    Button(role: .destructive) {
                        resetLocation()
                    } label: {
                        Label("位置情報を削除", systemImage: "trash")
                    }
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Image(systemName: "map")
                                .foregroundColor(.secondary)
                            Text("位置情報を追加するとプレビューが表示されます")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        Button(action: { showMapSelection = true }) {
                            Label("地図で位置を設定", systemImage: "map")
                        }
                    }
                }
            }
            Section("Webページ") {
                Toggle("Webページを印刷する", isOn: $card.printWebPage)
                TextField("URLを入力", text: $card.url)
                    .keyboardType(.URL)
                    .autocapitalization(.none)
                    .textInputAutocapitalization(.never)
                    .onChange(of: card.url) { _, newValue in
                        previewURL = makeURL(from: newValue)
                    }

                if let url = previewURL {
                    WebView(url: url, allowNavigation: true) { newURL in
                        let absoluteURL = newURL.absoluteString
                        if card.url != absoluteURL {
                            card.url = absoluteURL
                        }
                        self.previewURL = newURL
                    }
                    .frame(height: 220)
                    .cornerRadius(12)
                } else {
                    Text("有効な URL を入力するとプレビューが表示されます")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Button(action: {
                    if let url = makeURL(from: card.url) {
                        card.url = url.absoluteString
                        previewURL = url
                        showWebPreview = true
                    }
                }) {
                    Label("Webページを表示", systemImage: "safari")
                }
                .disabled(makeURL(from: card.url) == nil)

                TextField("検索ワードを入力", text: $webSearchQuery)
                    .autocapitalization(.none)
                    .textInputAutocapitalization(.never)
                Button(action: {
                    let query = webSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !query.isEmpty,
                          let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
                          let url = URL(string: "https://www.google.com/search?q=\(encodedQuery)")
                    else { return }
                    previewURL = url
                    showWebPreview = true
                }) {
                    Label("検索で表示", systemImage: "magnifyingglass")
                }
                .disabled(webSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                if card.hasURL || previewURL != nil {
                    Button(role: .destructive) {
                        resetWebPage()
                    } label: {
                        Label("Webページを削除", systemImage: "trash")
                    }
                }
            }
            Section("写真") {
                Toggle("写真を印刷する", isOn: $card.printPhoto)
                if let imageData = card.imageData,
                   let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 240)
                        .cornerRadius(12)
                } else {
                    Image(systemName: "photo.on.rectangle.angled")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 120)
                        .foregroundStyle(.secondary)
                }
                
                PhotosPicker(
                    selection: $selectedItem,
                    matching: .images,
                    photoLibrary: .shared()) {
                        Text("写真を選択")
                    }
                    .onChange(of: selectedItem) { _, newItem in
                        Task {
                            if let item = newItem, let data = try? await item.loadTransferable(type: Data.self) {
                                card.imageData = data
                            }
                        }
                    }
                
                if card.imageData != nil {
                    Button(role: .destructive) {
                        resetPhoto()
                    } label: {
                        Label("写真を削除", systemImage: "trash")
                    }
                }
            }
        .environment(\.locale, Locale(identifier: "ja_JP"))
        .navigationTitle(sheet.title)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("OK") {
                    saveAndDismiss()
                } else if card.hasPatternColorConflict && card.patternEffect != .none {
                        showPatternColorAlert = true
                    } else {
                        saveAndDismiss()
                    }
                }
            }
        }
        .sheet(isPresented: $showMapSelection) {
            MapSelectionView(
                card: $card,
                onDismiss: { showMapSelection = false }
            )
        }
        .sheet(isPresented: $showWebPreview) {
            if let url = previewURL {
                WebPreviewView(url: url) { newURL in
                    if newURL.host == "www.google.com" && newURL.path == "/search" {
                        return
                    }
                    let absoluteURL = newURL.absoluteString
                    if card.url != absoluteURL {
                        card.url = absoluteURL
                    }
                    previewURL = newURL
                }
            }
        }
        .onChange(of: model.importFeedback?.id) { _, newValue in
            guard let newValue, lastHandledImportFeedbackID != newValue else { return }
            lastHandledImportFeedbackID = newValue
            dismiss()
        }
    }

    private func makeURL(from input: String) -> URL? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if let url = URL(string: trimmed), url.scheme != nil {
            return url
        }
        return URL(string: "https://\(trimmed)")
    }

    private func updateEditMapPosition() {
        guard card.hasLocation else { return }
        let region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: card.latitude, longitude: card.longitude),
            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        )
        editMapPosition = .region(region)
    }

    private func saveAndDismiss() {
        onSave(card)
        dismiss()
    }
}

#Preview {
    // 以下のような new card の生成箇所に書き換え例
    // ここはpreview用なので簡単に生成しています。
    // 実際のコードの中で初期化している箇所に書き換える場合の例：

    // let defaultCardColorHex: String = {
    //     let hex = sheet.backgroundColorHex.uppercased()
    //     return (hex == "#FFFFFF" || hex == "#F5F5DC") ? "#EBC299" : sheet.backgroundColorHex
    // }()
    // CardEditView(
    //     card: TravelCard(
    //         backgroundColorHex: defaultCardColorHex,
    //         textColorHex: "#000000"
    //     ),
    //     sheet: sheet
    // ) { updatedCard in
    //     model.addCard(updatedCard, to: sheet)
    //     showingNewCard = false
    // }

    CardEditView(card: TravelCard(), sheet: TravelSheet(title: "サンプル")) { _ in }
        .environmentObject(TravelDataModel())
}

