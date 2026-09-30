import Foundation
import UIKit
import AsyncDisplayKit
import Display
import AccountContext
import TelegramPresentationData

/// Veilgram-owned settings surface. Experimental options affect only this
/// screen; no Telegram network/storage behavior is modified by these values.
final class VeilgramSettingsController: ViewController, UITableViewDataSource, UITableViewDelegate {
    private let accountContext: AccountContext
    private let preferenceKey: String
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private var showRoadmap: Bool

    init(context: AccountContext) {
        self.accountContext = context
        self.preferenceKey = "veilgram.settings.v1.\(context.account.id.int64).showRoadmap"
        self.showRoadmap = UserDefaults.standard.bool(forKey: self.preferenceKey)
        let presentation = context.sharedContext.currentPresentationData.with { $0 }
        super.init(navigationBarPresentationData: NavigationBarPresentationData(presentationData: presentation, style: .glass))
        self.title = "Veilgram"
        self.statusBar.statusBarStyle = presentation.theme.rootController.statusBarStyle.style
        self.navigationItem.backBarButtonItem = UIBarButtonItem(title: presentation.strings.Common_Back, style: .plain, target: nil, action: nil)
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func loadDisplayNode() {
        self.displayNode = ASDisplayNode()
        self.displayNode.backgroundColor = .systemGroupedBackground
        self.displayNodeDidLoad()

        self.tableView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        self.tableView.dataSource = self
        self.tableView.delegate = self
        self.tableView.backgroundColor = .systemGroupedBackground
        self.tableView.rowHeight = UITableView.automaticDimension
        self.displayNode.view.addSubview(self.tableView)
    }

    override func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        self.tableView.frame = CGRect(origin: .zero, size: layout.size)
        self.tableView.contentInset.top = self.navigationLayout(layout: layout).navigationFrame.maxY
        self.tableView.scrollIndicatorInsets.top = self.tableView.contentInset.top
    }

    func numberOfSections(in tableView: UITableView) -> Int { return 2 }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0: return 2
        default: return showRoadmap ? 4 : 0
        }
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return section == 0 ? "Veilgram settings" : "Planned, not yet available"
    }

    func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        return section == 0
            ? "Experimental menu visibility is stored on this device separately for each account. It does not change Telegram messages, privacy status or network requests."
            : "Message archive, edit history, media archive and filters have not been implemented. No functions are silently enabled."
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
        cell.selectionStyle = .none
        if indexPath.section == 0 {
            if indexPath.row == 0 {
                cell.textLabel?.text = "Version"
                cell.detailTextLabel?.text = "Research build • Telegram-iOS 12.9.2 foundation"
            } else {
                cell.textLabel?.text = "Show development roadmap"
                let control = UISwitch()
                control.isOn = self.showRoadmap
                control.addTarget(self, action: #selector(roadmapChanged(_:)), for: .valueChanged)
                cell.accessoryView = control
            }
        } else {
            let features = ["Message archive", "Edit history", "Media archive", "Message filters"]
            cell.textLabel?.text = features[indexPath.row]
            cell.detailTextLabel?.text = "Not implemented"
            cell.textLabel?.textColor = .secondaryLabel
        }
        return cell
    }

    @objc private func roadmapChanged(_ sender: UISwitch) {
        self.showRoadmap = sender.isOn
        UserDefaults.standard.set(sender.isOn, forKey: self.preferenceKey)
        self.tableView.reloadSections(IndexSet(integer: 1), with: .automatic)
    }
}
