import SwiftUI
import MapKit
import UIKit
import PDFKit
import WebKit
import ObjectiveC.runtime

private enum PrintConstants {
    static let a4PageSize = CGSize(width: 595.2, height: 841.8)
    static let pageMargins = UIEdgeInsets(top: 36, left: 36, bottom: 36, right: 36)
    static let headerCornerRadius: CGFloat = 10
    static let headerTitleFont = UIFont.systemFont(ofSize: 20, weight: .semibold)
    static let headerDateFont = UIFont.systemFont(ofSize: 14, weight: .regular)
    static let minimumBottomSpacing: CGFloat = 24
}

enum CardHorizontalAlignment: String, Hashable, CaseIterable {
    case leading
    case center
    case trailing
}
extension CardHorizontalAlignment {
    var title: String {
        switch self {
        case .leading: return "左"
        case .center: return "中央"
        case .trailing: return "右"
        }
    }
}

struct PrintLayoutView: View {
    let sheet: TravelSheet
    @EnvironmentObject var model: TravelDataModel
    @Environment(\.dismiss) private var dismiss
    @State private var showExportSheet = false
    @State private var showPDFPreview = false
    @State private var shareURL: URL? = nil
    @State private var pdfPreviewURL: URL? = nil
    @State private var exportError: String? = nil
    @State private var webSnapshots: [UUID: UIImage] = [:]
    @State private var manualPageBreaks: Set<UUID> = []
    @State private var cardScales: [UUID: Double] = [:]
    @State private var cardAlignments: [UUID: CardHorizontalAlignment] = [:]

    var body: some View {
        NavigationStack {
            if sheet.cards.isEmpty {
                emptyStateView
            } else {
                mainContentView
            }
        }
    }

    // 空状態表示
    @ViewBuilder
    private var emptyStateView: some View {
        Text("印刷用のカードがありません。")
            .foregroundColor(.secondary)
            .padding()
            .navigationTitle("改ページ設定")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
    }

    // メインコンテンツ表示
    @ViewBuilder
    private var mainContentView: some View {
        Group {
            pagesTabView
        }
        .navigationTitle(sheet.title.isEmpty ? "改ページ設定" : sheet.title)
        .toolbar { mainToolbar }
        .sheet(isPresented: $showExportSheet) { exportSheetContent }
        .sheet(isPresented: $showPDFPreview) { pdfPreviewSheet }
        .task { await loadSnapshots() }
        .onAppear {
            self.manualPageBreaks = sheet.manualPageBreaks
            self.cardScales = sheet.cardScales
            self.cardAlignments = sheet.cardAlignments
        }
        .onChange(of: manualPageBreaks) { _, newValue in
            model.updateManualSettings(for: sheet.id, manualPageBreaks: newValue, cardScales: cardScales, cardAlignments: cardAlignments)
        }
        .onChange(of: cardScales) { _, newValue in
            model.updateManualSettings(for: sheet.id, manualPageBreaks: manualPageBreaks, cardScales: newValue, cardAlignments: cardAlignments)
        }
        .onChange(of: cardAlignments) { _, newValue in
            model.updateManualSettings(for: sheet.id, manualPageBreaks: manualPageBreaks, cardScales: cardScales, cardAlignments: newValue)
        }
    }

    // ページタブ表示
    @ViewBuilder
    private var pagesTabView: some View {
        TabView {
            ForEach(sheet.cards) { card in
                PrintCardPage(card: card, mapSnapshot: nil, webSnapshot: webSnapshots[card.id])
                    .padding(16)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .automatic))
    }

    @ToolbarContentBuilder
    private var mainToolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .navigationBarTrailing) {
            Menu {
                NavigationLink {
                    PrintLayoutManualPageBreaksEditor(cards: sheet.cards, manualPageBreaks: $manualPageBreaks, cardAlignments: $cardAlignments, cardScales: $cardScales)
                        .navigationTitle("改ページ設定")
                } label: {
                    Label("改ページの指定…", systemImage: "list.bullet")
                }
            } label: {
                Label("設定", systemImage: "slider.horizontal.3")
            }

            Button(action: { Task { await previewPDF(autoPaginate: true) } }) {
                Label("PDFプレビュー（自動）", systemImage: "doc.text.magnifyingglass")
            }
            Button(action: { Task { await previewPDF(autoPaginate: false) } }) {
                Label("PDFプレビュー（手動）", systemImage: "doc.text.magnifyingglass")
            }
            Button(action: { Task { await exportPDF(autoPaginate: true) } }) {
                Label("印刷＆PDF", systemImage: "square.and.arrow.up")
            }
        }
        ToolbarItem(placement: .cancellationAction) {
            Button("閉じる") { dismiss() }
        }
    }

    // エクスポートシート内容
    @ViewBuilder
    private var exportSheetContent: some View {
        if let url = shareURL {
            ActivityView(activityItems: [url])
        } else {
            Text(exportError ?? "エクスポートに失敗しました。もう一度エクスポートボタンをタップして下さい。")
                .padding()
        }
    }

    // PDFプレビューシート内容
    @ViewBuilder
    private var pdfPreviewSheet: some View {
        if let url = pdfPreviewURL {
            NavigationStack {
                PDFPreviewView(url: url)
                    .navigationTitle("PDFプレビュー")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("閉じる") { showPDFPreview = false }
                        }
                    }
            }
        } else {
            Text(exportError ?? "プレビューの生成に失敗しました。もう一度プレビューボタンをタップして下さい。")
                .padding()
        }
    }

    // PDFエクスポート処理
    private func exportPDF(autoPaginate: Bool) async {
        let shouldAuto = autoPaginate && manualPageBreaks.isEmpty
        guard let data = await createPDFData(autoPaginate: shouldAuto, manualBreaks: manualPageBreaks) else {
            exportError = "PDFの作成に失敗しました。"
            showExportSheet = true
            return
        }
        guard let url = savePDFDataToTemporaryFile(data: data) else {
            exportError = "PDFファイルの保存に失敗しました。"
            showExportSheet = true
            return
        }
        shareURL = url
        exportError = nil
        showExportSheet = true
    }

    // PDFプレビュー処理
    private func previewPDF(autoPaginate: Bool) async {
        let shouldAuto = autoPaginate && manualPageBreaks.isEmpty
        guard let data = await createPDFData(autoPaginate: shouldAuto, manualBreaks: manualPageBreaks) else {
            exportError = "PDFの作成に失敗しました。"
            showPDFPreview = true
            return
        }
        guard let url = savePDFDataToTemporaryFile(data: data) else {
            exportError = "PDFファイルの保存に失敗しました。"
            showPDFPreview = true
            return
        }
        pdfPreviewURL = url
        exportError = nil
        showPDFPreview = true
    }

    private func makeHeaderStrings() -> (titleText: String, travelDateString: String) {
        let titleText = sheet.title.isEmpty ? "無題のシート" : sheet.title
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateStyle = .medium
        let travelDateString: String
        if let start = sheet.startDate, let end = sheet.endDate {
            travelDateString = "旅行日程: \(formatter.string(from: start)) 〜 \(formatter.string(from: end))"
        } else if let start = sheet.startDate {
            travelDateString = "旅行開始予定日: \(formatter.string(from: start))"
        } else if let end = sheet.endDate {
            travelDateString = "旅行終了予定日: \(formatter.string(from: end))"
        } else {
            travelDateString = "旅行日程未設定"
        }
        return (titleText, travelDateString)
    }

    // PDFデータ生成
    private func createPDFData(autoPaginate: Bool, manualBreaks: Set<UUID>) async -> Data? {
        let pageSize = PrintConstants.a4PageSize
        let margins = PrintConstants.pageMargins
        let contentWidth = pageSize.width - margins.left - margins.right
        let pageRect = CGRect(origin: .zero, size: pageSize)

        let (titleText, travelDateString) = makeHeaderStrings()
        let titleFont = PrintConstants.headerTitleFont
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: titleFont,
            .foregroundColor: UIColor(sheet.titleTextColor)
        ]
        let titleRect = NSString(string: titleText).boundingRect(
            with: CGSize(width: contentWidth - 24, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: titleAttributes,
            context: nil
        )
        let titleHeight = titleRect.height + 18

        let travelDateFont = PrintConstants.headerDateFont
        let travelDateAttributes: [NSAttributedString.Key: Any] = [
            .font: travelDateFont,
            .foregroundColor: UIColor(sheet.titleTextColor).withAlphaComponent(0.7)
        ]
        let travelDateRect = NSString(string: travelDateString).boundingRect(
            with: CGSize(width: contentWidth - 24, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: travelDateAttributes,
            context: nil
        )
        let travelDateHeight = travelDateRect.height + 4

        let printTitleOnAllPages = sheet.printTitleOnAllPages ?? true

        var mapSnapshots: [UUID: UIImage] = [:]
        var pageSnapshots: [UUID: UIImage] = [:]
        for card in sheet.cards {
            if card.hasLocation,
               let snapshot = await makeMapSnapshot(for: card, size: CGSize(width: contentWidth, height: contentWidth)) {
                mapSnapshots[card.id] = snapshot
            }
            if card.hasURL && card.printWebPage,
               let snapshot = await makeWebSnapshot(for: card, size: CGSize(width: contentWidth, height: contentWidth)) {
                pageSnapshots[card.id] = snapshot
            }
        }

        // Render each card to an image using PrintableCardView (variable height)
        var renderedCards: [(UUID, UIImage)] = []
        for card in sheet.cards {
            let view = PrintableCardView(card: card,
                                         mapSnapshot: mapSnapshots[card.id],
                                         webSnapshot: pageSnapshots[card.id],
                                         maxWidth: contentWidth)
            if let image = renderViewToImage(view: AnyView(view), width: contentWidth) {
                renderedCards.append((card.id, image))
            }
        }

        // Build PDF with either auto pagination or manual page breaks
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
        let data = renderer.pdfData { context in
            let contentHeight = pageSize.height - margins.top - margins.bottom
            var currentY: CGFloat = margins.top
            var remainingHeight: CGFloat = contentHeight
            var firstPage = true

            func drawHeaderIfNeeded() {
                // Draw sheet title header
                let headerRect = CGRect(x: margins.left, y: currentY, width: contentWidth, height: titleHeight + travelDateHeight)
                let roundedPath = UIBezierPath(roundedRect: headerRect, cornerRadius: PrintConstants.headerCornerRadius)
                UIColor(sheet.titleBackgroundColor).setFill()
                roundedPath.fill()

                // Draw the title text
                let textRect = CGRect(x: margins.left + 12, y: currentY + 9, width: contentWidth - 24, height: titleRect.height)
                NSString(string: titleText).draw(with: textRect, options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: titleAttributes, context: nil)

                // Draw the travel date text below the title
                let dateRect = CGRect(x: margins.left + 12, y: currentY + 9 + titleRect.height, width: contentWidth - 24, height: travelDateRect.height)
                NSString(string: travelDateString).draw(with: dateRect, options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: travelDateAttributes, context: nil)
            }

            func beginNewPage(printTitle: Bool = true) {
                context.beginPage()
                // Fill page background with sheet's background color
                let bgColor = UIColor(sheet.backgroundColor)
                bgColor.setFill()
                context.cgContext.fill(CGRect(origin: .zero, size: pageSize))

                currentY = margins.top
                remainingHeight = contentHeight

                if printTitle {
                    drawHeaderIfNeeded()
                    currentY += titleHeight + travelDateHeight + 12
                    remainingHeight -= titleHeight + travelDateHeight + 12
                }
            }

            // Start first page with title
            beginNewPage(printTitle: true)
            firstPage = false

            for (index, element) in renderedCards.enumerated() {
                let cardID = element.0
                let image = element.1

                let userScale = cardScales[cardID] ?? 1.0
                let originalWidth = image.size.width
                let originalHeight = image.size.height

                // Calculate max scales to fit content area
                let maxScaleX = contentWidth / originalWidth
                let maxScaleY = contentHeight / originalHeight
                let safeScale = min(userScale, maxScaleX, maxScaleY, 1.0)

                let drawWidth = originalWidth * safeScale
                let drawHeight = originalHeight * safeScale

                let alignment = cardAlignments[cardID] ?? .center
                let drawX: CGFloat
                switch alignment {
                case .center:
                    drawX = margins.left + (contentWidth - drawWidth) / 2
                case .trailing:
                    drawX = margins.left + (contentWidth - drawWidth)
                case .leading:
                    drawX = margins.left
                }

                if !autoPaginate {
                    // Manual mode: forced page break before this card
                    if manualBreaks.contains(cardID) && currentY != margins.top {
                        let shouldPrintTitle = printTitleOnAllPages ? true : firstPage
                        beginNewPage(printTitle: shouldPrintTitle)
                        firstPage = false
                    }
                    // If scaled image still doesn't fit in remaining space, move to new page
                    if drawHeight > remainingHeight {
                        let shouldPrintTitle = printTitleOnAllPages ? true : firstPage
                        beginNewPage(printTitle: shouldPrintTitle)
                        firstPage = false
                    }
                    image.draw(in: CGRect(x: drawX, y: currentY, width: drawWidth, height: drawHeight))
                    currentY += drawHeight
                    remainingHeight -= drawHeight
                    if remainingHeight < PrintConstants.minimumBottomSpacing && index < renderedCards.count - 1 {
                        let shouldPrintTitle = printTitleOnAllPages ? true : firstPage
                        beginNewPage(printTitle: shouldPrintTitle)
                        firstPage = false
                    }
                } else {
                    // Auto paginate: keep-together; scale down if necessary to fit a single page
                    if drawHeight > remainingHeight {
                        let shouldPrintTitle = printTitleOnAllPages ? true : firstPage
                        beginNewPage(printTitle: shouldPrintTitle)
                        firstPage = false
                    }
                    image.draw(in: CGRect(x: drawX, y: currentY, width: drawWidth, height: drawHeight))
                    currentY += drawHeight
                    remainingHeight -= drawHeight
                    if remainingHeight < PrintConstants.minimumBottomSpacing && index < renderedCards.count - 1 {
                        let shouldPrintTitle = printTitleOnAllPages ? true : firstPage
                        beginNewPage(printTitle: shouldPrintTitle)
                        firstPage = false
                    }
                }
            }
        }
        return data
    }

    // 地図スナップショット生成
    private func makeMapSnapshot(for card: TravelCard, size: CGSize) async -> UIImage? {
        guard card.hasLocation else { return nil }

        let options = MKMapSnapshotter.Options()
        let center = CLLocationCoordinate2D(latitude: card.latitude, longitude: card.longitude)
        let span = MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        let region = MKCoordinateRegion(center: center, span: span)
        options.region = region
        options.size = size
        options.scale = UIScreen.main.scale
        options.mapType = .standard

        return await withCheckedContinuation { continuation in
            MKMapSnapshotter(options: options).start { snapshot, error in
                guard let snapshot = snapshot else {
                    continuation.resume(returning: nil)
                    return
                }
                let baseImage = snapshot.image
                UIGraphicsBeginImageContextWithOptions(baseImage.size, true, baseImage.scale)
                baseImage.draw(at: .zero)

                // Compute point for the center coordinate
                let pinPoint = snapshot.point(for: center)
                let ctx = UIGraphicsGetCurrentContext()
                ctx?.saveGState()
                let radius: CGFloat = 6
                let pinRect = CGRect(x: pinPoint.x - radius, y: pinPoint.y - radius, width: radius * 2, height: radius * 2)
                // Outer white stroke
                ctx?.setFillColor(UIColor.red.cgColor)
                ctx?.setStrokeColor(UIColor.white.cgColor)
                ctx?.setLineWidth(2)
                ctx?.fillEllipse(in: pinRect)
                ctx?.strokeEllipse(in: pinRect)
                ctx?.restoreGState()

                let composed = UIGraphicsGetImageFromCurrentImageContext()
                UIGraphicsEndImageContext()
                continuation.resume(returning: composed)
            }
        }
    }

    // Webページスナップショット生成
    @MainActor
    private func makeWebSnapshot(for card: TravelCard, size: CGSize) async -> UIImage? {
        guard let url = makeURL(from: card.url) else { return nil }

        let webView = WKWebView(frame: CGRect(origin: .zero, size: size))
        let request = URLRequest(url: url)
        await withCheckedContinuation { continuation in
            class NavigationDelegate: NSObject, WKNavigationDelegate {
                static var associationKey: UInt8 = 0
                let continuation: CheckedContinuation<Void, Never>
                init(_ continuation: CheckedContinuation<Void, Never>) {
                    self.continuation = continuation
                }
                func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
                    continuation.resume(returning: ())
                }
                func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
                    continuation.resume(returning: ())
                }
                func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
                    continuation.resume(returning: ())
                }
            }

            let delegate = NavigationDelegate(continuation)
            objc_setAssociatedObject(webView, &NavigationDelegate.associationKey, delegate, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            webView.navigationDelegate = delegate
            webView.load(request)
        }

        let configuration = WKSnapshotConfiguration()
        configuration.rect = CGRect(origin: .zero, size: size)
        configuration.afterScreenUpdates = true

        return await withCheckedContinuation { continuation in
            DispatchQueue.main.async {
                webView.takeSnapshot(with: configuration) { image, _ in
                    continuation.resume(returning: image)
                }
            }
        }
    }

    // URL生成補助
    private func makeURL(from input: String) -> URL? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if let url = URL(string: trimmed), url.scheme != nil {
            return url
        }
        return URL(string: "https://\(trimmed)")
    }

    // スナップショット読み込み
    private func loadSnapshots() async {
        var snapshots: [UUID: UIImage] = [:]
        for card in sheet.cards where card.hasURL && card.printWebPage {
            if let snapshot = await makeWebSnapshot(for: card, size: CGSize(width: 280, height: 280)) {
                snapshots[card.id] = snapshot
            }
        }
        webSnapshots = snapshots
    }

    // カードページを画像化
    private func renderCardPageAsImage(card: TravelCard, size: CGSize, mapSnapshot: UIImage?, webSnapshot: UIImage?) -> UIImage? {
        let hostingController = UIHostingController(rootView: PrintCardPage(card: card, mapSnapshot: mapSnapshot, webSnapshot: webSnapshot)
            .frame(width: size.width, height: size.height)
            .background(ZStack {
                card.backgroundColor
                PatternOverlay(pattern: card.patternEffect, gradient: card.gradientEffect, baseColor: card.backgroundColor, patternColor: card.patternColor, opacity: card.patternOpacity)
            }))

        hostingController.view.bounds = CGRect(origin: .zero, size: size)
        hostingController.view.backgroundColor = UIColor.clear
        hostingController.view.setNeedsLayout()
        hostingController.view.layoutIfNeeded()

        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            hostingController.view.drawHierarchy(in: hostingController.view.bounds, afterScreenUpdates: true)
        }
    }

    // PDFデータを一時ファイルに保存
    private func savePDFDataToTemporaryFile(data: Data) -> URL? {
        let temporaryDirectory = FileManager.default.temporaryDirectory
        let fileName = "TravelDiary_Print_\(UUID().uuidString).pdf"
        let fileURL = temporaryDirectory.appendingPathComponent(fileName)
        do {
            try data.write(to: fileURL)
            return fileURL
        } catch {
            print("PDF save error: \(error)")
            return nil
        }
    }
}

// PrintCardPageの表示（mapPosition削除、init簡略化）
// 印刷用カードページ表示
struct PrintCardPage: View {
    let card: TravelCard
    let mapSnapshot: UIImage?
    let webSnapshot: UIImage?

    var body: some View {
        ZStack {
            ZStack {
                card.backgroundColor
                PatternOverlay(pattern: card.patternEffect, gradient: card.gradientEffect, baseColor: card.backgroundColor, patternColor: card.patternColor, opacity: card.patternOpacity)
            }
            GeometryReader { proxy in
                // Define sample page area with margins similar to PDF, but adaptive to preview size
                let availableWidth = proxy.size.width - 40
                let availableHeight = proxy.size.height - 40

                // Content width matches available width; height will be whatever PrintableCardView needs
                let contentWidth = max(100, availableWidth)

                // Build the unified printable card view (single card per page)
                let unifiedView = PrintableCardView(
                    card: card,
                    mapSnapshot: mapSnapshot,
                    webSnapshot: webSnapshot,
                    maxWidth: contentWidth
                )
                .background(ZStack {
                    card.backgroundColor
                    PatternOverlay(pattern: card.patternEffect, gradient: card.gradientEffect, baseColor: card.backgroundColor, patternColor: card.patternColor, opacity: card.patternOpacity)
                })
                .cornerRadius(20)
                // no shadow here per instructions

                // Use an offscreen measurement to determine natural height, then scale if needed
                IntrinsicSizeReader(content: unifiedView) { measuredSize in
                    let scaleY = availableHeight / max(1, measuredSize.height + 20)
                    let scaleX = availableWidth / max(1, measuredSize.width)
                    let scale = min(1.0, min(scaleX, scaleY))

                    return VStack {
                        unifiedView
                            .frame(width: contentWidth)
                            .scaleEffect(scale, anchor: .top)
                        Spacer(minLength: 0)
                    }
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .padding(20)
                    .background(Color(UIColor.secondarySystemGroupedBackground))
                }
            }
        }
    }
}

// コンテンツの自然サイズ測定表示
private struct IntrinsicSizeReader<Content: View, Overlay: View>: View {
    let content: Content
    let overlayBuilder: (CGSize) -> Overlay

    init(content: Content, @ViewBuilder overlayBuilder: @escaping (CGSize) -> Overlay) {
        self.content = content
        self.overlayBuilder = overlayBuilder
    }

    @State private var size: CGSize = .zero

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Hidden measurement view
            content
                .fixedSize(horizontal: false, vertical: true)
                .background(
                    GeometryReader { geo in
                        Color.clear
                            .preference(key: SizePreferenceKey.self, value: geo.size)
                    }
                )
                .opacity(0.001)

            // Visible overlay built with measured size
            overlayBuilder(size)
        }
        .onPreferenceChange(SizePreferenceKey.self) { newSize in
            self.size = newSize
        }
    }
}

private struct SizePreferenceKey: PreferenceKey {
    static var defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        value = nextValue()
    }
}

#Preview {
    let model = TravelDataModel()
    model.addSheet(title: "サンプル旅行")
    let card = TravelCard(memo: "長めのメモを印刷レイアウトで確認します。", locationName: "東京タワー", address: "東京都港区芝公園4-2-8", latitude: 35.6586, longitude: 139.7454, url: "https://www.tokyotower.co.jp/", category: "観光", showDate: true)
    var sheet = TravelSheet(title: "サンプルシート")
    sheet.cards = [card]
    return PrintLayoutView(sheet: sheet).environmentObject(TravelDataModel())
}
