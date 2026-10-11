// Draws a screen captured by screenshots.exs as a PNG, a 9x16 cell per
// character like a VGA text screen (80x25 = 720x400). macOS only (AppKit).
//
//     swiftc -O tools/screenshots/render.swift -o tmp/render-screen
//     tmp/render-screen screen.cells screen.png
//
// A .cells file has one line per screen row; a row is segments separated by
// U+001F, each segment "FOREGROUND<TAB>BACKGROUND<TAB>TEXT" with the colours
// as six hex digits; a "_" after the foreground underlines the text.
import AppKit

let args = CommandLine.arguments
guard args.count == 3, let data = try? String(contentsOfFile: args[1], encoding: .utf8) else {
  FileHandle.standardError.write("usage: render-screen in.cells out.png\n".data(using: .utf8)!)
  exit(1)
}

let rows = data.components(separatedBy: "\n")
let cellWidth: CGFloat = 9, cellHeight: CGFloat = 16
func segments(_ row: String) -> [(Substring, Substring, Substring)] {
  row.components(separatedBy: "\u{1F}").compactMap { segment in
    let parts = segment.split(separator: "\t", maxSplits: 2, omittingEmptySubsequences: false)
    return parts.count == 3 ? (parts[0], parts[1], parts[2]) : nil
  }
}

let columns = rows.map { segments($0).map { $0.2.count }.reduce(0, +) }.max() ?? 80
let width = Int(cellWidth) * columns, height = Int(cellHeight) * rows.count

let bitmap = NSBitmapImageRep(
  bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height, bitsPerSample: 8,
  samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
  bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)

func colour(_ hex: Substring) -> NSColor {
  let v = Int(hex, radix: 16) ?? 0
  return NSColor(
    deviceRed: CGFloat((v >> 16) & 255) / 255, green: CGFloat((v >> 8) & 255) / 255,
    blue: CGFloat(v & 255) / 255, alpha: 1)
}

let font = NSFont(name: "Menlo", size: 14.5)!
NSColor.black.setFill()
NSRect(x: 0, y: 0, width: width, height: height).fill()

for (r, row) in rows.enumerated() {
  var x = 0
  let y = CGFloat(height) - CGFloat(r + 1) * cellHeight
  for (fgHex, bgHex, text) in segments(row) {
    let underline = fgHex.hasSuffix("_")
    let fg = colour(underline ? fgHex.dropLast() : fgHex), bg = colour(bgHex)
    for character in text {
      let cell = NSRect(x: CGFloat(x) * cellWidth, y: y, width: cellWidth, height: cellHeight)
      bg.setFill()
      cell.fill()
      NSAttributedString(string: String(character), attributes: [.font: font, .foregroundColor: fg])
        .draw(at: cell.origin)
      if underline {
        fg.setFill()
        NSRect(x: cell.minX, y: cell.minY + 1, width: cellWidth, height: 1).fill()
      }
      x += 1
    }
  }
}

NSGraphicsContext.restoreGraphicsState()
try! bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: args[2]))
