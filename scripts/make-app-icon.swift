#!/usr/bin/env swift
// Draws Bikr's app icon: a white bicycle on an orange gradient.
// Run with: swift scripts/make-app-icon.swift [output.png]
// Nothing here is an SF Symbol — those may not be used in app icons.

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let side = 1024.0
let output = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first
    ?? "Bikr/Assets.xcassets/AppIcon.appiconset/AppIcon.png")

let space = CGColorSpace(name: CGColorSpace.sRGB)!
guard let context = CGContext(
    data: nil, width: Int(side), height: Int(side), bitsPerComponent: 8, bytesPerRow: 0,
    space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else { fatalError("Could not create the drawing context") }

// Background: orange, lighter at the top.
let gradient = CGGradient(
    colorsSpace: space,
    colors: [
        CGColor(srgbRed: 1.00, green: 0.60, blue: 0.13, alpha: 1),
        CGColor(srgbRed: 0.93, green: 0.33, blue: 0.03, alpha: 1),
    ] as CFArray,
    locations: [0, 1]
)!
context.drawLinearGradient(gradient, start: CGPoint(x: 0, y: side), end: CGPoint(x: side, y: 0), options: [])

// Bicycle, drawn in a 1024 grid with the origin at the bottom left.
// Kept inside the middle ~72% so the shape survives the rounded icon mask.
let wheelRadius = 168.0
let rearHub = CGPoint(x: 320, y: 404)
let frontHub = CGPoint(x: 704, y: 404)
let bottomBracket = CGPoint(x: 496, y: 404)
let seat = CGPoint(x: 412, y: 620)
let headTop = CGPoint(x: 648, y: 636)

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

guard let image = context.makeImage() else { fatalError("Could not render the icon") }
try? FileManager.default.createDirectory(at: output.deletingLastPathComponent(), withIntermediateDirectories: true)
guard let destination = CGImageDestinationCreateWithURL(output as CFURL, UTType.png.identifier as CFString, 1, nil) else {
    fatalError("Could not write to \(output.path)")
}
CGImageDestinationAddImage(destination, image, nil)
guard CGImageDestinationFinalize(destination) else { fatalError("Could not finish writing the icon") }
print("Wrote \(output.path)")
