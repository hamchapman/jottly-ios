import Foundation
import UIKit

//    public init(date: Date, text: String) {
//        self.text = text
//        self.date = date
//    }
//
//    public init(text: String) {
//        self.init(date: Date(), text: text)
//    }

//    private static func currentTime() -> String {
//        let date = Date()
//        let calender = Calendar.current
//        let components = calender.dateComponents([.hour, .minute, .second], from: date)
//        let componentsArray = [
//            components.hour!,
//            components.minute!,
//            components.second!
//        ].map { String(format: "%02d", $0) }
//        return componentsArray.joined(separator: ":")
//    }



public typealias HCLogger = GenericHCLogger<BasicHCLog>

public struct BasicHCLog: HCLog {
    public let date: Date
    public let text: String

    public init(date: Date, text: String) {
        self.text = text
        self.date = date
    }

    public init(text: String) {
        self.init(date: Date(), text: text)
    }
}

public protocol HCLog: Codable {

    init(text: String)

    // TODO: short, medium, long, or unix timestamp version
    var date: Date { get }
    var text: String { get }
}



public protocol HCLogStore {
    associatedtype LogType

    func fetchLogs(cursor: String?, limit: Int?) -> [LogType]
    func appendLog(_ log: LogType)
}

//public protocol HCLogStore {
//    func fetchLogs(cursor: String?, limit: Int?) -> [HCLog]
//    func appendLog(_ log: HCLog)
//}

extension HCLogStore {
    public func fetchLogs(cursor: String? = nil, limit: Int? = nil) -> [LogType] {
        return fetchLogs(cursor: cursor, limit: limit)
    }
}

//public typealias DefaultUserDefaultsLogStore = AnyHCLogStore<BasicHCLog>

public class HCUserDefaultsLogStore<LogType: HCLog>: AnyHCLogStore<LogType> {

    // TODO: This should keep its own cache of logs so that it doesn't
    // have to always fetch to append

    public let defaults = UserDefaults.standard
    public let identifier: String

    public init(identifier: String) {
        self.identifier = identifier
        super.init(self)
    }

    override public func appendLog(_ log: LogType) {
        var currentLogs = self.fetchLogs()
        currentLogs.append(log)

        print("About to try and encode log: \(try? PropertyListEncoder().encode(log))")

        let encodedLogs = currentLogs.flatMap { try? PropertyListEncoder().encode($0) }

        defaults.set(encodedLogs, forKey: self.identifier)
        defaults.synchronize()
    }

    override public func fetchLogs(cursor: String? = nil, limit: Int? = nil) -> [LogType] {
        let dataLogs = self.defaults.value(forKey: self.identifier) as? [Data]
        return dataLogs?.flatMap { try? PropertyListDecoder().decode(LogType.self, from: $0) } ?? [LogType]()
    }
}

//public class HCFileLogStore: HCLogStore {
//
//    // TODO: This should keep its own cache of logs so that it doesn't
//    // have to always fetch to append
//
//    public let filePath: URL
//
//    public init(filePath: URL) {
//        self.filePath = filePath
//    }
//
//    public func appendLog(_ log: HCLog) {
//        writeToFile(path: filePath, log: log)
//    }
//
//    public func fetchLogs(cursor: String? = nil, limit: Int? = nil) -> [HCLog] {
//        let logString = readFromFile(path: filePath)
//
//        // TODO: See if Codable can be used to encode / decode "special" format
//
//        let logLines = logString.split(separator: "\n")
//        return logLines.flatMap { logLine in
//            return parseLog(from: String(logLine))
//        }
//    }
//
//    private func parseLog(from logLine: String) -> LogType? {
//        let logSeparatedByDateKey = logLine.components(separatedBy: "date=")
//        let dateLogSeparatedByTextKey = logSeparatedByDateKey[1].components(separatedBy: " text=")
//        // TODO: Get the date somehow? Codable etc? Or just DateFormatter()?
//        // DateFormatter().date(from: dateLogSeparatedByTextKey.first!)
//        return HCLog(date: Date(), text: dateLogSeparatedByTextKey.last!)
//    }
//
//    private func writeToFile(path: URL, log: HCLog) {
////        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
////        let path = dir.appendingPathComponent(name)
//
//        let textToWrite = "date=\(log.date.debugDescription) text=\(log.text)\n"
//        print("************ textToWrtier: \(textToWrite)")
//
//        if let fileHandle = try? FileHandle(forWritingTo: path) {
//            fileHandle.seekToEndOfFile()
//            fileHandle.write(textToWrite.data(using: .utf8)!)
//            print("Appended to file at path \(path)")
//        } else {
//            do {
//                try textToWrite.write(to: path, atomically: true, encoding: .utf8)
//                print("Wrote to file at path \(path)")
//            } catch let error {
//                print("Error writing file at \(path). Error: \(error)")
//            }
//        }
//    }
//
//    private func readFromFile(path: URL) -> String {
//        do {
//            return try String(contentsOf: path, encoding: .utf8)
//        } catch let err {
//            print("Error reading logs from path \(path): \(err)")
//            return ""
//        }
//    }
//}


public class GenericHCLogger<LogType: HCLog> {

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

    public let store: AnyHCLogStore<LogType>

    public init(store: AnyHCLogStore<LogType>, gestureRecognizer: UIGestureRecognizer? = nil, identifier: String = "hclogs") {
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
        let log = LogType(text: text)
        debugPrint("DEBUG PRINT HC LOG: \(log)")
        self.store.appendLog(log)
        // TODO: Use a success / failure callback here?
        self.logs.append(log)
        hcLogsViewController.logsTableView.reloadData()
    }

    // TODO: Probably need something like this
    public func addToLogs(log: LogType) {
//        debugPrint("DEBUG PRINT HC LOG: \(log.debugDescription)")
        self.store.appendLog(log)
        // TODO: Use a success / failure callback here?
        self.logs.append(log)
        hcLogsViewController.logsTableView.reloadData()
    }

    public func fetchLogs() -> [LogType] {
        return self.store.fetchLogs()
    }
}



//public protocol HCLogStore {
//    associatedtype LogType
//
//    func fetchLogs(cursor: String?, limit: Int?) -> [LogType]
//    func appendLog(_ log: LogType)
//}

private class _AnyHCLogStoreBase<LogType>: HCLogStore {

    init() {
        guard type(of: self) != _AnyHCLogStoreBase.self else {
            fatalError("Cannot initialise, must subclass")
        }
    }

    func fetchLogs(cursor: String?, limit: Int?) -> [LogType] {
        fatalError("Must override")
    }

    func appendLog(_ log: LogType) {
        fatalError("Must override")
    }
}

private final class _AnyHCLogStoreBox<ConcreteHCLogStore: HCLogStore>: _AnyHCLogStoreBase<ConcreteHCLogStore.LogType> {
    // Store the concrete type
    var concrete: ConcreteHCLogStore

    // Define init()
    init(_ concrete: ConcreteHCLogStore) {
        self.concrete = concrete
    }

    override func fetchLogs(cursor: String?, limit: Int?) -> [LogType] {
        return concrete.fetchLogs(cursor: cursor, limit: limit)
    }

    override func appendLog(_ log: LogType) {
        concrete.appendLog(log)
    }
}

public class AnyHCLogStore<LogType>: HCLogStore {

    private let box: _AnyHCLogStoreBase<LogType>

    public init<Concrete: HCLogStore>(_ concrete: Concrete) where Concrete.LogType == LogType {
        box = _AnyHCLogStoreBox(concrete)
    }

    public func fetchLogs(cursor: String?, limit: Int?) -> [LogType] {
        return box.fetchLogs(cursor: cursor, limit: limit)
    }

    public func appendLog(_ log: LogType) {
        box.appendLog(log)
    }
}















