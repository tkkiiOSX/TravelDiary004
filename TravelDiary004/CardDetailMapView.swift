import SwiftUI
import MapKit

struct CardDetailMapView: View {
    let card: TravelCard
    @State private var position: MapCameraPosition = .automatic
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if card.hasLocation {
                    Map(position: $position) {
                        Marker(card.locationName.isEmpty ? "位置" : card.locationName,
                               coordinate: CLLocationCoordinate2D(latitude: card.latitude, longitude: card.longitude))
                            .tint(.red)
                    }
                    .mapStyle(.standard)
                    .onAppear {
                        let region = MKCoordinateRegion(
                            center: CLLocationCoordinate2D(latitude: card.latitude, longitude: card.longitude),
                            span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
                        )
                        position = .region(region)
                    }
                    
                    VStack(alignment: .leading, spacing: 12) {
                        if !card.locationName.isEmpty {
                            HStack {
                                Image(systemName: "location.circle.fill")
                                    .foregroundColor(.red)
                                Text(card.locationName)
                                    .font(.headline)
                            }
                        }
                        
                        if !card.address.isEmpty {
                            HStack(alignment: .top) {
                                Image(systemName: "house.circle.fill")
                                    .foregroundColor(.blue)
                                Text(card.address)
                                    .font(.subheadline)
                                    .lineLimit(3)
                            }
                        }
                        
                        HStack {
                            Image(systemName: "map.circle.fill")
                                .foregroundColor(.purple)
                            Text(String(format: "%.4f, %.4f", card.latitude, card.longitude))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
                    .padding()
                } else {
                    VStack {
                        Image(systemName: "map.slash")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text("位置情報が設定されていません")
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationTitle("地点表示")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    { () -> CardDetailMapView in
        var card = TravelCard()
        card.locationName = "丸の内"
        card.address = "東京都千代田区丸の内"
        card.latitude = 35.6762
        card.longitude = 139.7674
        return CardDetailMapView(card: card)
    }()
}
