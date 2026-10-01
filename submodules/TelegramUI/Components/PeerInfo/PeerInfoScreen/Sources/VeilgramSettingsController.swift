import Foundation
import UIKit
import AsyncDisplayKit
import Display
import AccountContext
import TelegramPresentationData
import VeilgramLocalFeatures

/// Veilgram-owned settings surface. Runtime options are per-account and are
/// consumed by TelegramCore / chat rendering without changing server data.
final class VeilgramSettingsController: ViewController, UITableViewDataSource, UITableViewDelegate {
    private let accountContext: AccountContext
    private let roadmapPreferenceKey: String
    private let adFilterPreferenceKey: String
    private let adCollapsePreferenceKey: String
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private var showRoadmap: Bool
    private var adFilterEnabled: Bool
    private var adCollapseEnabled: Bool
    private var ghostModeEnabled: Bool
    private var ghostReadReceiptsEnabled: Bool
    private var ghostTypingEnabled: Bool
    private var ghostOnlinePresenceEnabled: Bool
    private var localPremiumUIEnabled: Bool

    init(context: AccountContext) {
        self.accountContext = context
        let accountPrefix = "veilgram.settings.v1.\(context.account.id.int64)"
        self.roadmapPreferenceKey = "\(accountPrefix).showRoadmap"
        self.adFilterPreferenceKey = "\(accountPrefix).channelAdFilterEnabled"
        self.adCollapsePreferenceKey = "\(accountPrefix).channelAdCollapseEnabled"
        self.showRoadmap = UserDefaults.standard.bool(forKey: self.roadmapPreferenceKey)
        self.adFilterEnabled = UserDefaults.standard.bool(forKey: self.adFilterPreferenceKey)
        self.adCollapseEnabled = UserDefaults.standard.bool(forKey: self.adCollapsePreferenceKey)
        let accountPeerId = context.account.peerId.toInt64()
        VeilgramGhostModeRuntimePreferences.initializeDefaultsIfNeeded(accountPeerId: accountPeerId)
        self.ghostModeEnabled = VeilgramGhostModeRuntimePreferences.isEnabled(accountPeerId: accountPeerId)
        self.ghostReadReceiptsEnabled = VeilgramGhostModeRuntimePreferences.suppressReadReceipts(accountPeerId: accountPeerId)
        self.ghostTypingEnabled = VeilgramGhostModeRuntimePreferences.suppressTyping(accountPeerId: accountPeerId)
        self.ghostOnlinePresenceEnabled = VeilgramGhostModeRuntimePreferences.suppressOnlinePresence(accountPeerId: accountPeerId)
        self.localPremiumUIEnabled = VeilgramLocalPremiumRuntimePreferences.isEnabled(accountPeerId: accountPeerId)
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
            return 10
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
            return "Ghost mode is per-account. It suppresses cloud read receipts, typing/activity signals and online presence when enabled. Secret-chat read semantics are not modified. Ad detection is local and collapsed posts can always be revealed."
        case 1:
            return "These screens inspect only Veilgram-owned local archive files for this account. Archive capture remains explicitly opt-in."
        case 2:
            return "Versioned local JSON transfer validates checksum and typed document structure before replacing Veilgram-owned data."
        default:
            return "Additional Veilgram tools appear here as their runtime integrations are added."
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
                cell.textLabel?.text = "Ghost mode"
                cell.detailTextLabel?.text = "Invisible mode for this account"
                let control = UISwitch()
                control.isOn = self.ghostModeEnabled
                control.addTarget(self, action: #selector(ghostModeChanged(_:)), for: .valueChanged)
                cell.accessoryView = control
            } else if indexPath.row == 3 {
                cell.textLabel?.text = "Hide read receipts"
                cell.detailTextLabel?.text = "Do not acknowledge ordinary cloud-chat reads"
                cell.textLabel?.textColor = self.ghostModeEnabled ? .label : .secondaryLabel
                let control = UISwitch()
                control.isEnabled = self.ghostModeEnabled
                control.isOn = self.ghostReadReceiptsEnabled
                control.addTarget(self, action: #selector(ghostReadReceiptsChanged(_:)), for: .valueChanged)
                cell.accessoryView = control
            } else if indexPath.row == 4 {
                cell.textLabel?.text = "Hide typing activity"
                cell.detailTextLabel?.text = "Suppress typing, recording and upload activity"
                cell.textLabel?.textColor = self.ghostModeEnabled ? .label : .secondaryLabel
                let control = UISwitch()
                control.isEnabled = self.ghostModeEnabled
                control.isOn = self.ghostTypingEnabled
                control.addTarget(self, action: #selector(ghostTypingChanged(_:)), for: .valueChanged)
                cell.accessoryView = control
            } else if indexPath.row == 5 {
                cell.textLabel?.text = "Stay offline"
                cell.detailTextLabel?.text = "Do not advertise online presence"
                cell.textLabel?.textColor = self.ghostModeEnabled ? .label : .secondaryLabel
                let control = UISwitch()
                control.isEnabled = self.ghostModeEnabled
                control.isOn = self.ghostOnlinePresenceEnabled
                control.addTarget(self, action: #selector(ghostOnlinePresenceChanged(_:)), for: .valueChanged)
                cell.accessoryView = control
            } else if indexPath.row == 6 {
                cell.textLabel?.text = "Detect channel ads locally"
                cell.detailTextLabel?.text = "Experimental heuristic • ordinary channel posts"
                let control = UISwitch()
                control.isOn = self.adFilterEnabled
                control.addTarget(self, action: #selector(adFilterChanged(_:)), for: .valueChanged)
                cell.accessoryView = control
            } else if indexPath.row == 7 {
                cell.textLabel?.text = "Collapse high-confidence ads"
                cell.detailTextLabel?.text = self.adFilterEnabled
                    ? "Collapse matched channel ads with tap-to-reveal"
                    : "Enable local detection first"
                cell.textLabel?.textColor = self.adFilterEnabled ? .label : .secondaryLabel
                let control = UISwitch()
                control.isEnabled = self.adFilterEnabled
                control.isOn = self.adCollapseEnabled
                control.addTarget(self, action: #selector(adCollapseChanged(_:)), for: .valueChanged)
                cell.accessoryView = control
            } else if indexPath.row == 8 {
                cell.textLabel?.text = "Local Premium UI"
                cell.detailTextLabel?.text = "Enable Veilgram-owned premium-style presentation"
                let control = UISwitch()
                control.isOn = self.localPremiumUIEnabled
                control.addTarget(self, action: #selector(localPremiumChanged(_:)), for: .valueChanged)
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
        if indexPath.section == 0, indexPath.row == 9 {
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

    @objc private func ghostModeChanged(_ sender: UISwitch) {
        let accountPeerId = self.accountContext.account.peerId.toInt64()
        self.ghostModeEnabled = sender.isOn
        VeilgramGhostModeRuntimePreferences.setEnabled(sender.isOn, accountPeerId: accountPeerId)
        self.ghostReadReceiptsEnabled = VeilgramGhostModeRuntimePreferences.suppressReadReceipts(accountPeerId: accountPeerId)
        self.ghostTypingEnabled = VeilgramGhostModeRuntimePreferences.suppressTyping(accountPeerId: accountPeerId)
        self.ghostOnlinePresenceEnabled = VeilgramGhostModeRuntimePreferences.suppressOnlinePresence(accountPeerId: accountPeerId)
        self.tableView.reloadRows(
            at: [IndexPath(row: 3, section: 0), IndexPath(row: 4, section: 0), IndexPath(row: 5, section: 0)],
            with: .none
        )
    }

    @objc private func ghostReadReceiptsChanged(_ sender: UISwitch) {
        let accountPeerId = self.accountContext.account.peerId.toInt64()
        VeilgramGhostModeRuntimePreferences.setSuppressReadReceipts(sender.isOn, accountPeerId: accountPeerId)
        self.ghostReadReceiptsEnabled = sender.isOn
    }

    @objc private func ghostTypingChanged(_ sender: UISwitch) {
        let accountPeerId = self.accountContext.account.peerId.toInt64()
        VeilgramGhostModeRuntimePreferences.setSuppressTyping(sender.isOn, accountPeerId: accountPeerId)
        self.ghostTypingEnabled = sender.isOn
    }

    @objc private func ghostOnlinePresenceChanged(_ sender: UISwitch) {
        let accountPeerId = self.accountContext.account.peerId.toInt64()
        VeilgramGhostModeRuntimePreferences.setSuppressOnlinePresence(sender.isOn, accountPeerId: accountPeerId)
        self.ghostOnlinePresenceEnabled = sender.isOn
    }

    @objc private func localPremiumChanged(_ sender: UISwitch) {
        let accountPeerId = self.accountContext.account.peerId.toInt64()
        self.localPremiumUIEnabled = sender.isOn
        VeilgramLocalPremiumRuntimePreferences.setEnabled(
            sender.isOn,
            accountPeerId: accountPeerId
        )
    }

    @objc private func adFilterChanged(_ sender: UISwitch) {
        self.adFilterEnabled = sender.isOn
        UserDefaults.standard.set(sender.isOn, forKey: self.adFilterPreferenceKey)
        if !sender.isOn {
            self.adCollapseEnabled = false
            UserDefaults.standard.set(false, forKey: self.adCollapsePreferenceKey)
        }
        self.tableView.reloadRows(at: [IndexPath(row: 7, section: 0)], with: .none)
    }

    @objc private func adCollapseChanged(_ sender: UISwitch) {
        self.adCollapseEnabled = sender.isOn
        UserDefaults.standard.set(sender.isOn, forKey: self.adCollapsePreferenceKey)
    }
}