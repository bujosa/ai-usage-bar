import AppKit
import ImageIO
import UniformTypeIdentifiers

let canvas: CGFloat = 1024

func rounded(_ rect: CGRect, radius: CGFloat) -> CGPath {
    let path = CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
    return path
}

let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
guard let context = CGContext(
    data: nil,
    width: Int(canvas),
    height: Int(canvas),
    bitsPerComponent: 8,
    bytesPerRow: 0,
    space: colorSpace,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else {
    fputs("no context\n", stderr)
    exit(1)
}

let bounds = CGRect(x: 0, y: 0, width: canvas, height: canvas)
let shape = rounded(bounds, radius: canvas * 0.2237)
context.addPath(shape)
context.clip()

let colors = [
    CGColor(srgbRed: 0.27, green: 0.27, blue: 0.29, alpha: 1),
    CGColor(srgbRed: 0.14, green: 0.14, blue: 0.15, alpha: 1),
] as CFArray
let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: colors, locations: [0, 1])!
context.drawLinearGradient(gradient, start: CGPoint(x: 0, y: canvas), end: CGPoint(x: 0, y: 0), options: [])

let trackHeight = canvas * 0.092
let trackInset = canvas * 0.16
let track = CGRect(
    x: trackInset,
    y: (canvas - trackHeight) / 2,
    width: canvas - trackInset * 2,
    height: trackHeight
)
context.setFillColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.16))
context.addPath(rounded(track, radius: trackHeight / 2))
context.fillPath()

let fillWidth = track.width * 0.72
let fill = CGRect(x: track.minX, y: track.minY, width: fillWidth, height: track.height)
context.setFillColor(CGColor(srgbRed: 0.95, green: 0.62, blue: 0.34, alpha: 1))
context.addPath(rounded(fill, radius: trackHeight / 2))
context.fillPath()

let out = URL(fileURLWithPath: CommandLine.arguments[1])
guard let image = context.makeImage() else {
    fputs("encode failed\n", stderr)
    exit(1)
}
guard let destination = CGImageDestinationCreateWithURL(out as CFURL, UTType.png.identifier as CFString, 1, nil) else {
    fputs("destination failed\n", stderr)
    exit(1)
}
CGImageDestinationAddImage(destination, image, nil)
guard CGImageDestinationFinalize(destination) else {
    fputs("write failed\n", stderr)
    exit(1)
}
