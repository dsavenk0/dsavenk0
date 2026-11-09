import AppKit

// Баннер профиля (1280×360 PNG): окно терминала с короткой сессией —
// `whoami` печатает имя, `ls ~/projects` перечисляет проекты, каждый со своим
// мини-знаком в фирменном цвете (как на баннерах репозиториев). Приглашение —
// в цвете QUANTIX, нижняя полоса — белая.
// Использование: swift tools/make-banner.swift banner.png

let outPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "/tmp/profile-banner.png"
let W: CGFloat = 1280, H: CGFloat = 360

guard let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: Int(W), pixelsHigh: Int(H),
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
) else { exit(1) }

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

func rgb(_ hex: Int, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
}
let fg = rgb(0xEBEDF2)
let dim = rgb(0x858C99)
let promptColor = rgb(0x5C6370)
let red = rgb(0xFB0020), teal = rgb(0x22E3C8), orange = rgb(0xFF6B00), mint = rgb(0x4CE6B4)
let neon = rgb(0x00FF87)

/// Координата y, отсчитанная сверху (AppKit считает снизу).
func top(_ y: CGFloat) -> CGFloat { H - y }

func font(_ size: CGFloat, bold: Bool) -> NSFont {
    let name = bold ? "Menlo-Bold" : "Menlo-Regular"
    return NSFont(name: name, size: size) ?? NSFont.monospacedSystemFont(ofSize: size, weight: bold ? .bold : .regular)
}
@discardableResult
func text(_ s: String, _ x: CGFloat, _ baselineTop: CGFloat, _ size: CGFloat, _ color: NSColor,
          bold: Bool = false) -> CGFloat {
    let f = font(size, bold: bold)
    let str = NSAttributedString(string: s, attributes: [.font: f, .foregroundColor: color])
    str.draw(at: NSPoint(x: x, y: top(baselineTop) + f.descender))
    return x + str.size().width
}
func withGlow(_ color: NSColor, _ blur: CGFloat, _ draw: () -> Void) {
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = color
    shadow.shadowBlurRadius = blur
    shadow.shadowOffset = .zero
    shadow.set()
    draw()
    NSGraphicsContext.restoreGraphicsState()
}

// --- Фон и разноцветная нижняя полоса ---
if let grad = NSGradient(colors: [rgb(0x15171C), rgb(0x040507)]) {
    grad.draw(in: NSBezierPath(rect: NSRect(x: 0, y: 0, width: W, height: H)), angle: -60)
}
// Нижняя полоса — белая.
fg.withAlphaComponent(0.85).setFill()
NSBezierPath(rect: NSRect(x: 0, y: 0, width: W, height: 5)).fill()

// --- Окно терминала ---
let window = NSRect(x: 40, y: top(330), width: W - 80, height: 300)
let windowPath = NSBezierPath(roundedRect: window, xRadius: 16, yRadius: 16)
withGlow(NSColor.black.withAlphaComponent(0.7), 30) {
    rgb(0x0C0E12).setFill()
    windowPath.fill()
}
rgb(0xFFFFFF, 0.10).setStroke()
windowPath.lineWidth = 1.5
windowPath.stroke()

// Заголовок окна: три точки и путь.
NSGraphicsContext.saveGraphicsState()
windowPath.addClip()
rgb(0x171A20).setFill()
NSBezierPath(rect: NSRect(x: window.minX, y: top(70), width: window.width, height: 40)).fill()
NSGraphicsContext.restoreGraphicsState()
for (index, hex) in [0xFF5F57, 0xFEBC2E, 0x28C840].enumerated() {
    rgb(hex).setFill()
    NSBezierPath(ovalIn: NSRect(x: 64 + CGFloat(index) * 22, y: top(57), width: 14, height: 14)).fill()
}
let title = "dennis@mac — ~"
let titleWidth = NSAttributedString(string: title, attributes: [.font: font(16, bold: false)]).size().width
text(title, W / 2 - titleWidth / 2, 56, 16, dim)

// --- Сессия ---
let left: CGFloat = 72
func prompt(_ y: CGFloat) -> CGFloat {
    var x = text("~", left, y, 24, neon, bold: true)
    x = text(" $ ", x, y, 24, promptColor)
    return x
}

// $ whoami → имя крупно и таглайн.
text("whoami", prompt(122), 122, 24, fg)
let nameEnd = withGlowReturning()
func withGlowReturning() -> CGFloat {
    var end: CGFloat = 0
    withGlow(fg.withAlphaComponent(0.35), 18) { end = text("Dennis", left, 198, 64, fg, bold: true) }
    return end
}
text("market analytics · firmware · native tools · AI", nameEnd + 32, 190, 24, dim)

// $ ls ~/projects → мини-знаки и названия.
text("ls ~/projects", prompt(252), 252, 24, fg)

typealias Mark = (NSPoint, CGFloat) -> Void
let quantix: Mark = { c, s in
    // Атом из public/icon.svg: три эллипса через 60° и куб в центре.
    withGlow(neon.withAlphaComponent(0.8), 8) {
        neon.setStroke()
        let unit = s / 22
        for angle in [CGFloat(0), 60, 120] {
            let orbit = NSBezierPath(ovalIn: NSRect(x: -10.5 * unit, y: -4 * unit, width: 21 * unit, height: 8 * unit))
            let t = NSAffineTransform()
            t.translateX(by: c.x, yBy: c.y)
            t.rotate(byDegrees: angle)
            orbit.transform(using: t as AffineTransform)
            orbit.lineWidth = 1.6
            orbit.stroke()
        }
        let cube = NSBezierPath()
        let corners = [(0.0, 2.2), (1.9, 1.1), (1.9, -1.1), (0.0, -2.2), (-1.9, -1.1), (-1.9, 1.1)]
        for (index, corner) in corners.enumerated() {
            let point = NSPoint(x: c.x + CGFloat(corner.0) * unit, y: c.y + CGFloat(corner.1) * unit)
            index == 0 ? cube.move(to: point) : cube.line(to: point)
        }
        cube.close()
        for corner in [(0.0, -2.2), (1.9, 1.1), (-1.9, 1.1)] {
            cube.move(to: c)
            cube.line(to: NSPoint(x: c.x + CGFloat(corner.0) * unit, y: c.y + CGFloat(corner.1) * unit))
        }
        cube.lineWidth = 1.6
        cube.lineJoinStyle = .round
        cube.stroke()
    }
}
let xenos: Mark = { c, s in
    // Два шеврона с разрывом; красный луч проходит под ними.
    red.withAlphaComponent(0.8).setFill()
    NSBezierPath(rect: NSRect(x: c.x - s * 0.62, y: c.y - 0.75, width: s * 1.24, height: 1.5)).fill()
    withGlow(red.withAlphaComponent(0.8), 8) {
        rgb(0xD9DBDF).setStroke()
        for dir in [CGFloat(1), -1] {
            let p = NSBezierPath()
            p.move(to: NSPoint(x: c.x - s * 0.5, y: c.y + dir * s * 0.44))
            p.line(to: NSPoint(x: c.x - s * 0.12, y: c.y + dir * s * 0.17))
            p.line(to: NSPoint(x: c.x + s * 0.12, y: c.y + dir * s * 0.17))
            p.line(to: NSPoint(x: c.x + s * 0.5, y: c.y + dir * s * 0.44))
            p.lineWidth = s * 0.16
            p.lineJoinStyle = .round
            p.stroke()
        }
    }
}
let qubit: Mark = { c, s in
    withGlow(teal.withAlphaComponent(0.8), 8) {
        func hexagon(_ r: CGFloat) -> NSBezierPath {
            let p = NSBezierPath()
            for i in 0..<6 {
                let a = (CGFloat(i) * 60 + 90) * .pi / 180
                let point = NSPoint(x: c.x + r * cos(a), y: c.y + r * sin(a))
                i == 0 ? p.move(to: point) : p.line(to: point)
            }
            p.close()
            return p
        }
        teal.setStroke()
        let shell = hexagon(s * 0.46)
        shell.lineWidth = s * 0.11
        shell.lineJoinStyle = .round
        shell.stroke()
        teal.setFill()
        hexagon(s * 0.18).fill()
        let tail = NSBezierPath()
        tail.move(to: NSPoint(x: c.x + s * 0.24, y: c.y - s * 0.15))
        tail.line(to: NSPoint(x: c.x + s * 0.48, y: c.y - s * 0.29))
        tail.lineWidth = s * 0.11
        tail.lineCapStyle = .round
        tail.stroke()
    }
}
let netkill: Mark = { c, s in
    withGlow(orange.withAlphaComponent(0.8), 8) {
        orange.setStroke()
        let origin = NSPoint(x: c.x, y: c.y - s * 0.12)
        for radius in [s * 0.22, s * 0.38, s * 0.54] {
            let arc = NSBezierPath()
            arc.appendArc(withCenter: origin, radius: radius, startAngle: 42, endAngle: 138)
            arc.lineWidth = s * 0.09
            arc.lineCapStyle = .round
            arc.stroke()
        }
        orange.setFill()
        NSBezierPath(ovalIn: NSRect(x: c.x - s * 0.08, y: c.y - s * 0.46, width: s * 0.16, height: s * 0.16)).fill()
    }
}
let engine: Mark = { c, s in
    let tile = NSBezierPath(roundedRect: NSRect(x: c.x - s * 0.5, y: c.y - s * 0.5, width: s, height: s),
                            xRadius: s * 0.24, yRadius: s * 0.24)
    rgb(0x0F1A17).setFill()
    tile.fill()
    mint.withAlphaComponent(0.5).setStroke()
    tile.lineWidth = 1.5
    tile.stroke()
    withGlow(mint.withAlphaComponent(0.8), 6) {
        let f = font(s * 0.42, bold: true)
        let label = NSAttributedString(string: "Ai", attributes: [.font: f, .foregroundColor: mint])
        let size = label.size()
        label.draw(at: NSPoint(x: c.x - size.width / 2, y: c.y - size.height / 2))
    }
}

let items: [(Mark, String, NSColor)] = [
    (quantix, "QUANTIX", neon), (xenos, "X-enOS", red), (qubit, "QubitOS", teal),
    (netkill, "netKillUI", orange), (engine, "AI-llm-Engine", mint),
]
var x = left
let rowCenter = top(292)
for (mark, name, color) in items {
    mark(NSPoint(x: x + 18, y: rowCenter), 36)
    x = text(name, x + 46, 301, 24, color, bold: true) + 36
}

NSGraphicsContext.restoreGraphicsState()

guard let png = rep.representation(using: .png, properties: [:]) else { exit(1) }
do {
    try png.write(to: URL(fileURLWithPath: outPath))
    print("баннер: \(outPath)")
} catch {
    FileHandle.standardError.write(Data("ошибка записи баннера: \(error)\n".utf8))
    exit(1)
}
