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
    var titleTextColorHex: String = "#000000"
    var titleBackgroundColorHex: String = "#FFFFFF"
    var cards: [TravelCard] = []
    var manualPageBreaks: Set<UUID> = []
    var cardScales: [UUID: Double] = [:]
    var cardAlignmentsRaw: [UUID: String] = [:]
    var backgroundColorHex: String = "#FFFFFF"
    var travelDateTextColorHex: String = "#666666"
    var defaultCardBackgroundColorHex: String? = nil
    var startDate: Date? = nil
    var endDate: Date? = nil

    var printTitleOnAllPages: Bool? = true // optional for decoding compatibility

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
    
    var titleTextColor: Color {
        Color(hex: titleTextColorHex)
    }
    
    var titleBackgroundColor: Color {
        Color(hex: titleBackgroundColorHex)
    }

    var effectiveDefaultCardBackgroundColorHex: String {
        defaultCardBackgroundColorHex ?? TravelCard.defaultCardBackgroundColorHex(for: backgroundColorHex)
    }

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case titleTextColorHex
        case titleBackgroundColorHex
        case cards
        case manualPageBreaks
        case cardScales
        case cardAlignmentsRaw
        case backgroundColorHex
        case travelDateTextColorHex
        case defaultCardBackgroundColorHex
        case startDate
        case endDate
        case printTitleOnAllPages
    }

    init(
        id: UUID = UUID(),
        title: String,
        titleTextColorHex: String = "#000000",
        titleBackgroundColorHex: String = "#FFFFFF",
        cards: [TravelCard] = [],
        manualPageBreaks: Set<UUID> = [],
        cardScales: [UUID: Double] = [:],
        cardAlignmentsRaw: [UUID: String] = [:],
        backgroundColorHex: String = "#FFFFFF",
        travelDateTextColorHex: String = "#666666",
        defaultCardBackgroundColorHex: String? = nil,
        startDate: Date? = nil,
        endDate: Date? = nil,
        printTitleOnAllPages: Bool? = true
    ) {
        self.id = id
        self.title = title
        self.titleTextColorHex = titleTextColorHex
        self.titleBackgroundColorHex = titleBackgroundColorHex
        self.cards = cards
        self.manualPageBreaks = manualPageBreaks
        self.cardScales = cardScales
        self.cardAlignmentsRaw = cardAlignmentsRaw
        self.backgroundColorHex = backgroundColorHex
        self.travelDateTextColorHex = travelDateTextColorHex
        self.defaultCardBackgroundColorHex = defaultCardBackgroundColorHex
        self.startDate = startDate
        self.endDate = endDate
        self.printTitleOnAllPages = printTitleOnAllPages
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        title = try container.decode(String.self, forKey: .title)
        titleTextColorHex = try container.decodeIfPresent(String.self, forKey: .titleTextColorHex) ?? "#000000"
        titleBackgroundColorHex = try container.decodeIfPresent(String.self, forKey: .titleBackgroundColorHex) ?? "#FFFFFF"
        cards = try container.decodeIfPresent([TravelCard].self, forKey: .cards) ?? []
        manualPageBreaks = try container.decodeIfPresent(Set<UUID>.self, forKey: .manualPageBreaks) ?? []
        cardScales = try container.decodeIfPresent([UUID: Double].self, forKey: .cardScales) ?? [:]
        cardAlignmentsRaw = try container.decodeIfPresent([UUID: String].self, forKey: .cardAlignmentsRaw) ?? [:]
        backgroundColorHex = try container.decodeIfPresent(String.self, forKey: .backgroundColorHex) ?? "#FFFFFF"
        travelDateTextColorHex = try container.decodeIfPresent(String.self, forKey: .travelDateTextColorHex) ?? "#666666"
        defaultCardBackgroundColorHex = try container.decodeIfPresent(String.self, forKey: .defaultCardBackgroundColorHex)
        startDate = try container.decodeIfPresent(Date.self, forKey: .startDate)
        endDate = try container.decodeIfPresent(Date.self, forKey: .endDate)
        printTitleOnAllPages = try container.decodeIfPresent(Bool.self, forKey: .printTitleOnAllPages) ?? true
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(titleTextColorHex, forKey: .titleTextColorHex)
        try container.encode(titleBackgroundColorHex, forKey: .titleBackgroundColorHex)
        try container.encode(cards, forKey: .cards)
        try container.encode(manualPageBreaks, forKey: .manualPageBreaks)
        try container.encode(cardScales, forKey: .cardScales)
        try container.encode(cardAlignmentsRaw, forKey: .cardAlignmentsRaw)
        try container.encode(backgroundColorHex, forKey: .backgroundColorHex)
        try container.encode(travelDateTextColorHex, forKey: .travelDateTextColorHex)
        try container.encodeIfPresent(defaultCardBackgroundColorHex, forKey: .defaultCardBackgroundColorHex)
        try container.encodeIfPresent(startDate, forKey: .startDate)
        try container.encodeIfPresent(endDate, forKey: .endDate)
        try container.encode(printTitleOnAllPages ?? true, forKey: .printTitleOnAllPages)
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

    var textSize: Double = 14.0

    var backgroundEffectRaw: String = BackgroundEffect.none.rawValue
    var patternEffectRaw: String = PatternEffect.none.rawValue
    var gradientEffectRaw: String = GradientEffect.none.rawValue

    var showSafariJumpButton: Bool = false

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
        case textSize
        case showSafariJumpButton
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
        gradientEffectRaw: String = GradientEffect.none.rawValue,
        textSize: Double = 14.0,
        showSafariJumpButton: Bool = false
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
        self.textSize = textSize
        self.showSafariJumpButton = showSafariJumpButton
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
        textSize = try container.decodeIfPresent(Double.self, forKey: .textSize) ?? 14.0
        showSafariJumpButton = try container.decodeIfPresent(Bool.self, forKey: .showSafariJumpButton) ?? false
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
        try container.encode(textSize, forKey: .textSize)
        try container.encode(showSafariJumpButton, forKey: .showSafariJumpButton)
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

    private static func removeStoredData() {
        let url = dataURL()
        if FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.removeItem(at: url)
        }
    }

    init(resetStoredData: Bool = false) {
        if resetStoredData {
            Self.removeStoredData()
        }
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
            // Try to access security-scoped resource if available, but don't fail immediately if not.
            let accessed = url.startAccessingSecurityScopedResource()
            defer {
                if accessed { url.stopAccessingSecurityScopedResource() }
            }

            // 1) Try reading directly
            let data: Data
            do {
                data = try Data(contentsOf: url)
            } catch {
                // 2) Fallback: copy to a temporary file and read again
                let tmpExt = url.pathExtension.isEmpty ? "json" : url.pathExtension
                let tmpURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent("import_\(UUID().uuidString)")
                    .appendingPathExtension(tmpExt)
                do {
                    if FileManager.default.fileExists(atPath: tmpURL.path) {
                        try FileManager.default.removeItem(at: tmpURL)
                    }
                    try FileManager.default.copyItem(at: url, to: tmpURL)
                    data = try Data(contentsOf: tmpURL)
                } catch {
                    let message = "ファイルの読み込みに失敗しました（コピー/再読み込み）"
                    importFeedback = ImportFeedback(message: message, isSuccess: false)
                    return message
                }
            }

            var imported = try JSONDecoder().decode(TravelSheet.self, from: data)
            
            // Ensure printTitleOnAllPages is true if nil
            if imported.printTitleOnAllPages == nil {
                imported.printTitleOnAllPages = true
            }
            
            // --- Ensure imported sheet and all cards get new IDs ---
            let oldToNewCardID = Dictionary(uniqueKeysWithValues: imported.cards.map { ($0.id, UUID()) })
            imported.id = UUID()
            imported.cards = imported.cards.map { card in
                var newCard = card
                if let newID = oldToNewCardID[card.id] {
                    newCard.id = newID
                }
                return newCard
            }
            // manualPageBreaks, cardScales, cardAlignmentsRaw (if present) をID対応で変換
            imported.manualPageBreaks = Set(imported.manualPageBreaks.compactMap { oldToNewCardID[$0] })
            imported.cardScales = Dictionary(uniqueKeysWithValues: imported.cardScales.compactMap { (oldID, scale) in
                guard let newID = oldToNewCardID[oldID] else { return nil }
                return (newID, scale)
            })
            imported.cardAlignmentsRaw = Dictionary(uniqueKeysWithValues: imported.cardAlignmentsRaw.compactMap { (oldID, raw) in
                guard let newID = oldToNewCardID[oldID] else { return nil }
                return (newID, raw)
            })
            // --- End of ID refresh ---
            
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

    func resetStoredData() {
        Self.removeStoredData()
        sheets = []
        importFeedback = nil
    }

    func addSheet(title: String, backgroundColor: Color = .white, startDate: Date? = nil, endDate: Date? = nil, travelDateTextColor: Color = .secondary, defaultCardBackgroundColor: Color? = nil, titleTextColor: Color = .primary, titleBackgroundColor: Color = .white, printTitleOnAllPages: Bool = true) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let hex = UIColor(backgroundColor).toHexString() ?? "#FFFFFF"
        let textHex = UIColor(travelDateTextColor).toHexString() ?? "#666666"
        let defaultCardHex = defaultCardBackgroundColor.map { UIColor($0).toHexString() ?? "#FFFFFF" }
        let titleTextHex = UIColor(titleTextColor).toHexString() ?? "#000000"
        let titleBgHex = UIColor(titleBackgroundColor).toHexString() ?? "#FFFFFF"
        sheets.insert(TravelSheet(title: trimmed, titleTextColorHex: titleTextHex, titleBackgroundColorHex: titleBgHex, backgroundColorHex: hex, travelDateTextColorHex: textHex, defaultCardBackgroundColorHex: defaultCardHex, startDate: startDate, endDate: endDate, printTitleOnAllPages: printTitleOnAllPages), at: 0)
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
    
    func updateSheetTitleTextColor(sheetID: UUID, color: Color) {
        guard let idx = sheets.firstIndex(where: { $0.id == sheetID }) else { return }
        let hex = UIColor(color).toHexString() ?? "#000000"
        sheets[idx].titleTextColorHex = hex
    }

    func updateSheetTitleBackgroundColor(sheetID: UUID, color: Color) {
        guard let idx = sheets.firstIndex(where: { $0.id == sheetID }) else { return }
        let hex = UIColor(color).toHexString() ?? "#FFFFFF"
        sheets[idx].titleBackgroundColorHex = hex
    }
    
    func updateSheetPrintTitleOnAllPages(sheetID: UUID, value: Bool) {
        guard let idx = sheets.firstIndex(where: { $0.id == sheetID }) else { return }
        sheets[idx].printTitleOnAllPages = value
    }
}

