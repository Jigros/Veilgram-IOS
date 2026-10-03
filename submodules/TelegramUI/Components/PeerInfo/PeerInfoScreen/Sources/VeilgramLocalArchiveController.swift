import Foundation
import UIKit
import AsyncDisplayKit
import Display
import AccountContext
import TelegramPresentationData
import VeilgramLocalFeatures

final class VeilgramLocalArchiveController: ViewController, UITableViewDataSource, UITableViewDelegate {
    enum Focus {
        case overview
        case messages
        case edits
        case media
    }

    private let accountContext: AccountContext
    private let focus: Focus
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)

    private var messageCount = 0
    private var editRecordCount = 0
    private var revisionCount = 0
    private var mediaItemCount = 0
    private var mediaByteCount: Int64 = 0
    private var loadError: String?
    private var messageArchiveEnabled: Bool
    private var editHistoryEnabled: Bool

    init(context: AccountContext, focus: Focus = .overview) {
        self.accountContext = context
        self.focus = focus
        let accountPeerId = context.account.peerId.toInt64()
        self.messageArchiveEnabled = VeilgramArchiveRuntimePreferences.messageArchiveEnabled(
            accountPeerId: accountPeerId
        )
        self.editHistoryEnabled = VeilgramArchiveRuntimePreferences.editHistoryEnabled(
            accountPeerId: accountPeerId
        )

        let presentation = context.sharedContext.currentPresentationData.with { $0 }
        super.init(
            navigationBarPresentationData: NavigationBarPresentationData(
                presentationData: presentation,
                style: .glass
            )
        )
        self.title = "Local archive"
        self.statusBar.statusBarStyle = presentation.theme.rootController.statusBarStyle.style
        self.navigationItem.backBarButtonItem = UIBarButtonItem(
            title: presentation.strings.Common_Back,
            style: .plain,
            target: nil,
            action: nil
        )
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
        self.displayNode.view.addSubview(self.tableView)

        self.reloadLocalData()
    }

    override func containerLayoutUpdated(
        _ layout: ContainerViewLayout,
        transition: ContainedViewLayoutTransition
    ) {
        super.containerLayoutUpdated(layout, transition: transition)
        self.tableView.frame = CGRect(origin: .zero, size: layout.size)
        self.tableView.contentInset.top = self.navigationLayout(layout: layout).navigationFrame.maxY
        self.tableView.verticalScrollIndicatorInsets.top = self.tableView.contentInset.top
    }

    func numberOfSections(in tableView: UITableView) -> Int {
        return 4
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0:
            return 2
        case 1:
            return 3
        case 2:
            return self.loadError == nil ? 1 : 2
        default:
            return 1
        }
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case 0:
            return "Capture"
        case 1:
            return "Stored locally for this account"
        case 2:
            return "Status"
        default:
            return "Danger zone"
        }
    }

    func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        switch section {
        case 0:
            return "Both options are off by default. Only accepted ordinary cloud-message mutations already observed on this device are eligible. Secret chats, view-once and self-destruct content are always excluded."
        case 1:
            return "Only Veilgram-owned local files are shown here."
        case 3:
            return "Clear removes Veilgram local archive/edit/media documents for this account only. It does not delete Telegram chats, messages, media cache or account data."
        default:
            return nil
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
        cell.selectionStyle = .none

        if indexPath.section == 0 {
            if indexPath.row == 0 {
                cell.textLabel?.text = "Archive deleted cloud messages"
                cell.detailTextLabel?.text = "Accepted MessageId delete updates"
                let control = UISwitch()
                control.isOn = self.messageArchiveEnabled
                control.addTarget(self, action: #selector(messageArchiveChanged(_:)), for: .valueChanged)
                cell.accessoryView = control
            } else {
                cell.textLabel?.text = "Keep edit history"
                cell.detailTextLabel?.text = "Previous revision before accepted edit"
                let control = UISwitch()
                control.isOn = self.editHistoryEnabled
                control.addTarget(self, action: #selector(editHistoryChanged(_:)), for: .valueChanged)
                cell.accessoryView = control
            }
        } else if indexPath.section == 1 {
            switch indexPath.row {
            case 0:
                cell.textLabel?.text = "Message archive"
                cell.detailTextLabel?.text = "\(self.messageCount)"
            case 1:
                cell.textLabel?.text = "Edit history"
                cell.detailTextLabel?.text = "\(self.editRecordCount) messages • \(self.revisionCount) revisions"
            default:
                cell.textLabel?.text = "Media archive"
                cell.detailTextLabel?.text = "\(self.mediaItemCount) • \(Self.byteString(self.mediaByteCount))"
            }
            cell.selectionStyle = .default
            cell.accessoryType = .disclosureIndicator
        } else if indexPath.section == 2 {
            if indexPath.row == 0 {
                cell.textLabel?.text = "Refresh"
                cell.textLabel?.textColor = .systemBlue
                cell.selectionStyle = .default
            } else {
                cell.textLabel?.text = "Load error"
                cell.detailTextLabel?.text = self.loadError
                cell.detailTextLabel?.textColor = .systemRed
            }
        } else {
            cell.textLabel?.text = "Clear Veilgram local archive data"
            cell.textLabel?.textColor = .systemRed
            cell.selectionStyle = .default
        }
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        if indexPath.section == 1 {
            let mode: VeilgramLocalArchiveDetailController.Mode
            switch indexPath.row {
            case 0:
                mode = .messages
            case 1:
                mode = .edits
            default:
                mode = .media
            }
            self.push(
                VeilgramLocalArchiveDetailController(
                    context: self.accountContext,
                    mode: mode
                )
            )
        } else if indexPath.section == 2, indexPath.row == 0 {
            self.reloadLocalData()
        } else if indexPath.section == 3 {
            self.confirmClear()
        }
    }

    @objc private func messageArchiveChanged(_ sender: UISwitch) {
        self.messageArchiveEnabled = sender.isOn
        VeilgramArchiveRuntimePreferences.setMessageArchiveEnabled(
            sender.isOn,
            accountPeerId: self.accountContext.account.peerId.toInt64()
        )
    }

    @objc private func editHistoryChanged(_ sender: UISwitch) {
        self.editHistoryEnabled = sender.isOn
        VeilgramArchiveRuntimePreferences.setEditHistoryEnabled(
            sender.isOn,
            accountPeerId: self.accountContext.account.peerId.toInt64()
        )
    }

    private func reloadLocalData() {
        do {
            let store = try VeilgramArchiveStoreAPI(
                accountId: self.accountContext.account.peerId.toInt64()
            )
            let messages = try store.loadMessages()
            let edits = try store.loadEdits()
            let media = try store.loadMedia()

            self.messageCount = messages.messages.count
            self.editRecordCount = edits.records.count
            self.revisionCount = edits.records.reduce(into: 0) { total, record in
                total += record.revisions.count
            }
            self.mediaItemCount = media.items.count
            self.mediaByteCount = VeilgramMediaArchiveEngine.totalAvailableBytes(media)
            self.loadError = VeilgramArchiveRuntimeDiagnostics.lastErrorDescription
        } catch {
            self.messageCount = 0
            self.editRecordCount = 0
            self.revisionCount = 0
            self.mediaItemCount = 0
            self.mediaByteCount = 0
            self.loadError = String(describing: error)
        }
        if self.isViewLoaded {
            self.tableView.reloadData()
            self.scrollToFocusIfNeeded()
        }
    }

    private func scrollToFocusIfNeeded() {
        let row: Int?
        switch self.focus {
        case .overview:
            row = nil
        case .messages:
            row = 0
        case .edits:
            row = 1
        case .media:
            row = 2
        }
        guard let row else {
            return
        }
        let path = IndexPath(row: row, section: 1)
        self.tableView.scrollToRow(at: path, at: .middle, animated: false)
    }

    private func confirmClear() {
        let alert = UIAlertController(
            title: "Clear local Veilgram data?",
            message: "This removes only Veilgram's message archive, edit history and media-archive metadata for this Telegram account.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Clear", style: .destructive, handler: { [weak self] _ in
            self?.clearLocalData()
        }))
        self.present(alert, animated: true)
    }

    private func clearLocalData() {
        VeilgramArchiveRuntimeWriter.removeAll(
            accountPeerId: self.accountContext.account.peerId.toInt64()
        ) { [weak self] result in
            guard let self else {
                return
            }
            switch result {
            case .success:
                VeilgramArchiveRuntimeDiagnostics.clear()
                self.reloadLocalData()
            case let .failure(error):
                self.loadError = String(describing: error)
                self.tableView.reloadData()
            }
        }
    }

    private static func byteString(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.includesUnit = true
        formatter.isAdaptive = true
        return formatter.string(fromByteCount: max(0, bytes))
    }
}