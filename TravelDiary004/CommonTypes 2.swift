struct TravelCard {
    var id: String
    var title: String
    var description: String
    var latitude: Double
    var longitude: Double
    /// 地図表示の縮尺（リージョンの緯度/経度デルタ）。デフォルトは一覧表示にちょうど良い程度。
    var mapZoomDelta: Double = 0.08
    var imageURL: URL?
    // ... other properties and methods
}
