// App Store 用スクリーンショットに見出しと端末の枠をつける
//   swift tools/frame_screenshots.swift <撮影したフォルダ> <出力先フォルダ>
// 出力は撮影画像と同じピクセルサイズ（例: 6.9インチ 1320×2868）・アルファなし
import AppKit

let args = CommandLine.arguments.dropFirst()
guard args.count == 2 else {
    print("使い方: swift tools/frame_screenshots.swift <撮影したフォルダ> <出力先フォルダ>")
    exit(1)
}
let inDir = URL(fileURLWithPath: args[args.startIndex])
let outDir = URL(fileURLWithPath: args[args.startIndex + 1])
try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

// 並び順 = App Store での表示順。[ ] で囲んだ部分を青で強調する
let pages: [(file: String, title: String, subtitle: String)] = [
    ("1_home", "今日の薬が[ひと目で]", "朝・昼・夜・寝る前、タップで服用を記録"),
    ("2_interactions", "[飲み合わせ]をチェック", "添付文書をもとに、今の薬どうしを確認"),
    ("3_foods", "[飲食物]の注意もわかる", "お酒・グレープフルーツ・牛乳など"),
    ("7_settings", "飲む時間に[お知らせ]", "記録がなければ、もう一度通知します"),
    ("5_records", "続けた成果が[見える]", "週・月・年の服薬達成率をグラフで"),
    ("4_calendar", "[カレンダー]で振り返り", "飲めた日・飲み忘れた日が色でわかる"),
    ("6_edit", "写真で[かんたん登録]", "成分を選ぶと、飲み合わせも確認できます"),
]

let navy = NSColor(red: 0.11, green: 0.17, blue: 0.29, alpha: 1)
let blue = NSColor(red: 0.18, green: 0.50, blue: 0.88, alpha: 1)
let gray = NSColor(red: 0.36, green: 0.42, blue: 0.52, alpha: 1)

func headline(_ text: String, size: CGFloat) -> NSAttributedString {
    let font = NSFont(name: "HiraginoSans-W8", size: size) ?? .boldSystemFont(ofSize: size)
    let para = NSMutableParagraphStyle()
    para.alignment = .center
    let s = NSMutableAttributedString()
    var accent = false
    var chunk = ""
    func flush() {
        s.append(NSAttributedString(string: chunk, attributes: [.font: font, .foregroundColor: accent ? blue : navy,
                                                                .paragraphStyle: para, .kern: size * 0.02]))
        chunk = ""
    }
    for c in text {
        if c == "[" || c == "]" { flush(); accent = c == "[" } else { chunk.append(c) }
    }
    flush()
    return s
}

func body(_ text: String, size: CGFloat) -> NSAttributedString {
    let para = NSMutableParagraphStyle()
    para.alignment = .center
    return NSAttributedString(string: text, attributes: [
        .font: NSFont(name: "HiraginoSans-W5", size: size) ?? .systemFont(ofSize: size),
        .foregroundColor: gray, .paragraphStyle: para])
}

// 横幅に収まるまで文字を小さくする
func fitted(_ make: (CGFloat) -> NSAttributedString, size: CGFloat, maxWidth: CGFloat) -> NSAttributedString {
    var s = size
    var a = make(s)
    while a.size().width > maxWidth && s > 10 { s -= 2; a = make(s) }
    return a
}

for page in pages {
    let src = inDir.appendingPathComponent(page.file + ".png")
    guard let shot = NSImage(contentsOf: src)?.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
        print("× \(src.path) がありません"); continue
    }
    let W = CGFloat(shot.width), H = CGFloat(shot.height)
    let ctx = CGContext(data: nil, width: Int(W), height: Int(H), bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!

    // 背景：アプリと同じ淡い青のグラデーション＋右上に光
    let bg = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                        colors: [NSColor(red: 0.95, green: 0.97, blue: 1.0, alpha: 1).cgColor,
                                 NSColor(red: 0.80, green: 0.89, blue: 0.99, alpha: 1).cgColor] as CFArray,
                        locations: [0, 1])!
    ctx.drawLinearGradient(bg, start: CGPoint(x: 0, y: H), end: CGPoint(x: W * 0.3, y: 0),
                           options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
    let glow = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                          colors: [NSColor.white.withAlphaComponent(0.9).cgColor, NSColor.white.withAlphaComponent(0).cgColor] as CFArray,
                          locations: [0, 1])!
    ctx.drawRadialGradient(glow, startCenter: CGPoint(x: W * 0.85, y: H * 0.95), startRadius: 0,
                           endCenter: CGPoint(x: W * 0.85, y: H * 0.95), endRadius: W * 0.8, options: [])

    // 見出し
    NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)
    let margin = W * 0.07
    let title = fitted({ headline(page.title, size: $0) }, size: W * 0.082, maxWidth: W - margin * 2)
    let sub = fitted({ body(page.subtitle, size: $0) }, size: W * 0.040, maxWidth: W - margin * 2)
    let titleTop = H - W * 0.15
    let th = title.size().height, sh = sub.size().height
    title.draw(in: CGRect(x: margin, y: titleTop - th, width: W - margin * 2, height: th))
    sub.draw(in: CGRect(x: margin, y: titleTop - th - W * 0.03 - sh, width: W - margin * 2, height: sh))
    NSGraphicsContext.current = nil

    // 端末（黒いベゼル＋画面）。下端は少しはみ出させる
    let screenW = W * 0.80, screenH = screenW * H / W
    let bezel = W * 0.022
    let screen = CGRect(x: (W - screenW) / 2, y: titleTop - th - sh - W * 0.09 - bezel - screenH,
                        width: screenW, height: screenH)
    let radius = screenW * 0.125
    let frame = screen.insetBy(dx: -bezel, dy: -bezel)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -W * 0.02), blur: W * 0.06,
                  color: NSColor(red: 0.10, green: 0.25, blue: 0.50, alpha: 0.30).cgColor)
    ctx.addPath(CGPath(roundedRect: frame, cornerWidth: radius + bezel, cornerHeight: radius + bezel, transform: nil))
    ctx.setFillColor(NSColor(white: 0.10, alpha: 1).cgColor)
    ctx.fillPath()
    ctx.restoreGState()
    // ベゼルのふちを少し明るく
    ctx.addPath(CGPath(roundedRect: frame.insetBy(dx: W * 0.002, dy: W * 0.002),
                       cornerWidth: radius + bezel, cornerHeight: radius + bezel, transform: nil))
    ctx.setStrokeColor(NSColor(white: 0.35, alpha: 1).cgColor)
    ctx.setLineWidth(W * 0.003)
    ctx.strokePath()
    ctx.saveGState()
    ctx.addPath(CGPath(roundedRect: screen, cornerWidth: radius, cornerHeight: radius, transform: nil))
    ctx.clip()
    ctx.interpolationQuality = .high
    ctx.draw(shot, in: screen)
    ctx.restoreGState()

    let out = outDir.appendingPathComponent(String(format: "%02d_%@.png", pages.firstIndex { $0.file == page.file }! + 1,
                                                   String(page.file.drop { $0 != "_" }.dropFirst())))
    let rep = NSBitmapImageRep(cgImage: ctx.makeImage()!)
    try rep.representation(using: .png, properties: [:])!.write(to: out)
    print("→ \(out.path)")
}
