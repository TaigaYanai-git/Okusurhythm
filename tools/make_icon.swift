// アプリアイコン（1024px）を描く: swift tools/make_icon.swift <出力先.png>
import AppKit

let size: CGFloat = 1024
let out = CommandLine.arguments.dropFirst().first ?? "AppIcon.png"
// アルファなしの RGB（App Store の要件）
let ctx = CGContext(data: nil, width: Int(size), height: Int(size), bitsPerComponent: 8, bytesPerRow: 0,
                    space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!

// 背景：青のグラデーション（App Store 側で角丸になるので四角のまま塗る）
let bg = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                    colors: [NSColor(red: 0.42, green: 0.74, blue: 0.98, alpha: 1).cgColor,
                             NSColor(red: 0.16, green: 0.48, blue: 0.86, alpha: 1).cgColor] as CFArray,
                    locations: [0, 1])!
ctx.drawLinearGradient(bg, start: CGPoint(x: 0, y: size), end: CGPoint(x: size, y: 0), options: [])

// カプセル（左上→右下に 45° 傾ける）
ctx.saveGState()
ctx.translateBy(x: size * 0.46, y: size * 0.54)
ctx.rotate(by: .pi / 4)
let w: CGFloat = 660, h: CGFloat = 270
let capsule = CGRect(x: -w / 2, y: -h / 2, width: w, height: h)
ctx.setShadow(offset: CGSize(width: 0, height: -14), blur: 30, color: NSColor.black.withAlphaComponent(0.18).cgColor)
ctx.addPath(CGPath(roundedRect: capsule, cornerWidth: h / 2, cornerHeight: h / 2, transform: nil))
ctx.setFillColor(NSColor.white.cgColor)
ctx.fillPath()
ctx.setShadow(offset: .zero, blur: 0)
// 右半分を淡い青に
ctx.addPath(CGPath(roundedRect: capsule, cornerWidth: h / 2, cornerHeight: h / 2, transform: nil))
ctx.clip()
ctx.setFillColor(NSColor(red: 0.80, green: 0.90, blue: 1.0, alpha: 1).cgColor)
ctx.fill(CGRect(x: 0, y: -h / 2, width: w / 2, height: h))
ctx.setStrokeColor(NSColor(red: 0.16, green: 0.48, blue: 0.86, alpha: 0.35).cgColor)
ctx.setLineWidth(10)
ctx.move(to: CGPoint(x: 0, y: -h / 2)); ctx.addLine(to: CGPoint(x: 0, y: h / 2)); ctx.strokePath()
ctx.restoreGState()

// チェックのバッジ
let r: CGFloat = 170
let center = CGPoint(x: size * 0.73, y: size * 0.27)
ctx.setShadow(offset: CGSize(width: 0, height: -8), blur: 20, color: NSColor.black.withAlphaComponent(0.2).cgColor)
ctx.setFillColor(NSColor.white.cgColor)
ctx.fillEllipse(in: CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2))
ctx.setShadow(offset: .zero, blur: 0)
ctx.setFillColor(NSColor(red: 0.18, green: 0.72, blue: 0.42, alpha: 1).cgColor)
let inner = r - 26
ctx.fillEllipse(in: CGRect(x: center.x - inner, y: center.y - inner, width: inner * 2, height: inner * 2))
ctx.setStrokeColor(NSColor.white.cgColor)
ctx.setLineWidth(38); ctx.setLineCap(.round); ctx.setLineJoin(.round)
ctx.move(to: CGPoint(x: center.x - 62, y: center.y + 2))
ctx.addLine(to: CGPoint(x: center.x - 14, y: center.y - 48))
ctx.addLine(to: CGPoint(x: center.x + 70, y: center.y + 52))
ctx.strokePath()
let rep = NSBitmapImageRep(cgImage: ctx.makeImage()!)
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
print("→ \(out)")
