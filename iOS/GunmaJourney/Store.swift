import CoreLocation

import SwiftUI
import ImageIO
import UIKit

@MainActor final class JourneyStore: ObservableObject {
    @Published var places: [Place] = []
    @Published var descriptions: [String: PlaceCopy] = [:]
    @Published private(set) var visits: [String: Visit] = [:]
    @Published var errorMessage: String?
    private let directory: URL
    private var visitsURL: URL {
        return directory.appendingPathComponent("visits.json")
    }
    init() {
        directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("Journey", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let decoder = JSONDecoder(); decoder.keyDecodingStrategy = .convertFromSnakeCase
            guard let regions = Bundle.main.url(forResource: "regions", withExtension: "json"),
                  let copy = Bundle.main.url(forResource: "descriptions", withExtension: "json") else { throw StoreError.message("地点データを読み込めませんでした。") }
            places = try decoder.decode(Catalog.self, from: Data(contentsOf: regions)).locations
            descriptions = try decoder.decode([String: PlaceCopy].self, from: Data(contentsOf: copy))
            if FileManager.default.fileExists(atPath: visitsURL.path) {
                visits = try JSONDecoder().decode([String: Visit].self, from: Data(contentsOf: visitsURL))
            }
        } catch { errorMessage = "データを読み込めませんでした：\(error.localizedDescription)" }
    }
    var visitedCount: Int { places.filter { visit($0).status != .unvisited }.count }
    var liveCount: Int { visits.values.filter { $0.liveDate != nil }.count }
    var photoCount: Int { visits.values.filter { $0.liveDate == nil && $0.photoDate != nil }.count }
    func visit(_ place: Place) -> Visit { visits[place.id] ?? Visit() }
    private func save(_ changed: [String: Visit]) throws {
        // Publish success only after the atomic disk write succeeds.
        try JSONEncoder().encode(changed).write(to: visitsURL, options: [.atomic, .completeFileProtection])
        visits = changed
    }
    func stamp(_ place: Place, fix: CLLocation) throws {
        guard VisitRule.canStamp(place, fix: fix) else { throw StoreError.message("判定範囲内で、現在地をもう一度確認してください。") }
        var changed = visits; var v = visit(place)
        if v.liveDate == nil { v.liveDate = Date() }
        changed[place.id] = v; try save(changed)
    }
    func addImportedPhoto(_ data: Data, to place: Place) throws {
        guard let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary),
              let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: 1600
              ] as CFDictionary) else { throw StoreError.message("写真を読み込めませんでした。") }
        let image = UIImage(cgImage: cgImage)
        let metadata = PhotoMetadata(data: data)
        let needsLocation = visit(place).liveDate == nil
        if needsLocation {
            guard let coordinate = metadata.coordinate else { throw StoreError.message("この写真には位置情報が含まれていません。位置情報付きの写真を選んでください。") }
            guard VisitRule.photoInside(place, coordinate: coordinate) else { throw StoreError.message("写真の撮影場所が、この地点の判定範囲外です。") }
        }
        try savePhoto(image, place: place, imported: needsLocation, dateLabel: metadata.dateLabel, coordinate: metadata.coordinate)
    }
    func addCameraPhoto(_ image: UIImage, to place: Place, fix: CLLocation? = nil) throws {
        guard visit(place).liveDate != nil else { throw StoreError.message("先に現地スタンプを押してください。") }
        let formatter = DateFormatter(); formatter.locale = Locale(identifier: "en_US_POSIX"); formatter.dateFormat = "yyyy.MM.dd"
        let coordinate = fix.flatMap { VisitRule.validFix($0) ? $0.coordinate : nil }
        try savePhoto(image, place: place, imported: false, dateLabel: formatter.string(from: Date()), coordinate: coordinate)
    }
    private func savePhoto(_ image: UIImage, place: Place, imported: Bool, dateLabel: String?, coordinate: CLLocationCoordinate2D?) throws {
        let maxSide: CGFloat = 1600
        let scale = min(1, maxSide / max(image.size.width, image.size.height))
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat(); format.scale = 1
        let resized = UIGraphicsImageRenderer(size: size, format: format).image { _ in image.draw(in: CGRect(origin: .zero, size: size)) }
        guard let bytes = resized.jpegData(compressionQuality: 0.85) else { throw StoreError.message("写真を保存できませんでした。") }
        let filename = UUID().uuidString + ".jpg"
        let url = directory.appendingPathComponent(filename)
        try bytes.write(to: url, options: [.atomic, .completeFileProtection])
        var changed = visits; var v = visit(place); let old = v.photoFilename
        v.photoFilename = filename
        v.capturedDateLabel = dateLabel
        v.capturedLatitude = coordinate?.latitude
        v.capturedLongitude = coordinate?.longitude
        if imported { v.photoDate = Date() }
        changed[place.id] = v
        do { try save(changed) } catch { try? FileManager.default.removeItem(at: url); throw error }
        if let old { try? FileManager.default.removeItem(at: directory.appendingPathComponent(old)) }
    }
    func thumbnail(for place: Place) -> UIImage? {
        guard let name = visit(place).photoFilename,
              let source = CGImageSourceCreateWithURL(directory.appendingPathComponent(name) as CFURL, nil),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: 240
              ] as CFDictionary) else { return nil }
        return UIImage(cgImage: image)
    }
    func image(for place: Place) -> UIImage? {
        guard let name = visit(place).photoFilename else { return nil }
        return UIImage(contentsOfFile: directory.appendingPathComponent(name).path)
    }
}
enum StoreError: LocalizedError {
    case message(String)
    var errorDescription: String? { if case .message(let value) = self { return value }; return nil }
}

struct PhotoMetadata {
    var dateLabel: String?
    var coordinate: CLLocationCoordinate2D?
    init(data: Data) {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any] else { return }
        if let exif = props[kCGImagePropertyExifDictionary as String] as? [String: Any],
           let raw = exif[kCGImagePropertyExifDateTimeOriginal as String] as? String {
            let formatter = DateFormatter(); formatter.locale = Locale(identifier: "en_US_POSIX"); formatter.timeZone = TimeZone(secondsFromGMT: 0); formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"; formatter.isLenient = false
            if let date = formatter.date(from: raw) { formatter.dateFormat = "yyyy.MM.dd"; dateLabel = formatter.string(from: date) }
        }
        if let gps = props[kCGImagePropertyGPSDictionary as String] as? [String: Any],
           let lat = gps[kCGImagePropertyGPSLatitude as String] as? Double,
           let lon = gps[kCGImagePropertyGPSLongitude as String] as? Double,
           let ns = gps[kCGImagePropertyGPSLatitudeRef as String] as? String,
           let ew = gps[kCGImagePropertyGPSLongitudeRef as String] as? String,
           ["N", "S"].contains(ns), ["E", "W"].contains(ew), lat >= 0, lon >= 0 {
            let value = CLLocationCoordinate2D(latitude: ns == "S" ? -lat : lat, longitude: ew == "W" ? -lon : lon)
            if CLLocationCoordinate2DIsValid(value) { coordinate = value }
        }
    }
}
