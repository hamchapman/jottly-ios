import UIKit

public class HCLogsViewController: UIViewController {

    public var logsTableView: UITableView = UITableView()

    override public func viewDidLoad() {
        super.viewDidLoad()
        logsTableView = UITableView(frame: UIScreen.main.bounds, style: .plain)
        logsTableView.delegate = self
        logsTableView.dataSource = self
        logsTableView.register(UITableViewCell.self, forCellReuseIdentifier: "HCLogCell")

        self.navigationItem.setRightBarButton(
            UIBarButtonItem(
                barButtonSystemItem: .done,
                target: self,
                action: #selector(dismissViewController(_:))
            ),
            animated: true
        )

        self.view.addSubview(self.logsTableView)
    }

    @objc public func dismissViewController(_ sender: UIBarButtonItem) {
        self.dismiss(animated: true)
    }
}

extension HCLogsViewController: UITableViewDelegate, UITableViewDataSource {
    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return hcLogger.logs.count
    }

    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .default, reuseIdentifier: "HCLogCell")
        let log = hcLogger.logs.reversed()[indexPath.row]

        cell.textLabel?.text = "\(log.timestamp) - \(log.text)"
        cell.textLabel?.numberOfLines = 0
        cell.textLabel?.sizeToFit()
        cell.textLabel?.lineBreakMode = .byWordWrapping

        return cell
    }
}

