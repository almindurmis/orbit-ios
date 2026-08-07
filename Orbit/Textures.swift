import SpriteKit
import UIKit

enum Textures {
    static let softDot: SKTexture = radialGlow(radius: 32, color: .white)

    static func radialGlow(radius: CGFloat, color: UIColor) -> SKTexture {
        let size = CGSize(width: radius * 2, height: radius * 2)
        let image = UIGraphicsImageRenderer(size: size).image { ctx in
            let colors = [color.cgColor, color.withAlphaComponent(0).cgColor] as CFArray
            guard let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                            colors: colors, locations: [0, 1]) else { return }
            let center = CGPoint(x: radius, y: radius)
            ctx.cgContext.drawRadialGradient(gradient, startCenter: center, startRadius: 0,
                                             endCenter: center, endRadius: radius, options: [])
        }
        return SKTexture(image: image)
    }

    static func fadingLine(length: CGFloat, thickness: CGFloat) -> SKTexture {
        let size = CGSize(width: length, height: thickness)
        let image = UIGraphicsImageRenderer(size: size).image { ctx in
            let colors = [UIColor.white.cgColor, UIColor.white.withAlphaComponent(0).cgColor] as CFArray
            guard let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                            colors: colors, locations: [0, 1]) else { return }
            ctx.cgContext.drawLinearGradient(gradient, start: .zero,
                                             end: CGPoint(x: length, y: 0), options: [])
        }
        return SKTexture(image: image)
    }
}
