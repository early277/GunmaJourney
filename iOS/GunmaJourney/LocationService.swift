import CoreLocation
import SwiftUI

@MainActor final class LocationService: NSObject, ObservableObject, @preconcurrency CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    @Published var fix: CLLocation?
    @Published var busy = false
    @Published var message: String?
    @Published var denied = false
    private var timeout: Task<Void, Never>?
    override init() {
        super.init(); manager.delegate = self; manager.desiredAccuracy = kCLLocationAccuracyBest
    }
    func refresh() {
        fix = nil; message = nil
        switch manager.authorizationStatus {
        case .notDetermined: busy = true; manager.requestWhenInUseAuthorization()
        case .denied, .restricted: denied = true; busy = false; message = "設定で位置情報の利用を許可してください。"
        default: start()
        }
    }
    private func start() {
        denied = false
        guard manager.accuracyAuthorization == .fullAccuracy else {
            busy = false
            message = "スタンプの判定には正確な位置情報が必要です。設定アプリで「群馬をめぐる」の位置情報を開き、「正確な位置情報」をオンにしてください。"
            return
        }
        busy = true
        manager.startUpdatingLocation()
        timeout?.cancel()
        timeout = Task { [weak self] in
            try? await Task.sleep(for: .seconds(20))
            guard !Task.isCancelled, let self else { return }
            self.manager.stopUpdatingLocation(); self.busy = false
            if self.fix == nil { self.message = "現在地を確認できませんでした。空の見える安全な場所で再試行してください。" }
        }
    }
    func stop() { manager.stopUpdatingLocation(); timeout?.cancel(); busy = false }
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard busy else { return }
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse: start()
        case .denied, .restricted: denied = true; busy = false; message = "設定で位置情報の利用を許可してください。"
        default: break
        }
    }
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let latest = locations.last, VisitRule.validFix(latest) else { return }
        fix = latest; busy = false; message = nil
    }
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        guard (error as? CLError)?.code != .locationUnknown else { return }
        stop(); message = "現在地を取得できませんでした。位置情報の設定を確認してください。"
    }
}
