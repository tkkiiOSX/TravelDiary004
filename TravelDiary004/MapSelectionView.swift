import SwiftUI
import MapKit

struct MapSelectionView: View {
    @Binding var card: TravelCard
    let onDismiss: () -> Void
    
    @State private var position: MapCameraPosition = .automatic
    @State private var searchQuery = ""
    @State private var searchResults: [MKMapItem] = []
    @State private var selectedLocation: CLLocationCoordinate2D?
    @State private var isSearching = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 検索バー
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    TextField("住所または名称で検索", text: $searchQuery)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit(performSearch)
                    
                    if !searchQuery.isEmpty {
                        Button(action: { searchQuery = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                        }
                    }
                }
                .padding()
                
                // 検索結果リスト
                if isSearching {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color(.systemBackground))
                } else if !searchResults.isEmpty {
                    List(searchResults, id: \.self) { item in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.name ?? "Unknown")
                                .font(.body)
                                .fontWeight(.semibold)
                            if let address = item.placemark.formattedAddress {
                                Text(address)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(2)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectLocation(item)
                        }
                    }
                } else if !searchQuery.isEmpty {
                    VStack {
                        Text("検索結果がありません")
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemBackground))
                } else {
                    // デフォルト地図ビュー
                    MapReader { proxy in
                        Map(position: $position) {
                            if let coord = selectedLocation {
                                Marker("選択地点", coordinate: coord)
                                    .tint(.red)
                            } else {
                                Marker("選択地点", coordinate: CLLocationCoordinate2D(latitude: card.latitude, longitude: card.longitude))
                                    .tint(.red)
                            }
                        }
                        .mapStyle(.standard)
                        .onTapGesture(coordinateSpace: .local) { tap in
                            if let coord = proxy.convert(tap, from: .local) {
                                selectedLocation = coord
                            }
                        }
                    }
                }
                
                // ボタンエリア
                VStack(spacing: 12) {
                    if selectedLocation != nil || card.hasLocation {
                        Button(action: confirmSelection) {
                            HStack {
                                Image(systemName: "checkmark.circle")
                                Text("この位置を設定")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                        }
                    }
                    
                    Button(action: onDismiss) {
                        HStack {
                            Image(systemName: "xmark")
                            Text("キャンセル")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .foregroundColor(.primary)
                        .cornerRadius(8)
                    }
                }
                .padding()
            }
            .navigationTitle("位置を選択")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private func performSearch() {
        guard !searchQuery.isEmpty else {
            searchResults = []
            return
        }
        
        isSearching = true
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = searchQuery
        
        // 日本の中心付近に検索範囲を設定
        request.region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 36.2048, longitude: 138.2529),
            span: MKCoordinateSpan(latitudeDelta: 30, longitudeDelta: 30)
        )
        
        let search = MKLocalSearch(request: request)
        search.start { response, error in
            DispatchQueue.main.async {
                isSearching = false
                if let items = response?.mapItems {
                    searchResults = items
                }
            }
        }
    }
    
    private func selectLocation(_ item: MKMapItem) {
        let coordinate = item.placemark.coordinate
        selectedLocation = coordinate
        card.latitude = coordinate.latitude
        card.longitude = coordinate.longitude
        card.locationName = item.name ?? ""
        card.address = item.placemark.formattedAddress ?? ""
        
        // 地図をズーム
        let region = MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        )
        position = .region(region)
    }
    
    private func confirmSelection() {
        if let coord = selectedLocation {
            card.latitude = coord.latitude
            card.longitude = coord.longitude
        }
        onDismiss()
    }
}

extension CLPlacemark {
    var formattedAddress: String? {
        guard country != nil else { return nil }
        var addressLines: [String] = []
        
        if let state = administrativeArea {
            addressLines.append(state)
        }
        if let city = locality {
            addressLines.append(city)
        }
        if let street = thoroughfare {
            addressLines.append(street)
        }
        
        return addressLines.joined(separator: " ")
    }
}

#Preview {
    @Previewable @State var card = TravelCard()
    MapSelectionView(card: $card) { }
}

