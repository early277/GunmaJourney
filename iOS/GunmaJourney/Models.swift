import Foundation
import CoreLocation

struct Catalog: Decodable { let locations: [Place] }
struct Place: Decodable, Identifiable {
    let id: String
    let kana: String
    let destination: String
    let latitude: Double
    let longitude: Double
    let radiusM: Double
    let contextSourceUrl: String?
    let coordinateSourceUrl: String
    var coordinate: CLLocationCoordinate2D { .init(latitude: latitude, longitude: longitude) }
    func distance(from location: CLLocation) -> Double {
        CLLocation(latitude: latitude, longitude: longitude).distance(from: location)
    }
}
struct PlaceCopy: Decodable {
    let heading: String?
    let place: String
    let theme: String
    let sources: [PlaceSource]?
}
struct PlaceSource: Decodable {
    let title: String
    let url: String
}
struct Visit: Codable {
    var liveDate: Date?
    var photoDate: Date?
    var photoFilename: String?
    var capturedDateLabel: String?
    var capturedLatitude: Double?
    var capturedLongitude: Double?
    var status: VisitStatus { liveDate != nil ? .visited : photoDate != nil ? .photo : .unvisited }
}
enum VisitStatus { case unvisited, photo, visited }
enum VisitRule {
    static func validFix(_ fix: CLLocation, now: Date = Date()) -> Bool {
        fix.horizontalAccuracy >= 0 && fix.horizontalAccuracy <= 50 &&
        now.timeIntervalSince(fix.timestamp) >= -2 && now.timeIntervalSince(fix.timestamp) <= 15 &&
        CLLocationCoordinate2DIsValid(fix.coordinate)
    }
    static func canStamp(_ place: Place, fix: CLLocation, now: Date = Date()) -> Bool {
        validFix(fix, now: now) && place.distance(from: fix) <= place.radiusM
    }
    static func photoInside(_ place: Place, coordinate: CLLocationCoordinate2D) -> Bool {
        CLLocationCoordinate2DIsValid(coordinate) && place.distance(from: CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)) <= place.radiusM
    }
}
