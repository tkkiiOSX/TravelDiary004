import SwiftUI
import PhotosUI
import MapKit

private struct CardStyleEditorSheet: View {
    @Binding var card: TravelCard
    @Environment(\.dismiss) private var dismiss

    private var backgroundColorBinding: Binding<Color> {
        colorBinding(
            get: { card.backgroundColor },
            setHex: { card.backgroundColorHex = $0 },
            defaultHex: TravelCard.defaultBackgroundColorHex
        )
    }

    private var textColorBinding: Binding<Color> {
        colorBinding(
            get: { card.textColor },
            setHex: { card.textColorHex = $0 },
            defaultHex: TravelCard.defaultTextColorHex
        )
    }

    private var patternColorBinding: Binding<Color> {
        colorBinding(
            get: { card.patternColor },
            setHex: { card.patternColorHex = $0 },
            defaultHex: TravelCard.defaultPatternColorHex
        )
    }

    private var borderColorBinding: Binding<Color> {
        colorBinding(
            get: { card.borderColor },
            setHex: { card.borderColorHex = $0 },
            defaultHex: TravelCard.defaultBorderColorHex
        )
    }

    private var patternOpacityBinding: Binding<Double> {
        Binding(
            get: { card.patternOpacity },
            set: { card.patternOpacity = min(max($0, 0.0), 1.0) }
        )
    }

    private var borderWidthBinding: Binding<Double> {
        Binding(
            get: { card.borderWidth },
            set: { card.borderWidth = min(max($0, 1.0), 8.0) }
        )
    }

    private var borderStyleBinding: Binding<CardBorderStyle> {
        Binding(
            get: { card.borderStyle },
            set: { card.borderStyle = $0 }
        )
    }

    private func colorBinding(
        get: @escaping () -> Color,
        setHex: @escaping (String) -> Void,
        defaultHex: String
    ) -> Binding<Color> {
        Binding(
            get: get,
            set: { color in
                setHex(UIColor(color).toHexString() ?? defaultHex)
            }
        )
    }

    var body: some View {
        NavigationView {
            Form {
                Section("プレビュー") {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .center, spacing: 8) {
                            if let icon = card.iconName(), !icon.isEmpty {
                                Image(systemName: icon)
                                    .font(.title)
                                    .foregroundColor(card.textColor)
                            }
                            if !card.title.isEmpty {
                                Text(card.title)
                                    .font(.subheadline)
                                    .foregroundColor(card.textColor)
                                    .bold()
                            } else {
                                Text("カードタイトル")
                                    .font(.subheadline)
                                    .foregroundColor(card.textColor.opacity(0.6))
                            }
                            Spacer()
                        }

                        if card.showDate {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(card.displayDateString)
                                    .font(.subheadline)
                                    .foregroundColor(card.textColor)
                                    .bold()
                            }
                        }
                        if card.showTime {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(card.displayTimeString)
                                    .font(.caption)
                                    .foregroundColor(card.textColor.opacity(0.8))
                            }
                        }

                        if !card.memo.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("メモ")
                                    .font(.caption)
                                    .foregroundColor(card.textColor.opacity(0.7))
                                    .bold()
                                Text(card.memo)
                                    .font(.caption)
                                    .foregroundColor(card.textColor)
                                    .lineLimit(2)
                            }
                        } else {
                            Text("メモサンプル")
                                .font(.caption)
                                .foregroundColor(card.textColor.opacity(0.5))
                        }
                    }
                    .padding()
                    .background(
                        ZStack {
                            card.backgroundColor
                            PatternOverlay(pattern: card.patternEffect, gradient: card.gradientEffect, baseColor: card.backgroundColor, patternColor: card.patternColor, opacity: card.patternOpacity)
                        }
                    )
                    .cornerRadius(12)
                    .modifier(CardBorderModifier(style: card.borderStyle, color: card.borderColor, lineWidth: CGFloat(card.borderWidth), radius: 12))
                }

                Section("カード色") {
                    ColorPicker("背景色", selection: backgroundColorBinding, supportsOpacity: false)
                    ColorPicker("文字色", selection: textColorBinding, supportsOpacity: false)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("背景効果（パターン）")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Picker("背景効果（パターン）", selection: Binding(get: { card.patternEffect }, set: { card.patternEffect = $0 })) {
                            ForEach(PatternEffect.allCases) { effect in
                                Text(effect.displayName).tag(effect)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text("柄の色")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        ColorPicker("柄の色", selection: patternColorBinding, supportsOpacity: false)
                        if card.hasPatternColorConflict && card.patternEffect != .none {
                            Text("柄の色が背景色と同じです。別の色を選択してください。")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text("柄の透明度")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        HStack(spacing: 12) {
                            Slider(value: patternOpacityBinding, in: 0.0...1.0, step: 0.01)
                            Text("\(Int((card.patternOpacity * 100).rounded()))%")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .frame(width: 48, alignment: .trailing)
                        }
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text("グラデーション")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Picker("グラデーション", selection: Binding(get: { card.gradientEffect }, set: { card.gradientEffect = $0 })) {
                            Text("なし").tag(GradientEffect.none)
                            Text("左右").tag(GradientEffect.horizontal)
                            Text("上下").tag(GradientEffect.vertical)
                        }
                        .pickerStyle(.segmented)
                    }
                }

                Section("効果/影") {
                    Toggle("カードにシャドウを付ける", isOn: $card.showShadow)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("枠線")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        Picker("枠線の種類", selection: borderStyleBinding) {
                            ForEach(CardBorderStyle.allCases) { style in
                                Text(style.displayName).tag(style)
                            }
                        }
                        .pickerStyle(.segmented)

                        ColorPicker("枠線の色", selection: borderColorBinding, supportsOpacity: false)

                        HStack(spacing: 12) {
                            Slider(value: borderWidthBinding, in: 1.0...8.0, step: 1.0)
                            Text("\(Int(card.borderWidth.rounded())) pt")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .frame(width: 54, alignment: .trailing)
                        }
                    }
                }
            }
            .environment(\.locale, Locale(identifier: "ja_JP"))
            .navigationTitle("カードのスタイル編集")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") {
                        dismiss()
                    }
                }
            }
        }
    }
}

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

    private var backgroundColorBinding: Binding<Color> {
        colorBinding(
            get: { card.backgroundColor },
            setHex: { card.backgroundColorHex = $0 },
            defaultHex: TravelCard.defaultBackgroundColorHex
        )
    }

    private var textColorBinding: Binding<Color> {
        colorBinding(
            get: { card.textColor },
            setHex: { card.textColorHex = $0 },
            defaultHex: TravelCard.defaultTextColorHex
        )
    }

    private var patternColorBinding: Binding<Color> {
        colorBinding(
            get: { card.patternColor },
            setHex: { card.patternColorHex = $0 },
            defaultHex: TravelCard.defaultPatternColorHex
        )
    }

    private var borderColorBinding: Binding<Color> {
        colorBinding(
            get: { card.borderColor },
            setHex: { card.borderColorHex = $0 },
            defaultHex: TravelCard.defaultBorderColorHex
        )
    }

    private var patternOpacityBinding: Binding<Double> {
        Binding(
            get: { card.patternOpacity },
            set: { card.patternOpacity = min(max($0, 0.0), 1.0) }
        )
    }

    private var borderWidthBinding: Binding<Double> {
        Binding(
            get: { card.borderWidth },
            set: { card.borderWidth = min(max($0, 1.0), 8.0) }
        )
    }

    private var borderStyleBinding: Binding<CardBorderStyle> {
        Binding(
            get: { card.borderStyle },
            set: { card.borderStyle = $0 }
        )
    }

    private func colorBinding(
        get: @escaping () -> Color,
        setHex: @escaping (String) -> Void,
        defaultHex: String
    ) -> Binding<Color> {
        Binding(
            get: get,
            set: { color in
                setHex(UIColor(color).toHexString() ?? defaultHex)
            }
        )
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
                Toggle("日付を表示", isOn: $card.showDate)
                    .toggleStyle(.switch)
                Toggle("時刻を表示", isOn: $card.showTime)
                    .toggleStyle(.switch)
                if card.showDate {
                    DatePicker("日付", selection: $card.date, displayedComponents: [.date])
                }
                if card.showTime {
                    DatePicker("時刻", selection: $card.time, displayedComponents: [.hourAndMinute])
                }
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
            Section("カード色") {
                Button {
                    showStyleEditor = true
                } label: {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .center, spacing: 8) {
                            if let icon = card.iconName(), !icon.isEmpty {
                                Image(systemName: icon)
                                    .font(.title)
                                    .foregroundColor(card.textColor)
                            }
                            if !card.title.isEmpty {
                                Text(card.title)
                                    .font(.subheadline)
                                    .foregroundColor(card.textColor)
                                    .bold()
                            } else {
                                Text("カードタイトル")
                                    .font(.subheadline)
                                    .foregroundColor(card.textColor.opacity(0.6))
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                        }

                        if card.showDate {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(card.displayDateString)
                                    .font(.subheadline)
                                    .foregroundColor(card.textColor)
                                    .bold()
                            }
                        }
                        if card.showTime {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(card.displayTimeString)
                                    .font(.caption)
                                    .foregroundColor(card.textColor.opacity(0.8))
                            }
                        }

                        if !card.memo.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("メモ")
                                    .font(.caption)
                                    .foregroundColor(card.textColor.opacity(0.7))
                                    .bold()
                                Text(card.memo)
                                    .font(.caption)
                                    .foregroundColor(card.textColor)
                                    .lineLimit(2)
                            }
                        } else {
                            Text("メモサンプル")
                                .font(.caption)
                                .foregroundColor(card.textColor.opacity(0.5))
                        }
                    }
                    .padding()
                    .background(
                        ZStack {
                            card.backgroundColor
                            PatternOverlay(pattern: card.patternEffect, gradient: card.gradientEffect, baseColor: card.backgroundColor, patternColor: card.patternColor, opacity: card.patternOpacity)
                        }
                    )
                    .cornerRadius(12)
                    .modifier(CardBorderModifier(style: card.borderStyle, color: card.borderColor, lineWidth: CGFloat(card.borderWidth), radius: 12))
                }
                .buttonStyle(.plain)
            }
        }
        .environment(\.locale, Locale(identifier: "ja_JP"))
        .navigationTitle(sheet.title)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("OK") {
                    if card.hasLowColorContrast {
                        showColorAlert = true
                    } else if card.hasPatternColorConflict && card.patternEffect != .none {
                        showPatternColorAlert = true
                    } else {
                        saveAndDismiss()
                    }
                }
            }
        }
        .alert("色の判別が困難です", isPresented: $showColorAlert) {
            Button("戻る", role: .cancel) {}
        } message: {
            Text("背景色と文字色が似すぎています。別の色を選択してください。")
        }
        .alert("柄色が背景色と同じです", isPresented: $showPatternColorAlert) {
            Button("戻る", role: .cancel) {}
        } message: {
            Text("柄の色が背景色と一致しています。柄が見えにくくなるため、別の色を選択してください。")
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
        .sheet(isPresented: $showStyleEditor) {
            CardStyleEditorSheet(card: $card)
                .presentationDetents([.large])
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

