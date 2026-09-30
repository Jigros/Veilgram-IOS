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
    private let roadmapPreferenceKey: String
    private let adFilterPreferenceKey: String
    private let adCollapsePreferenceKey: String
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private var showRoadmap: Bool
    private var adFilterEnabled: Bool
    private var adCollapseEnabled: Bool

    init(context: AccountContext) {
        self.accountContext = context
        let accountPrefix = "veilgram.settings.v1.\(context.account.id.int64)"
        self.roadmapPreferenceKey = "\(accountPrefix).showRoadmap"
        self.adFilterPreferenceKey = "\(accountPrefix).channelAdFilterEnabled"
        self.adCollapsePreferenceKey = "\(accountPrefix).channelAdCollapseEnabled"
        self.showRoadmap = UserDefaults.standard.bool(forKey: self.roadmapPreferenceKey)
        self.adFilterEnabled = UserDefaults.standard.bool(forKey: self.adFilterPreferenceKey)
        self.adCollapseEnabled = UserDefaults.standard.bool(forKey: self.adCollapsePreferenceKey)
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
        self.tableView.verticalScrollIndicatorInsets.top = self.tableView.contentInset.top
    }

    func numberOfSections(in tableView: UITableView) -> Int { return 2 }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0: return 4
        default: return showRoadmap ? 4 : 0
        }
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return section == 0 ? "Veilgram settings" : "Planned, not yet available"
    }

    func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        return section == 0
            ? "Settings are stored locally and separately for each account. Channel-ad analysis is fully on-device. Official Telegram Sponsored Messages are outside this filter. Collapse is a preview preference and will not hide posts until the reveal UI is implemented."
            : "Message archive, edit history, media archive and filters have not been implemented. No functions are silently enabled."
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
        cell.selectionStyle = .none
        if indexPath.section == 0 {
            if indexPath.row == 0 {
                cell.textLabel?.text = "Version"
                cell.detailTextLabel?.text = "Research build • Telegram-iOS 12.9.2 foundation"
            } else if indexPath.row == 1 {
                cell.textLabel?.text = "Show development roadmap"
                let control = UISwitch()
                control.isOn = self.showRoadmap
                control.addTarget(self, action: #selector(roadmapChanged(_:)), for: .valueChanged)
                cell.accessoryView = control
            } else if indexPath.row == 2 {
                cell.textLabel?.text = "Detect channel ads locally"
                cell.detailTextLabel?.text = "Ordinary channel posts only • on-device"
                let control = UISwitch()
                control.isOn = self.adFilterEnabled
                control.addTarget(self, action: #selector(adFilterChanged(_:)), for: .valueChanged)
                cell.accessoryView = control
            } else {
                cell.textLabel?.text = "Collapse high-confidence ads"
                cell.detailTextLabel?.text = self.adFilterEnabled
                    ? "Preview setting • reveal UI not implemented yet"
                    : "Enable local detection first"
                cell.textLabel?.textColor = self.adFilterEnabled ? .label : .secondaryLabel
                let control = UISwitch()
                control.isEnabled = self.adFilterEnabled
                control.isOn = self.adCollapseEnabled
                control.addTarget(self, action: #selector(adCollapseChanged(_:)), for: .valueChanged)
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
        UserDefaults.standard.set(sender.isOn, forKey: self.roadmapPreferenceKey)
        self.tableView.reloadSections(IndexSet(integer: 1), with: .automatic)
    }

    @objc private func adFilterChanged(_ sender: UISwitch) {
        self.adFilterEnabled = sender.isOn
        UserDefaults.standard.set(sender.isOn, forKey: self.adFilterPreferenceKey)
        if !sender.isOn {
            self.adCollapseEnabled = false
            UserDefaults.standard.set(false, forKey: self.adCollapsePreferenceKey)
        }
        self.tableView.reloadRows(at: [IndexPath(row: 3, section: 0)], with: .none)
    }

    @objc private func adCollapseChanged(_ sender: UISwitch) {
        self.adCollapseEnabled = sender.isOn
        UserDefaults.standard.set(sender.isOn, forKey: self.adCollapsePreferenceKey)
    }
}
