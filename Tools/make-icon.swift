// Generates the 1024x1024 app icon. Run: swift Tools/make-icon.swift <output.png>
import CoreGraphics
import ImageIO
import Foundation

let size = 1024
let space = CGColorSpaceCreateDeviceRGB()
let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                    space: space, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
let center = CGPoint(x: 512, y: 512)

ctx.setFillColor(CGColor(red: 0.027, green: 0.031, blue: 0.078, alpha: 1))
ctx.fill(CGRect(x: 0, y: 0, width: 1024, height: 1024))

let glow = CGGradient(colorsSpace: space,
                      colors: [CGColor(red: 0.09, green: 0.14, blue: 0.32, alpha: 1),
                               CGColor(red: 0.027, green: 0.031, blue: 0.078, alpha: 0)] as CFArray,
                      locations: [0, 1])!
ctx.drawRadialGradient(glow, startCenter: center, startRadius: 0, endCenter: center, endRadius: 720, options: [])

// scattered stars (fixed seed so the icon is reproducible)
var seed: UInt64 = 42
func rnd() -> Double {
    seed = seed &* 6364136223846793005 &+ 1442695040888963407
    return Double(seed >> 33) / Double(UInt32.max)
}
ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.5))
for _ in 0..<70 {
    let x = rnd() * 1024, y = rnd() * 1024, r = 1.2 + rnd() * 2.4
    ctx.fillEllipse(in: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2))
}

let cyan = CGColor(red: 0.32, green: 0.9, blue: 1.0, alpha: 1)

// ring with layered glow
let ringRadius: CGFloat = 330
for (width, alpha) in [(CGFloat(58), 0.10), (36, 0.20), (22, 0.4), (13, 1.0)] {
    ctx.setStrokeColor(cyan.copy(alpha: alpha)!)
    ctx.setLineWidth(width)
    ctx.strokeEllipse(in: CGRect(x: center.x - ringRadius, y: center.y - ringRadius,
                                 width: ringRadius * 2, height: ringRadius * 2))
}

// planet core with glow
let coreGlow = CGGradient(colorsSpace: space,
                          colors: [cyan.copy(alpha: 0.55)!, cyan.copy(alpha: 0)!] as CFArray,
                          locations: [0, 1])!
ctx.drawRadialGradient(coreGlow, startCenter: center, startRadius: 0, endCenter: center, endRadius: 240, options: [])
ctx.setFillColor(cyan)
ctx.fillEllipse(in: CGRect(x: center.x - 74, y: center.y - 74, width: 148, height: 148))

// player dot on the ring, upper right
let angle = 0.85
let px = center.x + ringRadius * CGFloat(cos(angle))
let py = center.y + ringRadius * CGFloat(sin(angle))
let dotGlow = CGGradient(colorsSpace: space,
                         colors: [CGColor(red: 1, green: 1, blue: 1, alpha: 0.8),
                                  CGColor(red: 1, green: 1, blue: 1, alpha: 0)] as CFArray,
                         locations: [0, 1])!
ctx.drawRadialGradient(dotGlow, startCenter: CGPoint(x: px, y: py), startRadius: 0,
                       endCenter: CGPoint(x: px, y: py), endRadius: 130, options: [])
ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
ctx.fillEllipse(in: CGRect(x: px - 46, y: py - 46, width: 92, height: 92))

let image = ctx.makeImage()!
let url = URL(fileURLWithPath: CommandLine.arguments[1]) as CFURL
let dest = CGImageDestinationCreateWithURL(url, "public.png" as CFString, 1, nil)!
CGImageDestinationAddImage(dest, image, nil)
CGImageDestinationFinalize(dest)
