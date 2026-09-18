#!/usr/bin/env swift
// Draws Bikr's bicycle twice: the app icon (white on an orange gradient) and
// the same bicycle on its own for the launch screen, so the two can never
// drift apart.
// Run with: swift scripts/make-app-icon.swift
// Nothing here is an SF Symbol — those may not be used in app icons.

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let side = 1024.0
let space = CGColorSpace(name: CGColorSpace.sRGB)!

func newContext() -> CGContext {
    guard let context = CGContext(
        data: nil, width: Int(side), height: Int(side), bitsPerComponent: 8, bytesPerRow: 0,
        space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { fatalError("Could not create the drawing context") }
    return context
}

/// Orange, lighter at the top.
func drawBackground(in context: CGContext) {
    let gradient = CGGradient(
        colorsSpace: space,
        colors: [
            CGColor(srgbRed: 1.00, green: 0.60, blue: 0.13, alpha: 1),
            CGColor(srgbRed: 0.93, green: 0.33, blue: 0.03, alpha: 1),
        ] as CFArray,
        locations: [0, 1]
    )!
    context.drawLinearGradient(gradient, start: CGPoint(x: 0, y: side), end: CGPoint(x: side, y: 0), options: [])
}

func drawBicycle(in context: CGContext) {
    // Laid out in a 1024 grid with the origin at the bottom left, then centred.
    let wheelRadius = 168.0
    let rearHub = CGPoint(x: 320, y: 404)
    let frontHub = CGPoint(x: 704, y: 404)
    let bottomBracket = CGPoint(x: 496, y: 404)
    let seat = CGPoint(x: 412, y: 620)
    let headTop = CGPoint(x: 648, y: 636)

    // Work out how far the ink actually spans, strokes included, and shift it
    // to the middle.
    let saddleTop = seat.y + 46 + 20
    let handlebarTop = headTop.y + 58 + 19
    let ink = (
        left: rearHub.x - wheelRadius - 25,
        right: frontHub.x + wheelRadius + 25,
        bottom: rearHub.y - wheelRadius - 25,
        top: max(rearHub.y + wheelRadius + 25, max(saddleTop, handlebarTop))
    )
    context.saveGState()
    context.translateBy(
        x: (side - (ink.left + ink.right)) / 2,
        y: (side - (ink.bottom + ink.top)) / 2
    )

    context.setStrokeColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1))
    context.setLineCap(.round)
    context.setLineJoin(.round)

    // Wheels.
    context.setLineWidth(50)
    for hub in [rearHub, frontHub] {
        context.addEllipse(in: CGRect(x: hub.x - wheelRadius, y: hub.y - wheelRadius,
                                      width: wheelRadius * 2, height: wheelRadius * 2))
    }
    context.strokePath()

    // Frame: chain stay, seat stay, seat tube, top tube, down tube and fork.
    context.setLineWidth(44)
    let frame: [(CGPoint, CGPoint)] = [
        (rearHub, bottomBracket),
        (rearHub, seat),
        (bottomBracket, seat),
        (seat, headTop),
        (bottomBracket, headTop),
        (headTop, frontHub),
    ]
    for (from, to) in frame {
        context.move(to: from)
        context.addLine(to: to)
    }
    context.strokePath()

    // Saddle, and a handlebar that hangs forward off the head tube.
    context.setLineWidth(40)
    context.move(to: CGPoint(x: seat.x - 74, y: seat.y + 34))
    context.addLine(to: CGPoint(x: seat.x + 46, y: seat.y + 46))
    context.strokePath()

    context.setLineWidth(38)
    context.move(to: CGPoint(x: headTop.x - 74, y: headTop.y + 58))
    context.addLine(to: CGPoint(x: headTop.x + 6, y: headTop.y + 58))
    context.addCurve(to: CGPoint(x: headTop.x + 78, y: headTop.y - 6),
                     control1: CGPoint(x: headTop.x + 62, y: headTop.y + 58),
                     control2: CGPoint(x: headTop.x + 78, y: headTop.y + 40))
    context.strokePath()
    context.restoreGState()
}

func write(_ context: CGContext, to path: String) {
    let url = URL(fileURLWithPath: path)
    guard let image = context.makeImage() else { fatalError("Could not render \(path)") }
    try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
        fatalError("Could not write to \(path)")
    }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else { fatalError("Could not finish writing \(path)") }
    print("Wrote \(path)")
}

let icon = newContext()
drawBackground(in: icon)
drawBicycle(in: icon)
write(icon, to: "Bikr/Assets.xcassets/AppIcon.appiconset/AppIcon.png")

// The bicycle alone, for the launch screen to show on its own background.
let mark = newContext()
drawBicycle(in: mark)
write(mark, to: "Bikr/Assets.xcassets/SplashMark.imageset/SplashMark.png")
