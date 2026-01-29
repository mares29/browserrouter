#!/usr/bin/env swift
// Generates a DMG background image with branding

import Cocoa
import UniformTypeIdentifiers

let width = 540
let height = 400
let outputPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "dmg-background.png"

// Create bitmap context
guard let context = CGContext(
    data: nil,
    width: width,
    height: height,
    bitsPerComponent: 8,
    bytesPerRow: 0,
    space: CGColorSpaceCreateDeviceRGB(),
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else {
    print("Failed to create context")
    exit(1)
}

let rect = CGRect(x: 0, y: 0, width: width, height: height)

// Fill with light cream background (matching the provided image)
let bgColor = CGColor(red: 0.96, green: 0.96, blue: 0.95, alpha: 1.0)  // #F5F5F2
context.setFillColor(bgColor)
context.fill(rect)

// Draw circle icon in upper area
let circleY = Double(height) - 90.0
let circleX = Double(width) / 2.0
let circleRadius = 14.0

context.setStrokeColor(CGColor(red: 0.6, green: 0.6, blue: 0.6, alpha: 1.0))
context.setLineWidth(1.5)
context.addArc(center: CGPoint(x: circleX, y: circleY), radius: circleRadius, startAngle: 0, endAngle: .pi * 2, clockwise: true)
context.strokePath()

// Draw tagline text below circle
NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)

let textColor = NSColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1.0)

// "Links follow " in regular serif
let regularAttrs: [NSAttributedString.Key: Any] = [
    .font: NSFont(name: "Times New Roman", size: 24) ?? NSFont.systemFont(ofSize: 24),
    .foregroundColor: textColor
]

// "your focus" in italic serif
let italicAttrs: [NSAttributedString.Key: Any] = [
    .font: NSFont(name: "Times New Roman Italic", size: 24) ?? NSFont.systemFont(ofSize: 24),
    .foregroundColor: textColor
]

let part1 = NSAttributedString(string: "Links follow ", attributes: regularAttrs)
let part2 = NSAttributedString(string: "your focus", attributes: italicAttrs)

let fullText = NSMutableAttributedString()
fullText.append(part1)
fullText.append(part2)

let textSize = fullText.size()
let textX = (Double(width) - textSize.width) / 2.0
let textY = circleY - 45.0  // Below the circle

fullText.draw(at: NSPoint(x: textX, y: textY))

// Save image
guard let image = context.makeImage() else {
    print("Failed to create image")
    exit(1)
}

let url = URL(fileURLWithPath: outputPath)
guard let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
    print("Failed to create destination")
    exit(1)
}

CGImageDestinationAddImage(dest, image, nil)
if !CGImageDestinationFinalize(dest) {
    print("Failed to write image")
    exit(1)
}

print("Created \(outputPath)")
