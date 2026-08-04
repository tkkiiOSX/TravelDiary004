import Foundation
import MapKit

enum DateSelectionTarget: String, Identifiable {
    case start
    case end

    var id: String { rawValue }

    var navigationTitle: String {
        switch self {
        case .start:
            return "開始予定日"
        case .end:
            return "終了予定日"
        }
    }

    func apply(to startDate: inout Date?, endDate: inout Date?, selectedDate: Date) {
        switch self {
        case .start:
            startDate = selectedDate
        case .end:
            endDate = selectedDate
        }
    }
}

extension CLLocationCoordinate2D {
    var formattedString: String {
        String(format: "%.4f, %.4f", latitude, longitude)
    }

    func region(latitudeDelta: Double, longitudeDelta: Double) -> MKCoordinateRegion {
        MKCoordinateRegion(
            center: self,
            span: MKCoordinateSpan(latitudeDelta: latitudeDelta, longitudeDelta: longitudeDelta)
        )
    }
}

extension TravelCard {
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    func mapRegion(latitudeDelta: Double, longitudeDelta: Double) -> MKCoordinateRegion {
        coordinate.region(latitudeDelta: latitudeDelta, longitudeDelta: longitudeDelta)
    }
}
