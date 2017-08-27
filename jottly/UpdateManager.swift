import Foundation
import CoreMotion
import CoreLocation

public class HCGGUpdateManager: NSObject, URLSessionDelegate, URLSessionDataDelegate {
    let pedoMeter = CMPedometer()

    lazy var pedometerDataHandler: (CMPedometerData?, Error?) -> Void = {
        { (data: CMPedometerData?, error) -> Void in
            DispatchQueue.main.async {
                guard let pedData = data else {
                    print("CMPedometerData is nil")
                    return
                }

                self.updatePedometer(data: pedData)
            }
        }
    }()

    override public init() {}

    public func updateLocation(_ lastLoc: CLLocation) {
        var cleanedData: [String: Any] = [
            "altitude": lastLoc.altitude,
            "latitude": lastLoc.coordinate.latitude,
            "longitude": lastLoc.coordinate.longitude,
            "speed": lastLoc.speed
        ]

        let intTimestamp = Int(lastLoc.timestamp.timeIntervalSince1970)
        cleanedData["timestamp"] = String(intTimestamp)

        if let locationFloor = lastLoc.floor {
            cleanedData["floor"] = locationFloor.level
        }

        updateServer(type: "location", data: cleanedData)

        var cal = Calendar.current
        let timeZone = TimeZone.ReferenceType.system
        cal.timeZone = timeZone

        var comps = cal.dateComponents([.year, .month, .day, .hour, .minute, .second], from: Date())
        comps.hour = 0
        comps.minute = 0
        comps.second = 0

        let midnightOfToday = cal.date(from: comps)! // TODO: remove !
        print("Midnight of today: \(midnightOfToday)")

        if CMPedometer.isStepCountingAvailable() {
            self.pedoMeter.queryPedometerData(from: midnightOfToday, to: Date(), withHandler: pedometerDataHandler)
        }
    }

    public func updatePedometer(data: CMPedometerData) {
        var cleanedData: [String: Any] = [
            "numberOfSteps": data.numberOfSteps
        ]

        if let floorsAscended = data.floorsAscended { cleanedData["floorsAscended"] = floorsAscended }
        if let floorsDescended = data.floorsDescended { cleanedData["floorsDescended"] = floorsDescended }
        if let currentPace = data.currentPace { cleanedData["currentPace"] = currentPace }
        if let averageActivePace = data.averageActivePace { cleanedData["averageActivePace"] = averageActivePace }
        if let distance = data.distance { cleanedData["distance"] = distance }

        self.updateServer(type: "pedometer", data: cleanedData)
    }

    func updateServer(type: String, data: [String: Any]) {
//        var request = URLRequest(url: URL(string: "https://jotter-api.herokuapp.com/update")!)
//        var request = URLRequest(url: URL(string: "https://8a8f83a5.ngrok.io/update")!)

        var body = data
        body["type"] = type

        print("Normally would make request with body: \(body)")

        //        let json = try! JSONSerialization.data(withJSONObject: body, options: .prettyPrinted)
        //        request.httpBody = json
        //
        //        request.httpMethod = "POST"
        //        request.addValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        //
        //        URLSession.shared.dataTask(with: request, completionHandler: { data, response, error in
        //            print("Update for \(type) got status code: \((response as? HTTPURLResponse)?.statusCode))")
        //        }).resume()
    }
}
