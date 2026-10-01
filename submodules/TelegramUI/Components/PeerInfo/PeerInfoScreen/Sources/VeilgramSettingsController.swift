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
        let accountPrefix = "veilgram.settings.v1.\(context.account.peerId.toInt64())"
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

    func numberOfSections(in tableView: UITableView) -> Int { return 4 }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0:
            return 5
        case 1:
            return 3
        case 2:
            return 1
        default:
            return showRoadmap ? 1 : 0
        }
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case 0:
            return "Veilgram settings"
        case 1:
            return "Local archive"
        case 2:
            return "Transfer"
        default:
            return "Planned"
        }
    }

    func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        switch section {
        case 0:
            return "Settings and message-filter rules are stored locally and separately for each account. Channel-ad analysis is fully on-device. Official Telegram Sponsored Messages are outside this filter. Collapse remains a preview preference until reveal UI is implemented."
        case 1:
            return "These screens inspect only Veilgram-owned local archive files for this account. Archive capture remains explicitly opt-in."
        case 2:
            return "Versioned local JSON transfer validates checksum, type and known credential/session markers before replacing Veilgram-owned data."
        default:
            return "More UI will be exposed only after the underlying feature has its own build and safety gate."
        }
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
            } else if indexPath.row == 3 {
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
            } else {
                cell.textLabel?.text = "Message filters"
                cell.detailTextLabel?.text = "Local rules • add, enable, disable or delete"
                cell.selectionStyle = .default
                cell.accessoryType = .disclosureIndicator
            }
        } else if indexPath.section == 1 {
            let features: [(String, String)] = [
                ("Message archive", "Local snapshot count and storage status"),
                ("Edit history", "Local revision count and storage status"),
                ("Media archive", "Local availability metadata and size")
            ]
            cell.textLabel?.text = features[indexPath.row].0
            cell.detailTextLabel?.text = features[indexPath.row].1
            cell.selectionStyle = .default
            cell.accessoryType = .disclosureIndicator
        } else if indexPath.section == 2 {
            cell.textLabel?.text = "Local data transfer"
            cell.detailTextLabel?.text = "Archive, edit history and media metadata"
            cell.selectionStyle = .default
            cell.accessoryType = .disclosureIndicator
        } else {
            cell.textLabel?.text = "Additional local tools"
            cell.detailTextLabel?.text = "Planned"
            cell.textLabel?.textColor = .secondaryLabel
        }
        return cell
    }


    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if indexPath.section == 0, indexPath.row == 4 {
            self.push(VeilgramMessageFiltersController(context: self.accountContext))
            return
        }
        if indexPath.section == 1 {
            let focus: VeilgramLocalArchiveController.Focus
            switch indexPath.row {
            case 0:
                focus = .messages
            case 1:
                focus = .edits
            default:
                focus = .media
            }
            self.push(VeilgramLocalArchiveController(context: self.accountContext, focus: focus))
        }
        if indexPath.section == 2 {
            self.push(VeilgramLocalTransferController(context: self.accountContext))
        }
    }

    @objc private func roadmapChanged(_ sender: UISwitch) {
        self.showRoadmap = sender.isOn
        UserDefaults.standard.set(sender.isOn, forKey: self.roadmapPreferenceKey)
        self.tableView.reloadSections(IndexSet(integer: 3), with: .automatic)
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
