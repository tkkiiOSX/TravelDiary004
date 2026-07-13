import SwiftUI
import MapKit
import UIKit
import PDFKit
import WebKit
import ObjectiveC.runtime

struct PDFPreviewView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.document = PDFDocument(url: url)
        return pdfView
    }

    func updateUIView(_ uiView: PDFView, context: Context) {
        if uiView.document?.documentURL != url {
            uiView.document = PDFDocument(url: url)
        }
    }
}

struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
        controller.excludedActivityTypes = [.assignToContact, .saveToCameraRoll, .addToReadingList]
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
    }
}

struct PDFPreviewContainer: View {
    let sheet: TravelSheet
    let autoPaginate: Bool
    let manualPageBreaks: Set<UUID>
    let cardScales: [UUID: Double]
    let cardAlignments: [UUID: CardHorizontalAlignment]
    @EnvironmentObject var model: TravelDataModel
    @Environment(\.dismiss) private var dismiss
    @State private var pdfURL: URL? = nil
    @State private var showShare = false
    @State private var errorMessage: String? = nil
    @State private var mapSnapshots: [UUID: UIImage] = [:]
    @State private var webSnapshots: [UUID: UIImage] = [:]

    @State private var autoPaginateState: Bool = true
    @State private var showSettings = false
    @State private var manualPageBreaksState: Set<UUID> = []
    @State private var cardAlignmentsState: [UUID: CardHorizontalAlignment] = [:]
    @State private var cardScalesState: [UUID: Double] = [:]

    init(sheet: TravelSheet, autoPaginate: Bool = true, manualPageBreaks: Set<UUID> = [], cardScales: [UUID: Double] = [:], cardAlignments: [UUID: CardHorizontalAlignment] = [:]) {
        self.sheet = sheet
        self.autoPaginate = autoPaginate
        self.manualPageBreaks = manualPageBreaks
        self.cardScales = cardScales
        self.cardAlignments = cardAlignments

        _autoPaginateState = State(initialValue: autoPaginate)
        _manualPageBreaksState = State(initialValue: manualPageBreaks)
        _cardAlignmentsState = State(initialValue: cardAlignments)
        _cardScalesState = State(initialValue: cardScales)
    }

    var body: some View {
        Group {
            if let url = pdfURL {
                NavigationStack {
                    PDFPreviewView(url: url)
                        .navigationTitle("PDFプレビュー")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Button {
                                    showShare = true
                                } label: {
                                    Label("共有", systemImage: "square.and.arrow.up")
                                }
                            }
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Button {
                                    showSettings = true
                                } label: {
                                    Label("改ページの設定", systemImage: "slider.horizontal.3")
                                }
                            }
                            ToolbarItem(placement: .cancellationAction) {
                                Button("閉じる") {
                                    dismiss()
                                }
                            }
                        }
                        .sheet(isPresented: $showShare) {
                            ActivityView(activityItems: [url])
                        }
                        .sheet(isPresented: $showSettings) {
                            NavigationStack {
                                PrintLayoutManualPageBreaksEditor(
                                    cards: sheet.cards,
                                    manualPageBreaks: $manualPageBreaksState,
                                    cardAlignments: $cardAlignmentsState,
                                    cardScales: $cardScalesState
                                )
                                .navigationTitle("改ページ設定")
                                .toolbar {
                                    ToolbarItem(placement: .cancellationAction) {
                                        Button("閉じる") {
                                            showSettings = false
                                            Task { await generatePDF() }
                                        }
                                    }
                                }
                            }
                        }
                }
            } else if let message = errorMessage {
                VStack(spacing: 16) {
                    Text(message)
                        .padding()
                    Button("閉じる") { dismiss() }
                }
            } else {
                ProgressView("PDFを生成中…")
                    .task {
                        await prepareSnapshots()
                        await generatePDF()
                    }
            }
        }
        .onChange(of: manualPageBreaksState) { _, newValue in
            model.updateManualSettings(for: sheet.id, manualPageBreaks: newValue, cardScales: cardScalesState, cardAlignments: cardAlignmentsState)
            Task { await generatePDF() }
        }
        .onChange(of: cardAlignmentsState) { _, newValue in
            model.updateManualSettings(for: sheet.id, manualPageBreaks: manualPageBreaksState, cardScales: cardScalesState, cardAlignments: newValue)
            Task { await generatePDF() }
        }
        .onChange(of: autoPaginateState) { _, _ in
            Task { await generatePDF() }
        }
        .onChange(of: cardScalesState) { _, newValue in
            model.updateManualSettings(for: sheet.id, manualPageBreaks: manualPageBreaksState, cardScales: newValue, cardAlignments: cardAlignmentsState)
            Task { await generatePDF() }
        }
    }

    private func prepareSnapshots() async {
        var mapDict: [UUID: UIImage] = [:]
        var webDict: [UUID: UIImage] = [:]
        let mapSize = CGSize(width: 560, height: 560)
        let webSize = CGSize(width: 560, height: 560)
        for card in sheet.cards {
            if card.hasLocation {
                if let img = await makeMapSnapshot(for: card, size: mapSize) {
                    mapDict[card.id] = img
                }
            }
            if card.hasURL && card.printWebPage {
                if let img = await makeWebSnapshot(for: card, size: webSize) {
                    webDict[card.id] = img
                }
            }
        }
        mapSnapshots = mapDict
        webSnapshots = webDict
    }

    private func generatePDF() async {
        let pageSize = CGSize(width: 595.2, height: 841.8)
        let margins = UIEdgeInsets(top: 36, left: 36, bottom: 36, right: 36)
        let contentWidth = pageSize.width - margins.left - margins.right
        let contentHeight = pageSize.height - margins.top - margins.bottom
        let pageRect = CGRect(origin: .zero, size: pageSize)

        var renderedCards: [(cardID: UUID, image: UIImage)] = []
        for card in sheet.cards {
            let view = PrintableCardView(
                card: card,
                mapSnapshot: mapSnapshots[card.id],
                webSnapshot: webSnapshots[card.id],
                maxWidth: contentWidth
            )
            if let image = renderViewToImage(view: AnyView(view), width: contentWidth) {
                renderedCards.append((card.id, image))
            }
        }

        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
        let data = renderer.pdfData { context in
            var remainingHeight = contentHeight
            var currentY: CGFloat = margins.top

            func beginNewPage() {
                context.beginPage()
                UIColor(sheet.backgroundColor).setFill()
                context.cgContext.fill(CGRect(origin: .zero, size: pageSize))
                remainingHeight = contentHeight
                currentY = margins.top
            }

            beginNewPage()
            let effectiveAutoPaginate = autoPaginateState && manualPageBreaksState.isEmpty

            for (index, element) in renderedCards.enumerated() {
                let cardID = element.cardID
                let image = element.image

                let userScale = cardScalesState[cardID] ?? 1.0
                let originalWidth = image.size.width
                let originalHeight = image.size.height
                let maxScaleX = contentWidth / originalWidth
                let maxScaleY = contentHeight / originalHeight
                let safeScale = min(userScale, maxScaleX, maxScaleY, 1.0)

                let drawWidth = originalWidth * safeScale
                let drawHeight = originalHeight * safeScale

                let alignment = cardAlignmentsState[cardID] ?? .center
                let drawX: CGFloat
                switch alignment {
                case .center:
                    drawX = margins.left + (contentWidth - drawWidth) / 2
                case .trailing:
                    drawX = margins.left + (contentWidth - drawWidth)
                case .leading:
                    drawX = margins.left
                }

                if !effectiveAutoPaginate {
                    if manualPageBreaksState.contains(cardID) && currentY != margins.top {
                        beginNewPage()
                    }
                    if drawHeight > remainingHeight {
                        beginNewPage()
                    }
                    image.draw(in: CGRect(x: drawX, y: currentY, width: drawWidth, height: drawHeight))
                    currentY += drawHeight
                    remainingHeight -= drawHeight
                    if remainingHeight < 24 && index < renderedCards.count - 1 {
                        beginNewPage()
                    }
                } else {
                    if drawHeight > remainingHeight {
                        beginNewPage()
                    }
                    image.draw(in: CGRect(x: drawX, y: currentY, width: drawWidth, height: drawHeight))
                    currentY += drawHeight
                    remainingHeight -= drawHeight
                    if remainingHeight < 24 && index < renderedCards.count - 1 {
                        beginNewPage()
                    }
                }
            }
        }

        if let url = savePDFDataToTemporaryFile(data: data) {
            pdfURL = url
        } else {
            errorMessage = "PDFファイルの保存に失敗しました。"
        }
    }
}

struct PrintableCardView: View {
    let card: TravelCard
    let mapSnapshot: UIImage?
    let webSnapshot: UIImage?
    let maxWidth: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
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

            if card.hasLocation && card.printLocation {
                VStack(alignment: .leading, spacing: 6) {
                    Text("MAP")
                        .font(.subheadline)
                        .foregroundColor(card.textColor.opacity(0.7))
                        .bold()
                    if let snapshot = mapSnapshot {
                        SquareContainer(size: maxWidth - 32) {
                            Image(uiImage: snapshot)
                                .resizable()
                                .scaledToFill()
                                .clipped()
                        }
                        .cornerRadius(14)
                    }
                }
            }

            if card.hasURL && card.printWebPage {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Web表示")
                        .font(.subheadline)
                        .foregroundColor(card.textColor.opacity(0.7))
                        .bold()
                    if let webImage = webSnapshot {
                        SquareContainer(size: maxWidth - 32) {
                            Image(uiImage: webImage)
                                .resizable()
                                .scaledToFill()
                                .clipped()
                        }
                        .cornerRadius(14)
                    }
                }
            }

            if card.printPhoto, let data = card.imageData, let uiImage = UIImage(data: data) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("写真")
                        .font(.headline)
                        .foregroundColor(card.textColor.opacity(0.7))
                        .bold()
                    SquareContainer(size: maxWidth - 32) {
                        let isLandscape = uiImage.size.width >= uiImage.size.height
                        Group {
                            if isLandscape {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFill()
                                    .clipped()
                            } else {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFit()
                            }
                        }
                    }
                    .cornerRadius(14)
                }
            }
        }
        .padding()
        .background(ZStack {
            card.backgroundColor
            PatternOverlay(pattern: card.patternEffect, gradient: card.gradientEffect, baseColor: card.backgroundColor, patternColor: card.patternColor, opacity: card.patternOpacity)
        })
        .cornerRadius(18)
        .modifier(CardBorderModifier(style: card.borderStyle, color: card.borderColor, lineWidth: CGFloat(card.borderWidth), radius: 18))
        .modifier(CardShadowModifier(enabled: card.showShadow))
    }
}

struct SquareContainer<Content: View>: View {
    let size: CGFloat?
    let content: () -> Content

    init(size: CGFloat? = nil, @ViewBuilder content: @escaping () -> Content) {
        self.size = size
        self.content = content
    }

    var body: some View {
        Group {
            if let s = size {
                ZStack { content() }
                    .frame(width: s, height: s)
            } else {
                GeometryReader { geo in
                    let s = geo.size.width
                    ZStack { content() }
                        .frame(width: s, height: s)
                }
                .frame(maxWidth: .infinity)
                .aspectRatio(1, contentMode: .fit)
            }
        }
    }
}

struct CardBorderModifier: ViewModifier {
    let style: CardBorderStyle
    let color: Color
    let lineWidth: CGFloat
    let radius: CGFloat

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        return content
            .clipShape(shape)
            .overlay {
                switch style {
                case .none:
                    EmptyView()
                case .single:
                    shape.stroke(color, lineWidth: lineWidth)
                case .double:
                    ZStack {
                        shape.stroke(color, lineWidth: lineWidth)
                        shape.inset(by: lineWidth * 1.8).stroke(color, lineWidth: lineWidth)
                    }
                }
            }
    }
}

struct PrintLayoutManualPageBreaksEditor: View {
    let cards: [TravelCard]
    @Binding var manualPageBreaks: Set<UUID>
    @Binding var cardAlignments: [UUID: CardHorizontalAlignment]
    @Binding var cardScales: [UUID: Double]
    @State private var showResetAlert = false

    var body: some View {
        List {
            Section(footer: VStack(alignment: .leading, spacing: 4) {
                Text("自動改ページがOFFのとき有効です。チェックしたカードの直前で改ページします。")
                Text("各カードの配置（左/中央/右）はPDFに反映されます。").foregroundColor(.secondary)
            }) {
                ForEach(cards) { card in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .center) {
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
                            Spacer(minLength: 8)
                            Toggle("改ページ", isOn: Binding(
                                get: { manualPageBreaks.contains(card.id) },
                                set: { newValue in
                                    if newValue { manualPageBreaks.insert(card.id) } else { manualPageBreaks.remove(card.id) }
                                }
                            ))
                            .labelsHidden()
                        }

                        HStack(alignment: .center, spacing: 12) {
                            Picker("配置", selection: Binding(get: { cardAlignments[card.id] ?? .center }, set: { cardAlignments[card.id] = $0 })) {
                                ForEach(CardHorizontalAlignment.allCases, id: \.self) { option in
                                    Text(option.title).tag(option)
                                }
                            }
                            .pickerStyle(.segmented)
                            .layoutPriority(1)
                        }

                        HStack(spacing: 12) {
                            Text("縮小")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Slider(value: Binding(get: { cardScales[card.id] ?? 1.0 }, set: { cardScales[card.id] = $0 }), in: 0.25...1.0, step: 0.05)
                            Text("\(Int(((cardScales[card.id] ?? 1.0) * 100).rounded()))%")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .frame(minWidth: 44, alignment: .trailing)
                        }
                        .onAppear {
                            if cardAlignments[card.id] == nil { cardAlignments[card.id] = .center }
                            if cardScales[card.id] == nil { cardScales[card.id] = 1.0 }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .listStyle(.insetGrouped)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("デフォルト") {
                    showResetAlert = true
                }
            }
        }
        .alert("改ページ設定をデフォルトに戻します。", isPresented: $showResetAlert) {
            Button("はい", role: .destructive) {
                manualPageBreaks = []
                cardScales = [:]
                cardAlignments = [:]
            }
            Button("いいえ", role: .cancel) { }
        }
    }
}

private struct CardShadowModifier: ViewModifier {
    let enabled: Bool
    let radius: CGFloat = 18

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        return content
            .clipShape(shape)
            .overlay(
                shape.stroke(Color.black.opacity(enabled ? 0.12 : 0), lineWidth: enabled ? 1 : 0)
            )
            .shadow(color: enabled ? Color.black.opacity(0.18) : .clear, radius: enabled ? 16 : 0, x: 0, y: enabled ? 8 : 0)
            .padding(enabled ? 8 : 0)
    }
}

func renderViewToImage(view: AnyView, width: CGFloat) -> UIImage? {
    let hosting = UIHostingController(rootView: view)
    hosting.view.backgroundColor = .clear
    let targetSize = CGSize(width: width, height: UIView.layoutFittingCompressedSize.height)
    hosting.view.translatesAutoresizingMaskIntoConstraints = false

    let container = UIView(frame: CGRect(origin: .zero, size: CGSize(width: width, height: 10)))
    container.backgroundColor = .clear
    container.addSubview(hosting.view)

    NSLayoutConstraint.activate([
        hosting.view.leadingAnchor.constraint(equalTo: container.leadingAnchor),
        hosting.view.trailingAnchor.constraint(equalTo: container.trailingAnchor),
        hosting.view.topAnchor.constraint(equalTo: container.topAnchor)
    ])

    let fittingSize = hosting.sizeThatFits(in: targetSize)
    let height = max(1, fittingSize.height)
    hosting.view.frame = CGRect(x: 0, y: 0, width: width, height: height)
    container.frame = CGRect(x: 0, y: 0, width: width, height: height)
    container.setNeedsLayout()
    container.layoutIfNeeded()

    let renderer = UIGraphicsImageRenderer(size: CGSize(width: width, height: height))
    return renderer.image { _ in
        container.drawHierarchy(in: container.bounds, afterScreenUpdates: true)
    }
}

func savePDFDataToTemporaryFile(data: Data) -> URL? {
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

func makeMapSnapshot(for card: TravelCard, size: CGSize) async -> UIImage? {
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
        MKMapSnapshotter(options: options).start { snapshot, _ in
            guard let snapshot = snapshot else {
                continuation.resume(returning: nil)
                return
            }
            let baseImage = snapshot.image
            UIGraphicsBeginImageContextWithOptions(baseImage.size, true, baseImage.scale)
            baseImage.draw(at: .zero)

            let pinPoint = snapshot.point(for: center)
            let ctx = UIGraphicsGetCurrentContext()
            ctx?.saveGState()
            let radius: CGFloat = 6
            let pinRect = CGRect(x: pinPoint.x - radius, y: pinPoint.y - radius, width: radius * 2, height: radius * 2)
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
func makeWebSnapshot(for card: TravelCard, size: CGSize) async -> UIImage? {
    guard let url = makeURL(from: card.url) else { return nil }

    let webView = WKWebView(frame: CGRect(origin: .zero, size: size))
    let request = URLRequest(url: url)
    await withCheckedContinuation { continuation in
        class NavigationDelegate: NSObject, WKNavigationDelegate {
            static var associationKey: UInt8 = 0
            let continuation: CheckedContinuation<Void, Never>
            init(_ continuation: CheckedContinuation<Void, Never>) { self.continuation = continuation }
            func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) { continuation.resume(returning: ()) }
            func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { continuation.resume(returning: ()) }
            func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { continuation.resume(returning: ()) }
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
        webView.takeSnapshot(with: configuration) { image, _ in
            continuation.resume(returning: image)
        }
    }
}

func makeURL(from input: String) -> URL? {
    let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return nil }
    if let url = URL(string: trimmed), url.scheme != nil {
        return url
    }
    return URL(string: "https://\(trimmed)")
}
