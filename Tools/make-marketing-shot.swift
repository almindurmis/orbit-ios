// Composes an App Store marketing screenshot: brand gradient + stars background,
// headline and subline on top, rounded device capture below with a soft glow.
// Output stays 1320x2868 so App Store Connect accepts it as a 6.9" screenshot.
// Run: swift Tools/make-marketing-shot.swift in.png out.png "Headline" "Subline" <starSeed>
import CoreGraphics
import CoreText
import ImageIO
import Foundation

let args = CommandLine.arguments
let input = args[1], output = args[2], headline = args[3], subline = args[4]
let seed = args.count > 5 ? Int(args[5]) ?? 1 : 1

let W = 1320, H = 2868
let space = CGColorSpaceCreateDeviceRGB()
let ctx = CGContext(data: nil, width: W, height: H, bitsPerComponent: 8, bytesPerRow: 0,
                    space: space, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!

let bg = CGGradient(colorsSpace: space, colors: [
    CGColor(red: 0.10, green: 0.09, blue: 0.28, alpha: 1),
    CGColor(red: 0.05, green: 0.05, blue: 0.15, alpha: 1),
] as CFArray, locations: [0, 1])!
ctx.drawLinearGradient(bg, start: CGPoint(x: 0, y: CGFloat(H)), end: CGPoint(x: CGFloat(W), y: 0), options: [])

func radial(_ cx: CGFloat, _ cy: CGFloat, _ r: CGFloat, _ color: CGColor) {
    let g = CGGradient(colorsSpace: space, colors: [color, color.copy(alpha: 0)!] as CFArray,
                       locations: [0, 1])!
    ctx.drawRadialGradient(g, startCenter: CGPoint(x: cx, y: cy), startRadius: 0,
                           endCenter: CGPoint(x: cx, y: cy), endRadius: r, options: [])
}
radial(1150, 2600, 520, CGColor(red: 0.45, green: 0.30, blue: 0.90, alpha: 0.35))
radial(150, 400, 460, CGColor(red: 0.20, green: 0.70, blue: 0.90, alpha: 0.25))

srand48(seed)
for _ in 0..<55 {
    let x = drand48() * Double(W), y = drand48() * Double(H)
    let r = 1.0 + drand48() * 2.4
    ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.18 + drand48() * 0.5))
    ctx.fillEllipse(in: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2))
}

func drawLine(_ text: String, font fontName: String, size: CGFloat, color: CGColor, baselineFromTop: CGFloat) {
    func line(_ fontSize: CGFloat) -> CTLine {
        let font = CTFontCreateWithName(fontName as CFString, fontSize, nil)
        let attr = NSAttributedString(string: text, attributes: [
            NSAttributedString.Key(kCTFontAttributeName as String): font,
            NSAttributedString.Key(kCTForegroundColorAttributeName as String): color,
        ])
        return CTLineCreateWithAttributedString(attr)
    }
    var ctLine = line(size)
    var width = CGFloat(CTLineGetTypographicBounds(ctLine, nil, nil, nil))
    if width > 1180 {
        ctLine = line(size * 1180 / width)
        width = CGFloat(CTLineGetTypographicBounds(ctLine, nil, nil, nil))
    }
    ctx.textPosition = CGPoint(x: (CGFloat(W) - width) / 2, y: CGFloat(H) - baselineFromTop)
    CTLineDraw(ctLine, ctx)
}

drawLine(headline, font: "HelveticaNeue-Bold", size: 96,
         color: CGColor(red: 1, green: 1, blue: 1, alpha: 1), baselineFromTop: 230)
drawLine(subline, font: "HelveticaNeue-Medium", size: 50,
         color: CGColor(red: 1.0, green: 0.84, blue: 0.42, alpha: 0.95), baselineFromTop: 350)

let src = CGImageSourceCreateWithURL(URL(fileURLWithPath: input) as CFURL, nil)!
let shot = CGImageSourceCreateImageAtIndex(src, 0, nil)!
let targetW: CGFloat = 1128
let targetH = CGFloat(shot.height) * targetW / CGFloat(shot.width)
let rect = CGRect(x: (CGFloat(W) - targetW) / 2, y: CGFloat(H) - 480 - targetH,
                  width: targetW, height: targetH)
let rounded = CGPath(roundedRect: rect, cornerWidth: 64, cornerHeight: 64, transform: nil)

ctx.saveGState()
ctx.setShadow(offset: .zero, blur: 70, color: CGColor(red: 0.32, green: 0.9, blue: 1.0, alpha: 0.4))
ctx.addPath(rounded)
ctx.setFillColor(CGColor(red: 0.05, green: 0.05, blue: 0.15, alpha: 1))
ctx.fillPath()
ctx.restoreGState()

ctx.saveGState()
ctx.addPath(rounded)
ctx.clip()
ctx.draw(shot, in: rect)
ctx.restoreGState()

ctx.addPath(rounded)
ctx.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.18))
ctx.setLineWidth(3)
ctx.strokePath()

let image = ctx.makeImage()!
let dest = CGImageDestinationCreateWithURL(URL(fileURLWithPath: output) as CFURL,
                                           "public.png" as CFString, 1, nil)!
CGImageDestinationAddImage(dest, image, nil)
CGImageDestinationFinalize(dest)
