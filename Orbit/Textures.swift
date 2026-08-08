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

    static let asteroids: [SKTexture] = (0..<3).map { _ in asteroidTexture(radius: 16) }

    static func asteroidTexture(radius: CGFloat) -> SKTexture {
        let size = CGSize(width: radius * 2.4, height: radius * 2.4)
        let image = UIGraphicsImageRenderer(size: size).image { ctx in
            let c = ctx.cgContext
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let path = CGMutablePath()
            let points = 9
            for i in 0..<points {
                let angle = CGFloat(i) / CGFloat(points) * 2 * .pi
                let r = radius * CGFloat.random(in: 0.75...1.15)
                let p = CGPoint(x: center.x + cos(angle) * r, y: center.y + sin(angle) * r)
                i == 0 ? path.move(to: p) : path.addLine(to: p)
            }
            path.closeSubpath()
            c.addPath(path)
            c.setFillColor(UIColor(white: 0.48, alpha: 1).cgColor)
            c.fillPath()
            for _ in 0..<4 {
                let craterRadius = radius * CGFloat.random(in: 0.12...0.28)
                let angle = CGFloat.random(in: 0...(2 * .pi))
                let distance = CGFloat.random(in: 0...(radius * 0.55))
                let p = CGPoint(x: center.x + cos(angle) * distance,
                                y: center.y + sin(angle) * distance)
                c.setFillColor(UIColor(white: 0.32, alpha: 1).cgColor)
                c.fillEllipse(in: CGRect(x: p.x - craterRadius, y: p.y - craterRadius,
                                         width: craterRadius * 2, height: craterRadius * 2))
            }
        }
        return SKTexture(image: image)
    }

    // Tiny rocket pointing up: light body, cyan nose and fins, dark window.
    static let rocket: SKTexture = {
        let size = CGSize(width: 22, height: 48)
        let cyan = UIColor(red: 0.32, green: 0.9, blue: 1.0, alpha: 1)
        let image = UIGraphicsImageRenderer(size: size).image { ctx in
            let body = UIBezierPath(roundedRect: CGRect(x: 4, y: 8, width: 14, height: 32),
                                    cornerRadius: 7)
            UIColor(white: 0.88, alpha: 1).setFill()
            body.fill()

            let nose = UIBezierPath()
            nose.move(to: CGPoint(x: 4, y: 12))
            nose.addLine(to: CGPoint(x: 11, y: 0))
            nose.addLine(to: CGPoint(x: 18, y: 12))
            nose.close()
            cyan.setFill()
            nose.fill()

            ctx.cgContext.setFillColor(UIColor(red: 0.1, green: 0.15, blue: 0.3, alpha: 1).cgColor)
            ctx.cgContext.fillEllipse(in: CGRect(x: 7.5, y: 16, width: 7, height: 7))

            for x: CGFloat in [0, 22] {
                let fin = UIBezierPath()
                fin.move(to: CGPoint(x: x == 0 ? 4 : 18, y: 30))
                fin.addLine(to: CGPoint(x: x, y: 44))
                fin.addLine(to: CGPoint(x: x == 0 ? 4 : 18, y: 40))
                fin.close()
                cyan.setFill()
                fin.fill()
            }
        }
        return SKTexture(image: image)
    }()

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
