import CoreGraphics

extension CGPoint {
    static func + (l: CGPoint, r: CGPoint) -> CGPoint { CGPoint(x: l.x + r.x, y: l.y + r.y) }
    static func - (l: CGPoint, r: CGPoint) -> CGPoint { CGPoint(x: l.x - r.x, y: l.y - r.y) }
    static func * (l: CGPoint, r: CGFloat) -> CGPoint { CGPoint(x: l.x * r, y: l.y * r) }

    var length: CGFloat { hypot(x, y) }

    var normalized: CGPoint {
        let len = max(length, 0.0001)
        return CGPoint(x: x / len, y: y / len)
    }

    func distance(to p: CGPoint) -> CGFloat { (self - p).length }

    static func polar(angle: CGFloat, radius: CGFloat) -> CGPoint {
        CGPoint(x: cos(angle) * radius, y: sin(angle) * radius)
    }
}

func cross(_ a: CGPoint, _ b: CGPoint) -> CGFloat { a.x * b.y - a.y * b.x }
