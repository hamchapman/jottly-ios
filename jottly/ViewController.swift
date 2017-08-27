import UIKit
import CoreLocation
import UserNotifications

class ViewController: UIViewController {

    @IBAction func showLogsButton(_ sender: Any) {
        hcLogger.presentLogsInViewController(self)
    }

    let locationManager = CLLocationManager()

    let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }()

    override func viewDidLoad() {
        super.viewDidLoad()

        hcLogger.addLogViewGesture(self)

        hcLogger.addToLogs(text: "LAUNCHED")

        configureLocationServices()
        configureNotifications()
    }

}

// MARK: UNUserNotificationCenterDelegate

extension ViewController: UNUserNotificationCenterDelegate {

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        hcLogger.addToLogs(text: "NOTIFICATION RECEIVED AND WATNS TO BE SHOWN")
        completionHandler([.sound, .alert, .badge])
    }
}

// MARK: CLLocationManagerDelegate

extension ViewController: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didVisit visit: CLVisit) {
        var text: String?
        var text2: String?
        if visit.departureDate != Date.distantFuture {
            text = "departed"
            text2 = dateFormatter.string(from: visit.departureDate)
        } else if visit.arrivalDate != Date.distantPast {
            text = "arrived"
            text2 = dateFormatter.string(from: visit.arrivalDate)
        }
        guard let action = text, let date = text2 else { return }
        let coords = "\(visit.coordinate.longitude), \(visit.coordinate.latitude)"
        displayNotification(title: action, subtitle: date, body: coords)
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        let title = "Sig. Location Update"
        let date = dateFormatter.string(from: location.timestamp)
        let coords = "\(location.coordinate.longitude), \(location.coordinate.latitude)"
        displayNotification(title: title, subtitle: date, body: coords)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        displayNotification(title: "Error", subtitle: "Location Manager", body: error.localizedDescription)
    }
}

// MARK: Private

extension ViewController {
    fileprivate func configureLocationServices() {
        locationManager.delegate = self
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.pausesLocationUpdatesAutomatically = false
        // Request authorization, if needed.

        let authorizationStatus = CLLocationManager.authorizationStatus()
        switch authorizationStatus {
        case .notDetermined:
            // Request authorization.
            locationManager.requestAlwaysAuthorization()
            break
        default:
            break
        }

        locationManager.startMonitoringVisits()

        locationManager.startMonitoringSignificantLocationChanges()
    }

    fileprivate func configureNotifications() {
        UNUserNotificationCenter.current().delegate = self
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    fileprivate func displayNotification(title: String, subtitle: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.subtitle = subtitle
        content.body = body
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }

}
