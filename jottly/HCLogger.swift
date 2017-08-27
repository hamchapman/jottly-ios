import Foundation
import UIKit

public struct HCLog: Codable {

    // TODO: Store time that can be used to make short, medium, long, or unix timestamp version
    public let timestamp: String
    public let text: String

    public init(timestamp: String, text: String) {
        self.text = text
        self.timestamp = timestamp
    }

    public init(text: String) {
        let timestamp = HCLog.currentTime()
        self.init(timestamp: timestamp, text: text)
    }

    private static func currentTime() -> String {
        let date = Date()
        let calender = Calendar.current
        let components = calender.dateComponents([.hour, .minute, .second], from: date)
        let componentsArray = [
            components.hour!,
            components.minute!,
            components.second!
        ].map { String(format: "%02d", $0) }
        return componentsArray.joined(separator: ":")
    }
}


public protocol HCLogStore {
    func fetchLogs(cursor: String?, limit: Int?) -> [HCLog]
    func appendLog(_ log: HCLog)
}

extension HCLogStore {
    public func fetchLogs(cursor: String? = nil, limit: Int? = nil) -> [HCLog] {
        return fetchLogs(cursor: cursor, limit: limit)
    }
}

public class HCUserDefaultsLogStore: HCLogStore {

    // TODO: This should keep its own cache of logs so that it doesn't
    // have to always fetch to append

    public let defaults = UserDefaults.standard
    public let identifier: String

    public init(identifier: String) {
        self.identifier = identifier
    }

    public func appendLog(_ log: HCLog) {
        var currentLogs = self.fetchLogs()
        currentLogs.append(log)

        let encodedLogs = currentLogs.flatMap { try? PropertyListEncoder().encode($0) }

        defaults.set(encodedLogs, forKey: self.identifier)
        defaults.synchronize()
    }

    public func fetchLogs(cursor: String? = nil, limit: Int? = nil) -> [HCLog] {
        let dataLogs = self.defaults.value(forKey: self.identifier) as? [Data]
        return dataLogs?.flatMap { try? PropertyListDecoder().decode(HCLog.self, from: $0) } ?? [HCLog]()
    }
}

public class HCFileLogStore: HCLogStore {

    // TODO: This should keep its own cache of logs so that it doesn't
    // have to always fetch to append

    public let filePath: URL

    public init(filePath: URL) {
        self.filePath = filePath
    }

    public func appendLog(_ log: HCLog) {
        writeToFile(path: filePath, log: log)
    }

    public func fetchLogs(cursor: String? = nil, limit: Int? = nil) -> [HCLog] {
        let logString = readFromFile(path: filePath)

        // TODO: See if Codable can be used to encode / decode "special" format

        let logLines = logString.split(separator: "\n")
        return logLines.flatMap { logLine in
            return parseLog(from: String(logLine))
        }
    }

    private func parseLog(from logLine: String) -> HCLog? {
        let logSeparatedByDateKey = logLine.components(separatedBy: "date=")
        let dateLogSeparatedByTextKey = logSeparatedByDateKey[1].components(separatedBy: " text=")
        return HCLog(timestamp: dateLogSeparatedByTextKey.first!, text: dateLogSeparatedByTextKey.last!)
    }

    private func writeToFile(path: URL, log: HCLog) {
//        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
//        let path = dir.appendingPathComponent(name)

        let textToWrite = "date=\(log.timestamp) text=\(log.text)\n"

        if let fileHandle = try? FileHandle(forWritingTo: path) {
            fileHandle.seekToEndOfFile()
            fileHandle.write(textToWrite.data(using: .utf8)!)
            print("Appended to file at path \(path)")
        } else {
            do {
                try textToWrite.write(to: path, atomically: true, encoding: .utf8)
                print("Wrote to file at path \(path)")
            } catch let error {
                print("Error writing file at \(path). Error: \(error)")
            }
        }
    }

    private func readFromFile(path: URL) -> String {
        do {
            return try String(contentsOf: path, encoding: .utf8)
        } catch let err {
            print("Error reading logs from path \(path): \(err)")
            return ""
        }
    }
}


public class HCLogger {

    // TOOD: Add support for not requiring gesture recognizers and allow presentation via
    // a button click or similar
    private lazy var gestureRecognizer: UIGestureRecognizer = {
        if let gesture = self.providedGestureRecognizer {
            return gesture
        } else {
            let gestureRecognizer = UISwipeGestureRecognizer(target: self, action: #selector(gesturePerformed))
            gestureRecognizer.numberOfTouchesRequired = 3
            gestureRecognizer.direction = .up

            return gestureRecognizer
        }
    }()

    public let providedGestureRecognizer: UIGestureRecognizer?

    public var identifier: String
    public var logs: [HCLog] = []
    public var gestureRecognizerToViewControllerMap: [UIGestureRecognizer: UIViewController] = [:]
    public let hcLogsViewController = HCLogsViewController()

    public let store: HCLogStore

    public init(store: HCLogStore, gestureRecognizer: UIGestureRecognizer? = nil, identifier: String = "hclogs") {
        self.providedGestureRecognizer = gestureRecognizer
        self.identifier = identifier
        self.store = store
        self.logs = store.fetchLogs()
    }

    public func addLogViewGesture(_ vc: UIViewController) {
        gestureRecognizerToViewControllerMap[self.gestureRecognizer] = vc
        vc.view.addGestureRecognizer(self.gestureRecognizer)
    }

    @objc public func gesturePerformed(_ recognizer: UIGestureRecognizer) {
        if recognizer.state == .recognized {
            if let vc = gestureRecognizerToViewControllerMap[recognizer] {
                presentLogsInViewController(vc)
            } else {
                print("Did not find registered gesture recognizer")
            }
        }
    }

    public func presentLogsInViewController(_ vc: UIViewController) {
        let navController = UINavigationController(rootViewController: hcLogsViewController)
        vc.present(navController, animated: true)
    }

    public func addToLogs(text: String) {
        let log = HCLog(text: text)
        debugPrint("DEBUG PRINT HC LOG: \(log)")
        self.store.appendLog(log)
        // TODO: Use a success / failure callback here?
        self.logs.append(log)
        hcLogsViewController.logsTableView.reloadData()
    }

    public func fetchLogs() -> [HCLog] {
        return self.store.fetchLogs()
    }
}
