import AppKit
import Foundation

let args = CommandLine.arguments
guard args.count >= 3, let src = NSImage(contentsOf: URL(fileURLWithPath: args[1])) else {
    fputs("usage: composite <in.png> <out.png>\n", stderr); exit(1)
}
let outURL = URL(fileURLWithPath: args[2])
let size = 1024
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
rep.size = NSSize(width: size, height: size)

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
NSGraphicsContext.current?.imageInterpolation = .high

let canvas = NSRect(x: 0, y: 0, width: size, height: size)
src.draw(in: canvas, from: .zero, operation: .sourceOver, fraction: 1.0)

// Badge geometry (AppKit bottom-left origin → bottom-right corner = high x, low y)
let R: CGFloat = 215, margin: CGFloat = 66
let cx = CGFloat(size) - R - margin
let cy = R + margin
let badgeRect = NSRect(x: cx - R, y: cy - R, width: 2*R, height: 2*R)

// Badge fill with drop shadow so it lifts off the busy artwork
NSGraphicsContext.saveGraphicsState()
let shadow = NSShadow()
shadow.shadowColor = NSColor.black.withAlphaComponent(0.5)
shadow.shadowBlurRadius = 28
shadow.shadowOffset = NSSize(width: 0, height: -8)
shadow.set()
NSColor(calibratedWhite: 0.11, alpha: 1.0).setFill()
NSBezierPath(ovalIn: badgeRect).fill()
NSGraphicsContext.restoreGraphicsState()

// Light ring
NSColor.white.withAlphaComponent(0.92).setStroke()
let ring = NSBezierPath(ovalIn: badgeRect.insetBy(dx: R*0.06, dy: R*0.06))
ring.lineWidth = R*0.055
ring.stroke()

// The "2" — heavy rounded numeral, white
let fontSize = R*1.45
var font = NSFont.systemFont(ofSize: fontSize, weight: .heavy)
if let desc = font.fontDescriptor.withDesign(.rounded) { font = NSFont(descriptor: desc, size: fontSize) ?? font }
let para = NSMutableParagraphStyle(); para.alignment = .center
let s = NSAttributedString(string: "2", attributes: [.font: font, .foregroundColor: NSColor.white, .paragraphStyle: para])
let ts = s.size()
s.draw(at: NSPoint(x: cx - ts.width/2, y: cy - ts.height/2 + ts.height*0.04))

NSGraphicsContext.restoreGraphicsState()
guard let data = rep.representation(using: .png, properties: [:]) else { fputs("png fail\n", stderr); exit(1) }
try! data.write(to: outURL)
print("wrote \(outURL.path)")
