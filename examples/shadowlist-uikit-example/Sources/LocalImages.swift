import UIKit

/*
 * Photos for -SLImages local: JPEG files the app draws once into its caches folder, 1600 pixels
 * wide like the fixtures' originals. The image loader still reads, decodes and scales a real
 * file for every row, without the network. There are more of them than the loader's decoded
 * cache holds, and scrolling far keeps decoding like a feed of new photos does.
 */
enum LocalImages {
  static let count = 200
  private static let width: CGFloat = 1600

  private static var folder: URL {
    FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("bench-images", isDirectory: true)
  }

  static func url(_ index: Int) -> String {
    folder.appendingPathComponent("photo-\(index).jpg").absoluteString
  }

  /*
   * Draw the files that are missing. Runs at launch, before any list asks for an image.
   */
  static func prepare() {
    try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    for index in 0..<count {
      let file = folder.appendingPathComponent("photo-\(index).jpg")
      if FileManager.default.fileExists(atPath: file.path) { continue }
      try? draw(index).jpegData(compressionQuality: 0.8)?.write(to: file)
    }
  }

  /*
   * A gradient with a few circles, different for every index, in one of three aspect ratios.
   */
  private static func draw(_ index: Int) -> UIImage {
    let aspects: [CGFloat] = [0.75, 1, 0.5625]
    let size = CGSize(width: width, height: width * aspects[index % aspects.count])
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1
    format.opaque = true
    return UIGraphicsImageRenderer(size: size, format: format).image { context in
      let hue = CGFloat(index % 20) / 20
      let colors = [UIColor(hue: hue, saturation: 0.7, brightness: 0.4, alpha: 1).cgColor,
                    UIColor(hue: hue + 0.3, saturation: 0.6, brightness: 0.9, alpha: 1).cgColor]
      let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: [0, 1])!
      context.cgContext.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: size.width, y: size.height), options: [])
      for circle in 0..<12 {
        let radius = CGFloat(40 + (index * 37 + circle * 53) % 220)
        let center = CGPoint(x: CGFloat((index * 131 + circle * 389) % Int(size.width)), y: CGFloat((index * 71 + circle * 197) % Int(size.height)))
        UIColor(white: 1, alpha: 0.15 + CGFloat(circle % 4) * 0.08).setFill()
        context.cgContext.fillEllipse(in: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
      }
    }
  }
}
