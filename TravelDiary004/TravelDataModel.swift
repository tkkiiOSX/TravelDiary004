import SwiftUI
import Combine
import UIKit

// MARK: - Background Effect Support (shared)
enum BackgroundEffect: String, CaseIterable, Identifiable {
    case none
    case dots
    case checkered
    case ichimatsu
    case gradient
    case edgeShadow

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .none: return "なし"
        case .dots: return "ドット柄"
        case .checkered: return "チェック柄"
        case .ichimatsu: return "市松模様"
        case .gradient: return "グラデーション"
        case .edgeShadow: return "エッジシャドウ"
        }
    }
}

enum PatternEffect: String, CaseIterable, Identifiable {
    case none
    case dots
    case checkered
    case ichimatsu

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .none: return "なし"
        case .dots: return "ドット柄"
        case .checkered: return "チェック柄"
        case .ichimatsu: return "市松模様"
        }
    }
}

enum GradientEffect: String, CaseIterable, Identifiable {
    case none
    case horizontal
    case vertical

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .none: return "なし"
        case .horizontal: return "グラデーション（左右）"
        case .vertical: return "グラデーション（上下）"
        }
    }
}

enum CardBorderStyle: String, CaseIterable, Identifiable {
    case none
    case single
    case double

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .none: return "なし"
        case .single: return "一重線"
        case .double: return "二重線"
        }
    }
}

struct ImportFeedback: Identifiable, Equatable {
    let id = UUID()
    let message: String
    let isSuccess: Bool
}

struct TravelSheet: Identifiable, Hashable, Codable {
    var id: UUID = UUID()
    var title: String
    var cards: [TravelCard] = []
    var manualPageBreaks: Set<UUID> = []
    var cardScales: [UUID: Double] = [:]
    var cardAlignmentsRaw: [UUID: String] = [:]
    var backgroundColorHex: String = "#FFFFFF"
    var travelDateTextColorHex: String = "#666666"
    var defaultCardBackgroundColorHex: String? = nil
    var startDate: Date? = nil
    var endDate: Date? = nil

    var cardAlignments: [UUID: CardHorizontalAlignment] {
        get {
            var result: [UUID: CardHorizontalAlignment] = [:]
            for (key, raw) in cardAlignmentsRaw {
                if let align = CardHorizontalAlignment(rawValue: raw) { result[key] = align }
            }
            return result
        }
        set {
            var raw: [UUID: String] = [:]
            for (key, value) in newValue { raw[key] = value.rawValue }
            cardAlignmentsRaw = raw
        }
    }

    var backgroundColor: Color {
        Color(hex: backgroundColorHex)
    }

    var travelDateTextColor: Color {
        Color(hex: travelDateTextColorHex)
    }

    var effectiveDefaultCardBackgroundColorHex: String {
        defaultCardBackgroundColorHex ?? TravelCard.defaultCardBackgroundColorHex(for: backgroundColorHex)
    }
}

struct TravelCard: Identifiable, Hashable, Codable {
    static let defaultBackgroundColorHex = "#FFFFFF"
    static let defaultTextColorHex = "#000000"
    static let defaultPatternColorHex = "#D0D0D0"
    static let defaultBorderColorHex = "#000000"
    static let highlightedDefaultBackgroundColorHex = "#EBC299"

    var id: UUID = UUID()
    var date: Date = Date()
    var title: String = ""
    var memo: String = ""
    var imageData: Data? = nil
    var locationName: String = ""  // 地名・施設名
    var address: String = ""  // 住所
    var latitude: Double = 0.0
    var longitude: Double = 0.0
    var url: String = ""
    var category: String = "該当なし"
    var showDate: Bool = false
    var showTime: Bool = false
    var time: Date = Date()
    var printLocation: Bool = true
    var printWebPage: Bool = true
    var printPhoto: Bool = true
    var showShadow: Bool = true
    var backgroundColorHex: String = defaultBackgroundColorHex
    var textColorHex: String = defaultTextColorHex
    var patternColorHex: String = defaultPatternColorHex
    var borderColorHex: String = defaultBorderColorHex
    var borderWidth: Double = 2.0
    var borderStyleRaw: String = CardBorderStyle.none.rawValue
    var patternOpacity: Double = 0.45

    var backgroundEffectRaw: String = BackgroundEffect.none.rawValue
    var patternEffectRaw: String = PatternEffect.none.rawValue
    var gradientEffectRaw: String = GradientEffect.none.rawValue

    var backgroundEffect: BackgroundEffect {
        get { BackgroundEffect(rawValue: backgroundEffectRaw) ?? .none }
        set { backgroundEffectRaw = newValue.rawValue }
    }

    var patternEffect: PatternEffect {
        get { PatternEffect(rawValue: patternEffectRaw) ?? .none }
        set { patternEffectRaw = newValue.rawValue }
    }

    var gradientEffect: GradientEffect {
        get { GradientEffect(rawValue: gradientEffectRaw) ?? .none }
        set { gradientEffectRaw = newValue.rawValue }
    }

    var effectivePattern: PatternEffect {
        if patternEffect != .none { return patternEffect }
        // Map legacy backgroundEffect to pattern if available
        switch backgroundEffect {
        case .dots: return .dots
        case .checkered: return .checkered
        case .ichimatsu: return .ichimatsu
        default: return .none
        }
    }

    var effectiveGradient: GradientEffect {
        if gradientEffect != .none { return gradientEffect }
        // Map legacy backgroundEffect .gradient to horizontal by default
        switch backgroundEffect {
        case .gradient: return .horizontal
        default: return .none
        }
    }

    var backgroundColor: Color {
        Color(hex: backgroundColorHex)
    }

    var displayDateString: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    var displayTimeString: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: time)
    }

    var textColor: Color {
        Color(hex: textColorHex)
    }

    var patternColor: Color {
        Color(hex: patternColorHex)
    }

    var borderColor: Color {
        Color(hex: borderColorHex)
    }

    var borderStyle: CardBorderStyle {
        get { CardBorderStyle(rawValue: borderStyleRaw) ?? .none }
        set { borderStyleRaw = newValue.rawValue }
    }

    var patternUIColor: UIColor {
        UIColor(hex: patternColorHex) ?? .lightGray
    }

    var hasLowColorContrast: Bool {
        backgroundUIColor.contrastRatio(with: textUIColor) < 3.0
    }

    var hasPatternColorConflict: Bool {
        normalizedHex(backgroundColorHex) == normalizedHex(patternColorHex)
    }

    private var backgroundUIColor: UIColor {
        UIColor(hex: backgroundColorHex) ?? .white
    }

    private var textUIColor: UIColor {
        UIColor(hex: textColorHex) ?? .black
    }

    private func normalizedHex(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if trimmed.hasPrefix("#") {
            return String(trimmed.dropFirst())
        }
        return trimmed
    }

    var image: Image {
        if let data = imageData, let uiImage = UIImage(data: data) {
            return Image(uiImage: uiImage)
        }
        return Image(systemName: "photo")
    }
    
    var hasLocation: Bool {
        latitude != 0.0 && longitude != 0.0
    }

    var hasURL: Bool {
        !url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    static let categoryOptions: [(String, String, String)] = [
        ("徒歩", "徒歩", "figure.walk"),
        ("自転車", "自転車", "bicycle"),
        ("オートバイ", "オートバイ", "motorcycle"),
        ("車", "車", "car"),
        ("電車", "電車", "train.side.front.car"),
        ("バス", "バス", "bus"),
        ("タクシー", "タクシー", "car.fill"),
        ("飛行機", "飛行機", "airplane"),
        ("船", "船", "ferry"),
        ("食事", "食事", "fork.knife"),
        ("宿泊", "宿泊", "bed.double"),
        ("美術館", "美術館", "paintpalette"),
        ("博物館", "博物館", "building.columns"),
        ("歴史資料館", "歴史資料館", "book"),
        ("記念館", "記念館", "rosette"),
        ("遊園地", "遊園地", "popcorn"),
        ("水族館", "水族館", "fish"),
        ("動物園", "動物園", "pawprint"),
        ("映画館", "映画館", "film"),
        ("劇場", "劇場", "theatermasks"),
        ("ライブ会場", "ライブ会場", "music.mic"),
        ("その他施設", "その他施設", "ellipsis.circle"),
        ("該当なし", "該当なし", "")
    ]

    func iconName() -> String? {
        TravelCard.categoryOptions.first(where: { $0.0 == category })?.2
    }

    static func defaultCardBackgroundColorHex(for sheetBackgroundColorHex: String) -> String {
        let normalizedHex = normalizedHexString(sheetBackgroundColorHex)
        if normalizedHex == defaultBackgroundColorHex.replacingOccurrences(of: "#", with: "") ||
            normalizedHex == "F5F5DC" {
            return highlightedDefaultBackgroundColorHex
        }
        return sheetBackgroundColorHex
    }

    static func normalizedHexString(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if trimmed.hasPrefix("#") {
            return String(trimmed.dropFirst())
        }
        return trimmed
    }

    enum CodingKeys: String, CodingKey {
        case id
        case date
        case title
        case memo
        case imageData
        case locationName
        case address
        case latitude
        case longitude
        case url
        case category
        case showDate
        case showTime
        case time
        case printLocation
        case printWebPage
        case printPhoto
        case showShadow
        case backgroundColorHex
        case textColorHex
        case patternColorHex
        case borderColorHex
        case borderWidth
        case borderStyleRaw
        case patternOpacity
        case backgroundEffectRaw
        case patternEffectRaw
        case gradientEffectRaw
    }

    init(
        id: UUID = UUID(),
        date: Date = Date(),
        title: String = "",
        memo: String = "",
        imageData: Data? = nil,
        locationName: String = "",
        address: String = "",
        latitude: Double = 0.0,
        longitude: Double = 0.0,
        url: String = "",
        category: String = "該当なし",
        showDate: Bool = false,
        showTime: Bool = false,
        time: Date = Date(),
        printLocation: Bool = true,
        printWebPage: Bool = true,
        printPhoto: Bool = true,
        showShadow: Bool = true,
        backgroundColorHex: String = defaultBackgroundColorHex,
        textColorHex: String = defaultTextColorHex,
        patternColorHex: String = defaultPatternColorHex,
        borderColorHex: String = defaultBorderColorHex,
        borderWidth: Double = 2.0,
        borderStyleRaw: String = CardBorderStyle.none.rawValue,
        patternOpacity: Double = 0.45,
        backgroundEffectRaw: String = BackgroundEffect.none.rawValue,
        patternEffectRaw: String = PatternEffect.none.rawValue,
        gradientEffectRaw: String = GradientEffect.none.rawValue
    ) {
        self.id = id
        self.date = date
        self.title = title
        self.memo = memo
        self.imageData = imageData
        self.locationName = locationName
        self.address = address
        self.latitude = latitude
        self.longitude = longitude
        self.url = url
        self.category = category
        self.showDate = showDate
        self.showTime = showTime
        self.time = time
        self.printLocation = printLocation
        self.printWebPage = printWebPage
        self.printPhoto = printPhoto
        self.showShadow = showShadow
        self.backgroundColorHex = backgroundColorHex
        self.textColorHex = textColorHex
        self.patternColorHex = patternColorHex
        self.borderColorHex = borderColorHex
        self.borderWidth = borderWidth
        self.borderStyleRaw = borderStyleRaw
        self.patternOpacity = patternOpacity
        self.backgroundEffectRaw = backgroundEffectRaw
        self.patternEffectRaw = patternEffectRaw
        self.gradientEffectRaw = gradientEffectRaw
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        date = try container.decodeIfPresent(Date.self, forKey: .date) ?? Date()
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? ""
        memo = try container.decodeIfPresent(String.self, forKey: .memo) ?? ""
        imageData = try container.decodeIfPresent(Data.self, forKey: .imageData)
        locationName = try container.decodeIfPresent(String.self, forKey: .locationName) ?? ""
        address = try container.decodeIfPresent(String.self, forKey: .address) ?? ""
        latitude = try container.decodeIfPresent(Double.self, forKey: .latitude) ?? 0.0
        longitude = try container.decodeIfPresent(Double.self, forKey: .longitude) ?? 0.0
        url = try container.decodeIfPresent(String.self, forKey: .url) ?? ""
        category = try container.decodeIfPresent(String.self, forKey: .category) ?? "該当なし"
        showDate = try container.decodeIfPresent(Bool.self, forKey: .showDate) ?? false
        showTime = try container.decodeIfPresent(Bool.self, forKey: .showTime) ?? false
        time = try container.decodeIfPresent(Date.self, forKey: .time) ?? date
        printLocation = try container.decodeIfPresent(Bool.self, forKey: .printLocation) ?? true
        printWebPage = try container.decodeIfPresent(Bool.self, forKey: .printWebPage) ?? true
        printPhoto = try container.decodeIfPresent(Bool.self, forKey: .printPhoto) ?? true
        showShadow = try container.decodeIfPresent(Bool.self, forKey: .showShadow) ?? true
        backgroundColorHex = try container.decodeIfPresent(String.self, forKey: .backgroundColorHex) ?? Self.defaultBackgroundColorHex
        textColorHex = try container.decodeIfPresent(String.self, forKey: .textColorHex) ?? Self.defaultTextColorHex
        patternColorHex = try container.decodeIfPresent(String.self, forKey: .patternColorHex) ?? Self.defaultPatternColorHex
        borderColorHex = try container.decodeIfPresent(String.self, forKey: .borderColorHex) ?? Self.defaultBorderColorHex
        borderWidth = try container.decodeIfPresent(Double.self, forKey: .borderWidth) ?? 2.0
        borderStyleRaw = try container.decodeIfPresent(String.self, forKey: .borderStyleRaw) ?? CardBorderStyle.none.rawValue
        patternOpacity = try container.decodeIfPresent(Double.self, forKey: .patternOpacity) ?? 0.45
        backgroundEffectRaw = try container.decodeIfPresent(String.self, forKey: .backgroundEffectRaw) ?? BackgroundEffect.none.rawValue
        patternEffectRaw = try container.decodeIfPresent(String.self, forKey: .patternEffectRaw) ?? PatternEffect.none.rawValue
        gradientEffectRaw = try container.decodeIfPresent(String.self, forKey: .gradientEffectRaw) ?? GradientEffect.none.rawValue
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(date, forKey: .date)
        try container.encode(title, forKey: .title)
        try container.encode(memo, forKey: .memo)
        try container.encodeIfPresent(imageData, forKey: .imageData)
        try container.encode(locationName, forKey: .locationName)
        try container.encode(address, forKey: .address)
        try container.encode(latitude, forKey: .latitude)
        try container.encode(longitude, forKey: .longitude)
        try container.encode(url, forKey: .url)
        try container.encode(category, forKey: .category)
        try container.encode(showDate, forKey: .showDate)
        try container.encode(showTime, forKey: .showTime)
        try container.encode(time, forKey: .time)
        try container.encode(printLocation, forKey: .printLocation)
        try container.encode(printWebPage, forKey: .printWebPage)
        try container.encode(printPhoto, forKey: .printPhoto)
        try container.encode(showShadow, forKey: .showShadow)
        try container.encode(backgroundColorHex, forKey: .backgroundColorHex)
        try container.encode(textColorHex, forKey: .textColorHex)
        try container.encode(patternColorHex, forKey: .patternColorHex)
        try container.encode(borderColorHex, forKey: .borderColorHex)
        try container.encode(borderWidth, forKey: .borderWidth)
        try container.encode(borderStyleRaw, forKey: .borderStyleRaw)
        try container.encode(patternOpacity, forKey: .patternOpacity)
        try container.encode(backgroundEffectRaw, forKey: .backgroundEffectRaw)
        try container.encode(patternEffectRaw, forKey: .patternEffectRaw)
        try container.encode(gradientEffectRaw, forKey: .gradientEffectRaw)
    }
}

extension Color {
    init(hex: String) {
        self = Color(UIColor(hex: hex) ?? .white)
    }
}

extension UIColor {
    convenience init?(hex: String) {
        var hexString = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if hexString.hasPrefix("#") {
            hexString.removeFirst()
        }
        guard hexString.count == 6 || hexString.count == 8 else {
            return nil
        }
        var hexNumber: UInt64 = 0
        let scanner = Scanner(string: hexString)
        guard scanner.scanHexInt64(&hexNumber) else { return nil }
        let r, g, b, a: CGFloat
        if hexString.count == 8 {
            r = CGFloat((hexNumber & 0xFF000000) >> 24) / 255
            g = CGFloat((hexNumber & 0x00FF0000) >> 16) / 255
            b = CGFloat((hexNumber & 0x0000FF00) >> 8) / 255
            a = CGFloat(hexNumber & 0x000000FF) / 255
        } else {
            r = CGFloat((hexNumber & 0xFF0000) >> 16) / 255
            g = CGFloat((hexNumber & 0x00FF00) >> 8) / 255
            b = CGFloat(hexNumber & 0x0000FF) / 255
            a = 1.0
        }
        self.init(red: r, green: g, blue: b, alpha: a)
    }

    func toHexString(includeAlpha: Bool = false) -> String? {
        guard let components = cgColor.components, components.count >= 3 else { return nil }
        let r = Int((components[0] * 255).rounded())
        let g = Int((components[1] * 255).rounded())
        let b = Int((components[2] * 255).rounded())
        let a = cgColor.alpha
        if includeAlpha {
            return String(format: "#%02X%02X%02X%02X", r, g, b, Int((a * 255).rounded()))
        } else {
            return String(format: "#%02X%02X%02X", r, g, b)
        }
    }

    private func relativeLuminance() -> CGFloat {
        guard let components = cgColor.components, components.count >= 3 else { return 0 }
        func adjust(_ value: CGFloat) -> CGFloat {
            if value <= 0.03928 {
                return value / 12.92
            } else {
                return pow((value + 0.055) / 1.055, 2.4)
            }
        }
        let r = adjust(components[0])
        let g = adjust(components[1])
        let b = adjust(components[2])
        return 0.2126 * r + 0.7152 * g + 0.0722 * b
    }

    func contrastRatio(with other: UIColor) -> CGFloat {
        let lum1 = relativeLuminance()
        let lum2 = other.relativeLuminance()
        let bright = max(lum1, lum2)
        let dark = min(lum1, lum2)
        return (bright + 0.05) / (dark + 0.05)
    }
}

final class TravelDataModel: ObservableObject {
    @Published var sheets: [TravelSheet] = []
    @Published var importFeedback: ImportFeedback? = nil
    private var cancellables = Set<AnyCancellable>()

    private static func dataURL() -> URL {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return dir.appendingPathComponent("travel_data.json")
    }

    init() {
        if let data = try? Data(contentsOf: Self.dataURL()),
           let decoded = try? JSONDecoder().decode([TravelSheet].self, from: data) {
            self.sheets = decoded
        }
        // Observe changes to sheets and save automatically
        $sheets
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.save() }
            .store(in: &cancellables)
    }

    private func save() {
        let url = Self.dataURL()
        do {
            let data = try JSONEncoder().encode(sheets)
            try data.write(to: url, options: [.atomic])
        } catch {
            print("Save error: \(error)")
        }
    }

    @MainActor
    func importSheet(from url: URL) -> String? {
        do {
            guard url.startAccessingSecurityScopedResource() else {
                let message = "ファイルにアクセスできません"
                importFeedback = ImportFeedback(message: message, isSuccess: false)
                return message
            }
            defer { url.stopAccessingSecurityScopedResource() }

            let data = try Data(contentsOf: url)
            var imported = try JSONDecoder().decode(TravelSheet.self, from: data)
            let fileName = url.deletingPathExtension().lastPathComponent
            imported.title = fileName
            sheets.insert(imported, at: 0)
            importFeedback = ImportFeedback(message: "シートをインポートしました", isSuccess: true)
            return nil
        } catch {
            let message = "インポートに失敗しました: \(error.localizedDescription)"
            importFeedback = ImportFeedback(message: message, isSuccess: false)
            return message
        }
    }

    func clearImportFeedback() {
        importFeedback = nil
    }

    func addSheet(title: String, backgroundColor: Color = .white, startDate: Date? = nil, endDate: Date? = nil, travelDateTextColor: Color = .secondary, defaultCardBackgroundColor: Color? = nil) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let hex = UIColor(backgroundColor).toHexString() ?? "#FFFFFF"
        let textHex = UIColor(travelDateTextColor).toHexString() ?? "#666666"
        let defaultCardHex = defaultCardBackgroundColor.map { UIColor($0).toHexString() ?? "#FFFFFF" }
        sheets.insert(TravelSheet(title: trimmed, backgroundColorHex: hex, travelDateTextColorHex: textHex, defaultCardBackgroundColorHex: defaultCardHex, startDate: startDate, endDate: endDate), at: 0)
    }
    
    func deleteSheet(_ sheet: TravelSheet) {
        if let idx = sheets.firstIndex(where: { $0.id == sheet.id }) {
            sheets.remove(at: idx)
        }
    }

    func updateCard(_ card: TravelCard, in sheet: TravelSheet) {
        guard let sheetIndex = sheets.firstIndex(where: { $0.id == sheet.id }) else { return }
        guard let cardIndex = sheets[sheetIndex].cards.firstIndex(where: { $0.id == card.id }) else { return }
        sheets[sheetIndex].cards[cardIndex] = card
    }

    func addCard(_ card: TravelCard, to sheet: TravelSheet) {
        guard let sheetIndex = sheets.firstIndex(where: { $0.id == sheet.id }) else { return }
        sheets[sheetIndex].cards.append(card)
    }

    func deleteCard(_ card: TravelCard, from sheet: TravelSheet) {
        guard let sheetIndex = sheets.firstIndex(where: { $0.id == sheet.id }) else { return }
        if let cardIndex = sheets[sheetIndex].cards.firstIndex(where: { $0.id == card.id }) {
            sheets[sheetIndex].cards.remove(at: cardIndex)
        }
    }
    
    func moveCards(in sheet: TravelSheet, from source: IndexSet, to destination: Int) {
        guard let sheetIndex = sheets.firstIndex(where: { $0.id == sheet.id }) else { return }
        sheets[sheetIndex].cards.move(fromOffsets: source, toOffset: destination)
    }
    
    func updateSheetColor(sheetID: UUID, color: Color) {
        guard let idx = sheets.firstIndex(where: { $0.id == sheetID }) else { return }
        let hex = UIColor(color).toHexString() ?? "#FFFFFF"
        sheets[idx].backgroundColorHex = hex
    }

    func updateSheetTravelDateTextColor(sheetID: UUID, color: Color) {
        guard let idx = sheets.firstIndex(where: { $0.id == sheetID }) else { return }
        let hex = UIColor(color).toHexString() ?? "#666666"
        sheets[idx].travelDateTextColorHex = hex
    }

    func updateSheetDefaultCardBackgroundColor(sheetID: UUID, color: Color) {
        guard let idx = sheets.firstIndex(where: { $0.id == sheetID }) else { return }
        let hex = UIColor(color).toHexString() ?? "#FFFFFF"
        sheets[idx].defaultCardBackgroundColorHex = hex
    }

    func updateSheetTravelDates(sheetID: UUID, startDate: Date?, endDate: Date?) {
        guard let idx = sheets.firstIndex(where: { $0.id == sheetID }) else { return }
        sheets[idx].startDate = startDate
        sheets[idx].endDate = endDate
    }
    
    func updateSheetTitle(sheetID: UUID, newTitle: String) {
        let trimmed = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard let idx = sheets.firstIndex(where: { $0.id == sheetID }) else { return }
        sheets[idx].title = trimmed
    }
    
    func updateManualSettings(for sheetID: UUID, manualPageBreaks: Set<UUID>, cardScales: [UUID: Double], cardAlignments: [UUID: CardHorizontalAlignment]) {
        guard let idx = sheets.firstIndex(where: { $0.id == sheetID }) else { return }
        sheets[idx].manualPageBreaks = manualPageBreaks
        sheets[idx].cardScales = cardScales
        // store alignments as raw strings for Codable simplicity
        var raw: [UUID: String] = [:]
        for (key, value) in cardAlignments { raw[key] = value.rawValue }
        sheets[idx].cardAlignmentsRaw = raw
    }

    func resetManualSettings(for sheetID: UUID) {
        guard let idx = sheets.firstIndex(where: { $0.id == sheetID }) else { return }
        sheets[idx].manualPageBreaks = []
        sheets[idx].cardScales = [:]
        sheets[idx].cardAlignmentsRaw = [:]
    }
}
