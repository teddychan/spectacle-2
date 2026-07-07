import AppKit
import Foundation

let out = URL(fileURLWithPath: CommandLine.arguments[1])
let S = 1024
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: S, pixelsHigh: S,
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
rep.size = NSSize(width: S, height: S)
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
NSGraphicsContext.current?.imageInterpolation = .high
let C = CGFloat(S)

let pad: CGFloat = 92
let tile = NSRect(x: pad, y: pad, width: C - 2*pad, height: C - 2*pad)
let radius = tile.width * 0.235
let tilePath = NSBezierPath(roundedRect: tile, xRadius: radius, yRadius: radius)
tilePath.addClip()
let grad = NSGradient(colors: [
    NSColor(srgbRed: 0.96, green: 0.30, blue: 0.24, alpha: 1),
    NSColor(srgbRed: 0.98, green: 0.68, blue: 0.20, alpha: 1),
    NSColor(srgbRed: 0.55, green: 0.80, blue: 0.28, alpha: 1),
])!
grad.draw(in: tilePath, angle: -55)

func X(_ g: NSRect, _ f: CGFloat) -> CGFloat { g.minX + g.width*f }
func Y(_ g: NSRect, _ f: CGFloat) -> CGFloat { g.minY + g.height*f }
let g = NSRect(x: tile.minX + tile.width*0.16, y: tile.minY + tile.height*0.34,
               width: tile.width*0.68, height: tile.height*0.30)
let lw = tile.width * 0.052
NSColor.white.setStroke()
let lensW = g.width*0.40, lensH = g.height
let r = lensH*0.34
for lx in [CGFloat(0.0), 0.60] {
    let lens = NSBezierPath(roundedRect: NSRect(x: X(g, lx), y: g.minY, width: lensW, height: lensH), xRadius: r, yRadius: r)
    lens.lineWidth = lw; lens.lineJoinStyle = .round; lens.stroke()
}
let bridge = NSBezierPath()
bridge.move(to: NSPoint(x: X(g, 0.40), y: Y(g, 0.72)))
bridge.curve(to: NSPoint(x: X(g, 0.60), y: Y(g, 0.72)),
             controlPoint1: NSPoint(x: X(g, 0.46), y: Y(g, 1.02)),
             controlPoint2: NSPoint(x: X(g, 0.54), y: Y(g, 1.02)))
bridge.lineWidth = lw; bridge.lineCapStyle = .round; bridge.stroke()
for (sx, ex) in [(CGFloat(0.02), CGFloat(-0.12)), (0.98, 1.12)] {
    let t = NSBezierPath()
    t.move(to: NSPoint(x: X(g, sx), y: Y(g, 0.74)))
    t.line(to: NSPoint(x: X(g, ex), y: Y(g, 0.98)))
    t.lineWidth = lw; t.lineCapStyle = .round; t.stroke()
}

let br: CGFloat = tile.width*0.15
let bc = NSPoint(x: tile.maxX - br - tile.width*0.06, y: tile.minY + br + tile.width*0.06)
NSColor(calibratedWhite: 0.0, alpha: 0.28).setFill()
NSBezierPath(ovalIn: NSRect(x: bc.x-br, y: bc.y-br, width: 2*br, height: 2*br)).fill()
let fs = br*1.5
var font = NSFont.systemFont(ofSize: fs, weight: .bold)
if let d = font.fontDescriptor.withDesign(.rounded) { font = NSFont(descriptor: d, size: fs) ?? font }
let s = NSAttributedString(string: "2", attributes: [.font: font, .foregroundColor: NSColor.white])
let ts = s.size()
s.draw(at: NSPoint(x: bc.x - ts.width/2, y: bc.y - ts.height/2 + ts.height*0.04))

NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .png, properties: [:])!.write(to: out)
print("wrote \(out.path)")
