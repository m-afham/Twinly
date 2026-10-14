// Twinly app icon generator (CoreGraphics, macOS). Current icon: "rubin" in
// the Ink and champagne palette — flat colour, no gradients or glow.
//
//   swift tools/icon/make_icon.swift <concept: lens|rubin> <variant: light|dark|tinted> <out.png>
//
// Concept "lens": two glossy overlapping spheres (the twins) whose
// intersection glows gold with a four-point star. Concept "rubin": two
// mirrored face profiles (Rubin's vase) with a star between them.

import AppKit
import CoreGraphics
import Foundation

let args = CommandLine.arguments
let concept = args.count > 1 ? args[1] : "lens"
let variant = args.count > 2 ? args[2] : "light"
let outPath = args.count > 3 ? args[3] : "icon.png"

let S: CGFloat = 1024
let cs = CGColorSpace(name: CGColorSpace.displayP3)!
let ctx = CGContext(data: nil, width: Int(S), height: Int(S), bitsPerComponent: 8, bytesPerRow: 0,
                    space: cs, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
// Top-left origin for sane geometry.
ctx.translateBy(x: 0, y: S)
ctx.scaleBy(x: 1, y: -1)

func c(_ hex: UInt32, _ a: CGFloat = 1) -> CGColor {
    CGColor(colorSpace: cs, components: [CGFloat((hex >> 16) & 0xFF) / 255, CGFloat((hex >> 8) & 0xFF) / 255,
                                         CGFloat(hex & 0xFF) / 255, a])!
}
func gray(_ hex: UInt32, _ a: CGFloat = 1) -> CGColor {
    let r = CGFloat((hex >> 16) & 0xFF), g = CGFloat((hex >> 8) & 0xFF), b = CGFloat(hex & 0xFF)
    let l = (0.299 * r + 0.587 * g + 0.114 * b) / 255
    return CGColor(colorSpace: cs, components: [l, l, l, a])!
}
let tinted = variant == "tinted"
func col(_ hex: UInt32, _ a: CGFloat = 1) -> CGColor { tinted ? gray(hex, a) : c(hex, a) }

func linear(_ colors: [CGColor], _ locs: [CGFloat], from: CGPoint, to: CGPoint) {
    let g = CGGradient(colorsSpace: cs, colors: colors as CFArray, locations: locs)!
    ctx.drawLinearGradient(g, start: from, end: to, options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
}
func radial(_ colors: [CGColor], _ locs: [CGFloat], center: CGPoint, radius: CGFloat) {
    let g = CGGradient(colorsSpace: cs, colors: colors as CFArray, locations: locs)!
    ctx.drawRadialGradient(g, startCenter: center, startRadius: 0, endCenter: center, endRadius: radius,
                           options: [.drawsAfterEndLocation])
}

/// Four-point star with concave sides.
func starPath(center p: CGPoint, radius r: CGFloat, waist: CGFloat = 0.18) -> CGPath {
    let path = CGMutablePath()
    let tips = (0..<4).map { i -> CGPoint in
        let a = CGFloat(i) * .pi / 2 - .pi / 2
        return CGPoint(x: p.x + cos(a) * r, y: p.y + sin(a) * r)
    }
    path.move(to: tips[0])
    for i in 0..<4 {
        let next = tips[(i + 1) % 4]
        path.addQuadCurve(to: next, control: CGPoint(x: p.x + (tips[i].x + next.x - 2 * p.x) * waist,
                                                     y: p.y + (tips[i].y + next.y - 2 * p.y) * waist))
    }
    path.closeSubpath()
    return path
}

func drawStar(at p: CGPoint, radius r: CGFloat, glow: CGFloat) {
    // Flat cream star (the glow parameter is kept for the old "lens" concept).
    ctx.addPath(starPath(center: p, radius: r))
    ctx.setFillColor(col(0xF3EFE7))
    ctx.fillPath()
}

/// "Ink and champagne": a flat near-black canvas for every variant
/// (the tinted variant goes greyscale through col()).
func background() {
    ctx.setFillColor(col(0x111214))
    ctx.fill(CGRect(x: 0, y: 0, width: S, height: S))
}

// MARK: - Concept: lens

func drawLens() {
    background()
    let r: CGFloat = 268
    let d: CGFloat = 158
    let cy: CGFloat = S / 2 + 6
    let L = CGPoint(x: S / 2 - d, y: cy), R = CGPoint(x: S / 2 + d, y: cy)
    let left = CGPath(ellipseIn: CGRect(x: L.x - r, y: L.y - r, width: 2 * r, height: 2 * r), transform: nil)
    let right = CGPath(ellipseIn: CGRect(x: R.x - r, y: R.y - r, width: 2 * r, height: 2 * r), transform: nil)

    // Ambient glow behind both.
    ctx.saveGState()
    ctx.setShadow(offset: .zero, blur: 120, color: col(0xE5469B, variant == "dark" ? 0.5 : 0.65))
    ctx.addPath(left); ctx.addPath(right)
    ctx.setFillColor(col(0x000000, 0.01))
    ctx.fillPath()
    ctx.restoreGState()

    // Spheres.
    for (path, center, colors) in [(left, L, [0xFF8A5C, 0xFF5F6D, 0xE5469B] as [UInt32]),
                                   (right, R, [0xB47CFF, 0x8C6CFF, 0x5B45E0] as [UInt32])] {
        ctx.saveGState()
        ctx.addPath(path); ctx.clip()
        linear(colors.map { col($0) }, [0, 0.5, 1],
               from: CGPoint(x: center.x - r * 0.6, y: center.y - r), to: CGPoint(x: center.x + r * 0.5, y: center.y + r))
        // Soft top gloss.
        radial([col(0xFFFFFF, 0.38), col(0xFFFFFF, 0)], [0, 1],
               center: CGPoint(x: center.x - r * 0.25, y: center.y - r * 0.45), radius: r * 0.85)
        // Bottom shade for volume.
        radial([col(0x000000, 0), col(0x000000, 0.28)], [0.55, 1],
               center: CGPoint(x: center.x - r * 0.15, y: center.y - r * 0.25), radius: r * 1.35)
        ctx.restoreGState()
    }

    // The lens: where the twins overlap.
    ctx.saveGState()
    ctx.addPath(left); ctx.clip()
    ctx.addPath(right); ctx.clip()
    radial([col(0xFFF6E0), col(0xFFD27A), col(0xFF7AB6), col(0xC45CF0)], [0, 0.32, 0.72, 1],
           center: CGPoint(x: S / 2, y: cy), radius: r * 0.98)
    ctx.restoreGState()

    // Hairline rims so the circles read at small sizes.
    ctx.saveGState()
    ctx.setLineWidth(5)
    ctx.setStrokeColor(col(0xFFFFFF, 0.28))
    ctx.addPath(left); ctx.strokePath()
    ctx.addPath(right); ctx.strokePath()
    ctx.restoreGState()

    drawStar(at: CGPoint(x: S / 2, y: cy), radius: 118, glow: 60)
}

// MARK: - Concept: rubin

/// Left-hand profile facing right; the right one is its mirror.
func profilePath() -> CGPath {
    let p = CGMutablePath()
    p.move(to: CGPoint(x: -80, y: 120))
    p.addCurve(to: CGPoint(x: 330, y: 250), control1: CGPoint(x: 100, y: 110), control2: CGPoint(x: 280, y: 150))
    p.addCurve(to: CGPoint(x: 372, y: 400), control1: CGPoint(x: 362, y: 300), control2: CGPoint(x: 372, y: 350))   // forehead
    p.addCurve(to: CGPoint(x: 366, y: 452), control1: CGPoint(x: 376, y: 425), control2: CGPoint(x: 364, y: 440))  // brow → eye
    p.addCurve(to: CGPoint(x: 432, y: 572), control1: CGPoint(x: 384, y: 492), control2: CGPoint(x: 420, y: 538))  // nose ridge
    p.addCurve(to: CGPoint(x: 396, y: 608), control1: CGPoint(x: 444, y: 592), control2: CGPoint(x: 418, y: 610))  // nose tip
    p.addCurve(to: CGPoint(x: 408, y: 660), control1: CGPoint(x: 396, y: 628), control2: CGPoint(x: 410, y: 642))  // upper lip
    p.addCurve(to: CGPoint(x: 390, y: 682), control1: CGPoint(x: 406, y: 672), control2: CGPoint(x: 396, y: 678))
    p.addCurve(to: CGPoint(x: 402, y: 718), control1: CGPoint(x: 400, y: 690), control2: CGPoint(x: 406, y: 706))  // lower lip
    p.addCurve(to: CGPoint(x: 378, y: 752), control1: CGPoint(x: 398, y: 735), control2: CGPoint(x: 382, y: 742))  // chin crease
    p.addCurve(to: CGPoint(x: 392, y: 810), control1: CGPoint(x: 376, y: 770), control2: CGPoint(x: 394, y: 790))  // chin
    p.addCurve(to: CGPoint(x: 300, y: 862), control1: CGPoint(x: 388, y: 842), control2: CGPoint(x: 340, y: 856))  // jaw
    p.addCurve(to: CGPoint(x: 296, y: 1044), control1: CGPoint(x: 290, y: 920), control2: CGPoint(x: 296, y: 990)) // neck
    p.addLine(to: CGPoint(x: -80, y: 1044))
    p.closeSubpath()
    return p
}

func drawRubin() {
    background()
    var nudge = CGAffineTransform(translationX: 18, y: 10)
    let base = profilePath().copy(using: &nudge)!
    var mirror = CGAffineTransform(translationX: S, y: 0).scaledBy(x: -1, y: 1)
    let right = base.copy(using: &mirror)!

    // Flat fills: champagne for you, steel blue for your famous twin.
    for (path, color) in [(base, UInt32(0xD9B26F)), (right, UInt32(0x9DB2CF))] {
        ctx.addPath(path)
        ctx.setFillColor(col(color))
        ctx.fillPath()
    }
    drawStar(at: CGPoint(x: S / 2, y: 448), radius: 84, glow: 56)
}

concept == "rubin" ? drawRubin() : drawLens()

let image = ctx.makeImage()!
let rep = NSBitmapImageRep(cgImage: image)
let png = rep.representation(using: .png, properties: [:])!
try png.write(to: URL(fileURLWithPath: outPath))
print("wrote \(outPath)")
