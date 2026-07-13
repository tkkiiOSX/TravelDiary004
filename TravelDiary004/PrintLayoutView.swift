import SwiftUI
import MapKit
import UIKit
import PDFKit
import WebKit
import ObjectiveC.runtime

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
    @State private var exportURL: URL? = nil
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

    @ViewBuilder
    private var mainContentView: some View {
        Group {
            pagesTabView
        }
        .navigationTitle("改ページ設定")
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

    @ViewBuilder
    private var pagesTabView: some View {
        TabView {
            ForEach(sheet.cards) { card in
                PrintCardPage(card: card, webSnapshot: webSnapshots[card.id])
                    .padding(16)
                    .tag(card.id)
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
            Button(action: { Task { await previewPDF(autoPaginate: true) } }) {
                Label("印刷＆PDF", systemImage: "square.and.arrow.up")
            }
        }
        ToolbarItem(placement: .cancellationAction) {
            Button("閉じる") { dismiss() }
        }
    }

    @ViewBuilder
    private var exportSheetContent: some View {
        if let url = exportURL {
            ActivityView(activityItems: [url])
        } else {
            Text(exportError ?? "エクスポートに失敗しました。もう一度エクスポートボタンをタップして下さい。")
                .padding()
        }
    }

    @ViewBuilder
    private var pdfPreviewSheet: some View {
        if let url = pdfPreviewURL {
            NavigationStack {
                PDFPreviewView(url: url)
                    .navigationTitle("PDFプレビュー")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("閉じる") { showPDFPreview = false }
                        }
                    }
            }
        } else {
            Text(exportError ?? "プレビューの生成に失敗しました。もう一度プレビューボタンをタップして下さい。")
                .padding()
        }
    }

    private func exportPDF(autoPaginate: Bool) async {
        guard let data = await createPDFData(autoPaginate: autoPaginate && manualPageBreaks.isEmpty, manualBreaks: manualPageBreaks) else {
            exportError = "PDFの作成に失敗しました。"
            showExportSheet = true
            return
        }
        guard let url = savePDFDataToTemporaryFile(data: data) else {
            exportError = "PDFファイルの保存に失敗しました。"
            showExportSheet = true
            return
        }
        exportURL = url
        exportError = nil
        showExportSheet = true
    }

    private func previewPDF(autoPaginate: Bool) async {
        guard let data = await createPDFData(autoPaginate: autoPaginate && manualPageBreaks.isEmpty, manualBreaks: manualPageBreaks) else {
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

    private func createPDFData(autoPaginate: Bool, manualBreaks: Set<UUID>) async -> Data? {
        // Reuse the robust generator in PDFPreviewContainer by constructing the same inputs and applying pagination settings
        let pageSize = CGSize(width: 595.2, height: 841.8)
        let margins = UIEdgeInsets(top: 36, left: 36, bottom: 36, right: 36)
        let contentWidth = pageSize.width - margins.left - margins.right
        let pageRect = CGRect(origin: .zero, size: pageSize)

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

            func beginNewPage() {
                context.beginPage()
                // Fill page background with sheet's background color
                let bgColor = UIColor(sheet.backgroundColor)
                bgColor.setFill()
                context.cgContext.fill(CGRect(origin: .zero, size: pageSize))

                currentY = margins.top
                remainingHeight = contentHeight
            }

            // Start first page
            beginNewPage()

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
                        beginNewPage()
                    }
                    // If scaled image still doesn't fit in remaining space, move to new page
                    if drawHeight > remainingHeight {
                        beginNewPage()
                    }
                    image.draw(in: CGRect(x: drawX, y: currentY, width: drawWidth, height: drawHeight))
                    currentY += drawHeight
                    remainingHeight -= drawHeight
                    if remainingHeight < 24 && index < renderedCards.count - 1 { beginNewPage() }
                } else {
                    // Auto paginate: keep-together; scale down if necessary to fit a single page
                    if drawHeight > remainingHeight {
                        beginNewPage()
                    }
                    image.draw(in: CGRect(x: drawX, y: currentY, width: drawWidth, height: drawHeight))
                    currentY += drawHeight
                    remainingHeight -= drawHeight
                    if remainingHeight < 24 && index < renderedCards.count - 1 { beginNewPage() }
                }
            }
        }
        return data
    }

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
            webView.takeSnapshot(with: configuration) { image, error in
                continuation.resume(returning: image)
            }
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

    private func loadSnapshots() async {
        var snapshots: [UUID: UIImage] = [:]
        for card in sheet.cards where card.hasURL && card.printWebPage {
            if let snapshot = await makeWebSnapshot(for: card, size: CGSize(width: 280, height: 280)) {
                snapshots[card.id] = snapshot
            }
        }
        webSnapshots = snapshots
    }

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

struct PrintCardPage: View {
    let card: TravelCard
    let mapSnapshot: UIImage?
    let webSnapshot: UIImage?
    @State private var mapPosition: MapCameraPosition

    init(card: TravelCard, mapSnapshot: UIImage? = nil, webSnapshot: UIImage? = nil) {
        self.card = card
        self.mapSnapshot = mapSnapshot
        self.webSnapshot = webSnapshot
        if card.hasLocation {
            let region = MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: card.latitude, longitude: card.longitude),
                span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
            )
            _mapPosition = State(initialValue: .region(region))
        } else {
            _mapPosition = State(initialValue: .automatic)
        }
    }

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
                    .onAppear { updateMapPosition() }
                    .onChange(of: card.latitude) { _, _ in updateMapPosition() }
                    .onChange(of: card.longitude) { _, _ in updateMapPosition() }
                }
            }
        }
    }

    private func updateMapPosition() {
        guard card.hasLocation else { return }
        let region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: card.latitude, longitude: card.longitude),
            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        )
        mapPosition = .region(region)
    }
}

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
                .hidden()

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
