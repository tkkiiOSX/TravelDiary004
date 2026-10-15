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
    @State private var selectedCard: TravelCard? = nil
    @State private var showingCardDetail = false

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
                if let sheet = selectedSheet {
                    List {
                        Section {
                            VStack(alignment: .leading, spacing: 6) {
                                // Title row with navigation buttons
                                HStack {
                                    Button(action: {
                                        if let idx = model.sheets.firstIndex(where: { $0.id == sheet.id }) {
                                            let prev = (idx - 1 + model.sheets.count) % model.sheets.count
                                            selectedSheetID = model.sheets[prev].id
                                        }
                                    }) {
                                        Image(systemName: "chevron.left")
                                    }
                                    Text(sheet.title.isEmpty ? "無題のシート" : sheet.title)
                                        .font(.title2.weight(.semibold))
                                        .foregroundColor(sheet.titleTextColor)
                                        .multilineTextAlignment(.leading)
                                        .lineLimit(2)
                                        .minimumScaleFactor(0.6)
                                        .truncationMode(.middle)
                                        .allowsTightening(true)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.horizontal, 6)
                                        .padding(.top, 2)
                                    Spacer()
                                    Button(action: {
                                        if let idx = model.sheets.firstIndex(where: { $0.id == sheet.id }) {
                                            let next = (idx + 1) % model.sheets.count
                                            selectedSheetID = model.sheets[next].id
                                        }
                                    }) {
                                        Image(systemName: "chevron.right")
                                    }
                                }
                                // Period row (travel dates)
                                VStack(alignment: .leading, spacing: 2) {
                                    if let startDate = sheet.startDate, let endDate = sheet.endDate {
                                        Text("旅行日程: \(formattedDate(startDate)) 〜 \(formattedDate(endDate))")
                                            .font(.callout)
                                            .foregroundColor(sheet.travelDateTextColor)
                                            .padding()
                                    } else if let startDate = sheet.startDate {
                                        Text("旅行開始予定日: \(formattedDate(startDate))")
                                            .font(.callout)
                                            .foregroundColor(sheet.travelDateTextColor)
                                    } else if let endDate = sheet.endDate {
                                        Text("旅行終了予定日: \(formattedDate(endDate))")
                                            .font(.callout)
                                            .foregroundColor(sheet.travelDateTextColor)
                                    }
                                }
                                .padding(.bottom, 4)
                            }
                            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                            .padding(.bottom, 0)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(sheet.titleBackgroundColor.opacity(0.95))
                            )
                        }
                        .padding(.top, 5) // ← この数値をお好みで調整（例: 12, 16, 20 など）
                        .padding(.horizontal, 3) // ← ここを追加（左右の隙間を作る数値）
                        .listRowBackground(sheet.backgroundColor.opacity(0.08))

                        // Cards section with reordering support
                        Section {
                            if sheet.cards.isEmpty {
                                Text("カードがありません。新規作成してください。")
                                    .foregroundColor(.secondary)
                            } else {
                                ForEach(sheet.cards) { card in
                                    Button {
                                        selectedCard = card
                                        showingCardDetail = true
                                    } label: {
                                        CardDisplayView(card: card)
                                            .padding(.vertical, 0) // keep as 0
                                            .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                        Button(role: .destructive) {
                                            cardPendingDeletion = card
                                            showDeleteAlert = true
                                        } label: {
                                            Label("削除", systemImage: "trash")
                                        }
                                    }
                                    .listRowInsets(EdgeInsets(top: 0, leading: 1, bottom: 0, trailing: 1))
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
                    .listStyle(.plain)
                    .listSectionSpacing(2)
                    .scrollContentBackground(.hidden)
                    .background(sheet.backgroundColor)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Button {
                    showingNewCard = true
                } label: {
                    Image(systemName: "plus.circle")
                    Text("カード")
                }

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
                            backgroundColorHex: sheet.effectiveDefaultCardBackgroundColorHex,
                            textColorHex: sheet.effectiveDefaultCardTextColorHex
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
        .navigationDestination(isPresented: $showingCardDetail) {
            if let card = selectedCard, let sheet = selectedSheet {
                CardEditView(card: card, sheet: sheet) { updatedCard in
                    model.updateCard(updatedCard, in: sheet)
                }
            } else {
                Text("カードが見つかりません。")
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

private func formattedDate(_ date: Date?) -> String {
    guard let date else { return "未設定" }
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "ja_JP")
    formatter.dateStyle = .medium
    return formatter.string(from: date)
}



struct CardShadowModifier: ViewModifier {
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
