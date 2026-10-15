

//
//  CardDisplayView.swift
//  TravelDiary004
//
//  Created by Xcode2021 on 2026/10/11.
//
import SwiftUI
import MapKit

private struct ScaledSquareMapView: View {
    let card: TravelCard
    @Binding var position: MapCameraPosition

    @State private var availableWidth: CGFloat = 0

    private var scale: CGFloat {
        CGFloat(max(0.5, min(card.mapDisplayScale, 1.0)))
    }

    var body: some View {
        Map(position: $position) {
            Marker(
                card.locationName.isEmpty ? "選択地点" : card.locationName,
                coordinate: card.coordinate
            )
            .tint(.red)
        }
        .mapStyle(.standard)
        .allowsHitTesting(false)
        .frame(
            width: max(1, availableWidth * scale),
            height: max(1, availableWidth * scale)
        )
        .cornerRadius(14)
        // 小さくした正方形の地図を左寄せにする
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            GeometryReader { geometry in
                Color.clear
                    .onAppear {
                        availableWidth = geometry.size.width
                    }
                    .onChange(of: geometry.size.width) { _, newWidth in
                        availableWidth = newWidth
                    }
            }
        }
        .onAppear {
            position = .region(
                card.mapRegion(
                    latitudeDelta: card.mapZoomDelta,
                    longitudeDelta: card.mapZoomDelta
                )
            )
        }
    }
}

private struct MapWithDescriptionView: View {
    let card: TravelCard
    @Binding var position: MapCameraPosition

    var body: some View {
        GeometryReader { geometry in
            let mapSide = geometry.size.width * 0.5

            HStack(alignment: .top, spacing: 8) {
                Map(position: $position) {
                    Marker(
                        card.locationName.isEmpty ? "選択地点" : card.locationName,
                        coordinate: card.coordinate
                    )
                    .tint(.red)
                }
                .mapStyle(.standard)
                .allowsHitTesting(false)
                .frame(width: mapSide, height: mapSide)
                .cornerRadius(14)

                Text(card.mapDescription)
                    .font(.system(size: CGFloat(max(card.textSize - 4, 8))))
                    .foregroundColor(card.textColor)
                    .lineLimit(nil)
                    .minimumScaleFactor(0.5)
                    .frame(
                        width: max(1, geometry.size.width - mapSide - 8),
                        height: mapSide,
                        alignment: .topLeading
                    )
                    .clipped()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
        .aspectRatio(2, contentMode: .fit)
        .onAppear {
            position = .region(
                card.mapRegion(
                    latitudeDelta: card.mapZoomDelta,
                    longitudeDelta: card.mapZoomDelta
                )
            )
        }
    }
}

struct CardDisplayView: View {
    let card: TravelCard

    @State private var position: MapCameraPosition = .automatic
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if card.showDate {
                VStack(alignment: .leading, spacing: 2) {
                    Text(card.displayDateString)
                        .font(.system(size: CGFloat(max(card.textSize - 2, 8)), weight: .bold))
                        .foregroundColor(card.textColor)
                }
            }

            if card.showStartTime || card.showEndTime {
                VStack(alignment: .leading, spacing: 2) {
                    Text(card.displayTimeRangeString)
                        .font(.system(size: CGFloat(max(card.textSize - 4, 8))))
                        .foregroundColor(card.textColor.opacity(0.8))
                }
            }

            HStack(alignment: .center, spacing: 8) {
                if let icon = card.iconName(), !icon.isEmpty {
                    Image(systemName: icon)
                        .font(.system(size: CGFloat(card.textSize), weight: .bold))
                        .foregroundColor(card.textColor)
                }

                if !card.title.isEmpty {
                    Text(card.title)
                        .font(.system(size: CGFloat(card.textSize), weight: .bold))
                        .foregroundColor(card.textColor)
                } else {
                    Text("無題のカード")
                        .font(.system(size: CGFloat(card.textSize)))
                        .foregroundColor(card.textColor.opacity(0.6))
                }

                Spacer()
            }

            if !card.memo.isEmpty {
                Text(card.memo)
                    .font(.system(size: CGFloat(max(card.textSize - 4, 8))))
                    .foregroundColor(card.textColor.opacity(0.5))
                    .fixedSize(horizontal: false, vertical: true)
            }

            if card.hasLocation {
                VStack(alignment: .leading, spacing: 6) {
                    //ScaledSquareMapView(card: card, position: $position)
                    if abs(card.mapDisplayScale - 0.5) < 0.001 && card.showMapDescription {
                        MapWithDescriptionView(card: card, position: $position)
                    } else {
                        ScaledSquareMapView(card: card, position: $position)
                    }

                    if card.showMapJumpButton {
                        let coordinate = CLLocationCoordinate2D(
                            latitude: card.latitude,
                            longitude: card.longitude
                        )

                        Button {
                            let placemark = MKPlacemark(coordinate: coordinate)
                            let mapItem = MKMapItem(placemark: placemark)
                            mapItem.name = card.locationName.isEmpty ? "選択地点" : card.locationName

                            let span = MKCoordinateSpan(
                                latitudeDelta: 0.01,
                                longitudeDelta: 0.01
                            )

                            mapItem.openInMaps(launchOptions: [
                                MKLaunchOptionsMapCenterKey: NSValue(mkCoordinate: coordinate),
                                MKLaunchOptionsMapSpanKey: NSValue(mkCoordinateSpan: span)
                            ])
                        } label: {
                            Image(systemName: "map")
                                .font(.title2)
                                .foregroundColor(.white)
                                .padding(10)
                                .background(Circle().fill(Color.accentColor))
                                .shadow(radius: 3)
                        }
                        .buttonStyle(.plain)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, 8)
                    }
                }
            }

            if let url = displayURL {
                VStack(alignment: .leading, spacing: 6) {
                    GeometryReader { geo in
                        let side = min(geo.size.width, geo.size.height)

                        WebView(url: url, allowNavigation: false)
                            .frame(width: side, height: side)
                            .cornerRadius(14)
                    }
                    .aspectRatio(1, contentMode: .fit)
                }
            }

            if let imageData = card.imageData,
               let uiImage = UIImage(data: imageData) {
                ZStack {
                    GeometryReader { geo in
                        let side = min(geo.size.width, geo.size.height)
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
                        .frame(width: side, height: side)
                        .clipped()
                        .cornerRadius(14)
                    }
                }
                .aspectRatio(1, contentMode: .fit)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            ZStack {
                card.backgroundColor
                PatternOverlay(
                    pattern: card.patternEffect,
                    gradient: card.gradientEffect,
                    baseColor: card.backgroundColor,
                    patternColor: card.patternColor,
                    opacity: card.patternOpacity
                )
            }
        )
        .foregroundColor(card.textColor)
        .cornerRadius(18)
        .modifier(
            CardBorderModifier(
                style: card.borderStyle,
                color: card.borderColor,
                lineWidth: CGFloat(card.borderWidth),
                radius: 18
            )
        )
        .modifier(CardShadowModifier(enabled: card.showShadow))
        .padding(.vertical, 4)
        .padding(.horizontal, 4)
    }

    private var displayURL: URL? {
        let trimmed = card.url.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let url = URL(string: trimmed), url.scheme != nil {
            return url
        }

        return URL(string: "https://\(trimmed)")
    }
}

#Preview {
    let card = TravelCard(
        date: Date(),
        title: "サンプル",
        memo: "メモ",
        latitude: 35.0,
        longitude: 135.0,
        showDate: true,
        showStartTime: true,
        showEndTime: true,
        backgroundColorHex: "#aaaaaa"
    )

    return CardDisplayView(card: card)
}

