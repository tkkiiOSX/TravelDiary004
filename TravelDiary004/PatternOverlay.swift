import SwiftUI
import UIKit

struct PatternOverlay: View {
    let pattern: PatternEffect
    let gradient: GradientEffect
    let baseColor: Color
    let patternColor: Color
    let opacity: Double

    var body: some View {
        ZStack {
            Color.clear
            
            // Gradient layer
            switch gradient {
            case .none:
                Color.clear
            case .horizontal:
                LinearGradient(
                    colors: [
                        baseColor,
                        darkerColor(baseColor, amount: 0.25)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .allowsHitTesting(false)
            case .vertical:
                LinearGradient(
                    colors: [
                        baseColor,
                        darkerColor(baseColor, amount: 0.25)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .allowsHitTesting(false)
            }
            
            // Pattern layer
            switch pattern {
            case .none:
                Color.clear
            case .dots:
                GeometryReader { _ in
                    Canvas { context, size in
                        let spacing: CGFloat = 32.0
                        let radius: CGFloat = 10.0
                        let dotColor = UIColor(patternColor).withAlphaComponent(CGFloat(opacity))
                        let fill = GraphicsContext.Shading.color(Color(dotColor))
                        var path = Path()
                        var y: CGFloat = 0
                        while y <= size.height {
                            var x: CGFloat = 0
                            //111行目、3行目などの奇数行目はー（spaceing / 2）の位置からスタートする
                            if Int(y / spacing) % 2 == 1
                            {
                                x -= spacing / 2
                        }
                            while x <= size.width {
                                path.addEllipse(in: CGRect(x: x, y: y, width: radius * 2, height: radius * 2))
                                x += spacing
                            }
                            y += spacing
                        }
                        context.fill(path, with: fill)
                    }
                }
                .allowsHitTesting(false)
            case .checkered:
                GeometryReader { _ in
                    Canvas { context, size in
                        let spacing: CGFloat = 18
                        let lineWidth: CGFloat = 5
                        let lineColor = UIColor(patternColor).withAlphaComponent(CGFloat(opacity))
                        let cgLineColor = Color(lineColor)

                        // Draw vertical lines
                        var x: CGFloat = 0
                        while x <= size.width {
                            var path = Path()
                            path.move(to: CGPoint(x: x, y: 0))
                            path.addLine(to: CGPoint(x: x, y: size.height))
                            context.stroke(path, with: .color(cgLineColor), lineWidth: lineWidth)
                            x += spacing
                        }
                        // Draw horizontal lines
                        var y: CGFloat = 0
                        while y <= size.height {
                            var path = Path()
                            path.move(to: CGPoint(x: 0, y: y))
                            path.addLine(to: CGPoint(x: size.width, y: y))
                            context.stroke(path, with: .color(cgLineColor), lineWidth: lineWidth)
                            y += spacing
                        }
                    }
                }
                .allowsHitTesting(false)
            case .ichimatsu:
                GeometryReader { _ in
                    Canvas { context, size in
                        let square: CGFloat = 20
                        let c1 = UIColor(patternColor).withAlphaComponent(CGFloat(opacity))
                        let c2 = UIColor(patternColor).withAlphaComponent(CGFloat(opacity * 0.75))
                        for row in stride(from: 0.0, through: size.height, by: square) {
                            for col in stride(from: 0.0, through: size.width, by: square) {
                                let isAlt = (Int(row / square) + Int(col / square)) % 2 == 0
                                let color = isAlt ? c1 : c2
                                let rect = CGRect(x: col, y: row, width: square, height: square)
                                context.fill(Path(rect), with: .color(Color(color)))
                            }
                        }
                    }
                }
                .allowsHitTesting(false)
            }
        }
    }
}

// MARK: - Color helpers
private func uiColor(from color: Color) -> UIColor? {
    #if canImport(UIKit)
    return UIColor(color)
    #else
    return nil
    #endif
}

private func darkerColor(_ color: Color, amount: CGFloat) -> Color {
    guard let ui = uiColor(from: color) else { return color.opacity(1 - amount * 0.5) }
    var r: CGFloat = 0
    var g: CGFloat = 0
    var b: CGFloat = 0
    var a: CGFloat = 0
    if ui.getRed(&r, green: &g, blue: &b, alpha: &a) {
        return Color(UIColor(red: max(r - amount, 0), green: max(g - amount, 0), blue: max(b - amount, 0), alpha: a))
    }
    return color
}

#Preview("PatternOverlay Effects") {
    let patterns: [PatternEffect] = [.none, .dots, .checkered, .ichimatsu]
    
    let gradients: [GradientEffect] = [.none, .horizontal, .vertical]
    
    let columns = [GridItem(.adaptive(minimum: 120), spacing: 16)]
    ScrollView {
        LazyVGrid(columns: columns, spacing: 16) {
            ForEach(Array(patterns.enumerated()), id: \.offset) { patternIdx, pattern in
                ForEach(Array(gradients.enumerated()), id: \.offset) { gradientIdx, gradient in
                    VStack(spacing: 8) {
                        ZStack {
                            let base: Color = [.blue.opacity(0.25), .green.opacity(0.25), .orange.opacity(0.25), .pink.opacity(0.25)][patternIdx % 4]
                            RoundedRectangle(cornerRadius: 12)
                                .fill(base)
                                .overlay(
                                    PatternOverlay(pattern: pattern, gradient: gradient, baseColor: base, patternColor: .black, opacity: 0.45)
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                )
                                .frame(height: 100)
                            VStack {
                                Text(pattern.displayName)
                                    .font(.caption2)
                                    .foregroundStyle(.primary)
                                Text(gradient.displayName)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(4)
                            .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.6)))
                        }
                    }
                    .padding(8)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color(UIColor.secondarySystemBackground)))
                }
            }
        }
        .padding(16)
    }
}
