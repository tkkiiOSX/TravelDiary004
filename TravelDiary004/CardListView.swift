import SwiftUI
import MapKit

// --- ここから追加 ---
private struct ManualPageBreaksEditor: View {
    let sheet: TravelSheet
    @Binding var manualPageBreaks: Set<UUID>
    @Binding var cardScales: [UUID: Double]
    @Environment(\.dismiss) private var dismiss
    @State private var showManualPreview = false

    var body: some View {
        List {
            Section(footer: Text("自動改ページがOFFのとき有効です。チェックしたカードの直前で改ページします。")) {
                ForEach(sheet.cards) { card in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(card.title.isEmpty ? "無題のカード" : card.title)
                                    .font(.body)
                                if !card.memo.isEmpty {
                                    Text(card.memo)
                                        .font(.caption)
                                        .lineLimit(1)
                                        .foregroundColor(.secondary)
                                }
                            }
                            Spacer()
                            Toggle("改ページ", isOn: Binding(
                                get: { manualPageBreaks.contains(card.id) },
                                set: { newValue in
                                    if newValue { manualPageBreaks.insert(card.id) } else { manualPageBreaks.remove(card.id) }
                                }
                            ))
                            .labelsHidden()
                        }
                        // --- ここにスライダー ---
                        HStack(spacing: 12) {
                            Image(systemName: "arrow.left.and.right")
                                .foregroundColor(.accentColor)
                            Slider(
                                value: Binding(
                                    get: { cardScales[card.id] ?? 1.0 },
                                    set: { cardScales[card.id] = $0 }
                                ),
                                in: 0.25...1.0,
                                step: 0.01
                            )
                            Text("\(Int((cardScales[card.id] ?? 1.0) * 100))%")
                                .frame(width: 48, alignment: .trailing)
                                .font(.caption)
                        }
                        .padding(.leading, 32)
                    }
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showManualPreview = true
                } label: {
                    Label("PDFプレビュー（手動）", systemImage: "doc.text.magnifyingglass")
                }
            }
        }
        .sheet(isPresented: $showManualPreview) {
            PDFPreviewContainer(sheet: sheet, autoPaginate: false, manualPageBreaks: manualPageBreaks, cardScales: cardScales)
        }
    }
}
// --- ここまで追加 ---

struct CardListView: View {
    @EnvironmentObject var model: TravelDataModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedSheetID: UUID
    @State private var showingNewCard = false
    @State private var showPDFPreview = false
    @State private var showManualEditor = false
    @State private var lastHandledImportFeedbackID: UUID? = nil

    @State private var cardPendingDeletion: TravelCard? = nil
    @State private var showDeleteAlert = false

    @State private var manualPageBreaks: Set<UUID> = []
    @State private var manualCardScales: [UUID: Double] = [:]

    init(initialSheet: TravelSheet) {
        _selectedSheetID = State(initialValue: initialSheet.id)
    }

    private var selectedSheet: TravelSheet? {
        model.sheets.first(where: { $0.id == selectedSheetID })
    }

    var body: some View {
        Group {
            if model.sheets.isEmpty {
                Text("先にシートを追加してください。")
                    .foregroundColor(.secondary)
            } else {
                TabView(selection: $selectedSheetID) {
                    ForEach(model.sheets) { sheet in
                        List {
                            // Header section: title editor & color picker
                            Section {
                                VStack(alignment: .leading, spacing: 12) {
                                    TextField("シート名を入力", text: Binding(
                                        get: { sheet.title },
                                        set: { model.updateSheetTitle(sheetID: sheet.id, newTitle: $0) }
                                    ))
                                    .textFieldStyle(.roundedBorder)
                                    .font(.title2)
                                    .bold()

                                    ColorPicker("シート背景色", selection: Binding(get: { sheet.backgroundColor }, set: { newColor in
                                        model.updateSheetColor(sheetID: sheet.id, color: newColor)
                                    }), supportsOpacity: false)
                                }
                                .listRowBackground(sheet.backgroundColor.opacity(0.08))
                            }

                            // Cards section with reordering support
                            Section {
                                if sheet.cards.isEmpty {
                                    Text("カードがありません。新規作成してください。")
                                        .foregroundColor(.secondary)
                                } else {
                                    ForEach(sheet.cards) { card in
                                        NavigationLink(value: card) {
                                            CardDisplayView(card: card)
                                                .padding(.vertical, 8)
                                        }
                                        .listRowBackground(sheet.backgroundColor)
                                    }
                                    .onDelete { indexSet in
                                        if let index = indexSet.first {
                                            let pending = sheet.cards[index]
                                            cardPendingDeletion = pending
                                            showDeleteAlert = true
                                        }
                                    }
                                    .onMove { indices, newOffset in
                                        model.moveCards(in: sheet, from: indices, to: newOffset)
                                    }
                                }
                            }
                        }
                        .scrollContentBackground(.hidden)
                        .background(sheet.backgroundColor)
                        .tag(sheet.id)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .automatic))
            }
        }
        .navigationTitle(selectedSheet?.title ?? "カード表示")
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Button {
                    showingNewCard = true
                } label: {
                    Image(systemName: "plus.circle")
                    Text("カード")
                }

                /*Button {
                    showManualEditor = true
                } label: {
                    Image(systemName: "list.bullet.rectangle")
                    Text("印刷＆PDF（手動)")
                }*/

                Button {
                    showPDFPreview = true
                } label: {
                    Image(systemName: "printer")
                    Text("印刷＆PDF")
                }
                EditButton()
            }
        }
        .sheet(isPresented: $showingNewCard) {
            if let sheet = selectedSheet {
                NavigationStack {
                    CardEditView(
                        card: TravelCard(
                            backgroundColorHex: TravelCard.defaultCardBackgroundColorHex(for: sheet.backgroundColorHex),
                            textColorHex: TravelCard.defaultTextColorHex
                        ),
                        sheet: sheet
                    ) { updatedCard in
                        model.addCard(updatedCard, to: sheet)
                        showingNewCard = false
                    }
                }
            }
        }
        .sheet(isPresented: $showPDFPreview) {
            if let sheet = selectedSheet {
                PDFPreviewContainer(
                    sheet: sheet,
                    autoPaginate: true,
                    manualPageBreaks: sheet.manualPageBreaks,
                    cardScales: sheet.cardScales,
                    cardAlignments: sheet.cardAlignments
                )
            }
        }
        .sheet(isPresented: $showManualEditor) {
            if let sheet = selectedSheet {
                NavigationStack {
                    ManualPageBreaksEditor(sheet: sheet, manualPageBreaks: $manualPageBreaks, cardScales: $manualCardScales)
                        .navigationTitle("改ページの指定")
                }
            }
        }
        .navigationDestination(for: TravelCard.self) { card in
            if let sheet = selectedSheet {
                CardEditView(card: card, sheet: sheet) { updatedCard in
                    model.updateCard(updatedCard, in: sheet)
                }
            } else {
                Text("シートが見つかりません。")
                    .foregroundColor(.secondary)
            }
        }
        .alert("このカードを削除しますか？", isPresented: $showDeleteAlert, presenting: cardPendingDeletion) { pending in
            Button("削除", role: .destructive) {
                if let sheet = selectedSheet {
                    model.deleteCard(pending, from: sheet)
                }
                cardPendingDeletion = nil
            }
            Button("キャンセル", role: .cancel) {
                cardPendingDeletion = nil
            }
        } message: { pending in
            Text(pending.title.isEmpty ? "無題のカード" : pending.title)
        }
        .onChange(of: model.importFeedback?.id) { _, newValue in
            guard let newValue, lastHandledImportFeedbackID != newValue else { return }
            lastHandledImportFeedbackID = newValue
            dismiss()
        }
    }
}

private struct CardDisplayView: View {
    let card: TravelCard
    @State private var position: MapCameraPosition = .automatic

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
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
                    }
                    Spacer()
                }
            }

            if card.showDate {
                VStack(alignment: .leading, spacing: 2) {
                    Text(card.date, style: .date)
                        .font(.headline)
                        .foregroundColor(card.textColor)
                    Text(card.date, style: .time)
                        .font(.subheadline)
                        .foregroundColor(card.textColor.opacity(0.8))
                }
            }

            if !card.memo.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("メモ")
                        .font(.subheadline)
                        .foregroundColor(card.textColor.opacity(0.7))
                        .bold()
                    Text(card.memo)
                        .font(.body)
                        .foregroundColor(card.textColor)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if card.hasLocation {
                VStack(alignment: .leading, spacing: 6) {
                    Text("MAP")
                        .font(.subheadline)
                        .foregroundColor(card.textColor.opacity(0.7))
                        .bold()
                    ZStack {
                        GeometryReader { geo in
                            let side = min(geo.size.width, geo.size.height)
                            Map(position: $position) {
                                Marker(card.locationName.isEmpty ? "選択地点" : card.locationName,
                                       coordinate: CLLocationCoordinate2D(latitude: card.latitude, longitude: card.longitude))
                                    .tint(.red)
                            }
                            .mapStyle(.standard)
                            .allowsHitTesting(false)
                            .frame(width: side, height: side)
                            .cornerRadius(14)
                            .onAppear {
                                let region = MKCoordinateRegion(
                                    center: CLLocationCoordinate2D(latitude: card.latitude, longitude: card.longitude),
                                    span: MKCoordinateSpan(latitudeDelta: 0.08, longitudeDelta: 0.08)
                                )
                                position = .region(region)
                            }
                        }
                    }
                    .aspectRatio(1, contentMode: .fit)
                }
            }

            if let url = displayURL {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Web表示")
                        .font(.subheadline)
                        .foregroundColor(card.textColor.opacity(0.7))
                        .bold()
                    ZStack {
                        GeometryReader { geo in
                            let side = min(geo.size.width, geo.size.height)
                            WebView(url: url, allowNavigation: false)
                                .frame(width: side, height: side)
                                .cornerRadius(14)
                        }
                    }
                    .aspectRatio(1, contentMode: .fit)
                }
            }

            if let imageData = card.imageData,
               let uiImage = UIImage(data: imageData) {
                ZStack {
                    GeometryReader { geo in
                        let side = min(geo.size.width, geo.size.height)
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: side, height: side)
                            .clipped()
                            .cornerRadius(14)
                    }
                }
                .aspectRatio(1, contentMode: .fit)
            }

        }
        .padding()
        .background(
            ZStack {
                card.backgroundColor
                PatternOverlay(pattern: card.patternEffect, gradient: card.gradientEffect, baseColor: card.backgroundColor, patternColor: card.patternColor, opacity: card.patternOpacity)
            }
        )
        .foregroundColor(card.textColor)
        .cornerRadius(18)
        .modifier(CardBorderModifier(style: card.borderStyle, color: card.borderColor, lineWidth: CGFloat(card.borderWidth), radius: 18))
        .modifier(CardShadowModifier(enabled: card.showShadow))
    }

    private var displayURL: URL? {
        let trimmed = card.url.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if let url = URL(string: trimmed), url.scheme != nil {
            return url
        }
        return URL(string: "https://\(trimmed)")
    }
}

private struct CardShadowModifier: ViewModifier {
    let enabled: Bool
    func body(content: Content) -> some View {
        if enabled {
            content.shadow(color: Color.black.opacity(0.12), radius: 16, x: 0, y: 8)
        } else {
            content
        }
    }
}

private struct CardListViewPreviewProvider {
    static var model: TravelDataModel = {
        let model = TravelDataModel()
        model.addSheet(title: "サンプル旅行")
        return model
    }()
}

#Preview("カードリスト プレビュー") {
    CardListView(initialSheet: CardListViewPreviewProvider.model.sheets.first!).environmentObject(CardListViewPreviewProvider.model)
}
