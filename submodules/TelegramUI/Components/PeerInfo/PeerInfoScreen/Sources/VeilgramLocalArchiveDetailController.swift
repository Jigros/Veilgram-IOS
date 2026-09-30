import Foundation
import UIKit
import AsyncDisplayKit
import Display
import AccountContext
import TelegramPresentationData
import VeilgramLocalFeatures

final class VeilgramLocalArchiveDetailController: ViewController, UITableViewDataSource {
    enum Mode {
        case messages
        case edits
        case media
    }

    private struct EditRow {
        let key: VeilgramMessageKey
        let revision: VeilgramEditRevision
    }

    private let accountContext: AccountContext
    private let mode: Mode
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)

    private var messages: [VeilgramArchivedMessage] = []
    private var edits: [EditRow] = []
    private var media: [VeilgramMediaItem] = []
    private var loadError: String?

    init(context: AccountContext, mode: Mode) {
        self.accountContext = context
        self.mode = mode

        let presentation = context.sharedContext.currentPresentationData.with { $0 }
        super.init(
            navigationBarPresentationData: NavigationBarPresentationData(
                presentationData: presentation,
                style: .glass
            )
        )
        switch mode {
        case .messages:
            self.title = "Message archive"
        case .edits:
            self.title = "Edit history"
        case .media:
            self.title = "Media archive"
        }
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
        self.tableView.backgroundColor = .systemGroupedBackground
        self.tableView.rowHeight = UITableView.automaticDimension
        self.displayNode.view.addSubview(self.tableView)

        self.reload()
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
        return self.loadError == nil ? 1 : 2
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 1 {
            return 1
        }
        switch self.mode {
        case .messages:
            return max(1, self.messages.count)
        case .edits:
            return max(1, self.edits.count)
        case .media:
            return max(1, self.media.count)
        }
    }

    func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        guard section == 0 else {
            return nil
        }
        switch self.mode {
        case .messages:
            return "Local snapshots only. An archived row does not mean the message still exists on Telegram."
        case .edits:
            return "Previous locally observed text revisions only. Revisions are never written back to Telegram."
        case .media:
            return "Metadata for Veilgram-owned local archive copies only. Missing bytes are never represented as playable media."
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
        cell.selectionStyle = .none
        cell.textLabel?.numberOfLines = 2
        cell.detailTextLabel?.numberOfLines = 2

        if indexPath.section == 1 {
            cell.textLabel?.text = "Load error"
            cell.detailTextLabel?.text = self.loadError
            cell.detailTextLabel?.textColor = .systemRed
            return cell
        }

        switch self.mode {
        case .messages:
            guard !self.messages.isEmpty else {
                return Self.emptyCell(cell, text: "No archived messages")
            }
            let item = self.messages[indexPath.row]
            cell.textLabel?.text = Self.preview(item.text)
            cell.detailTextLabel?.text = "peer \(item.key.peerId) • msg \(item.key.id) • archived \(Self.dateString(item.archivedAt))"
        case .edits:
            guard !self.edits.isEmpty else {
                return Self.emptyCell(cell, text: "No saved revisions")
            }
            let item = self.edits[indexPath.row]
            cell.textLabel?.text = Self.preview(item.revision.text)
            cell.detailTextLabel?.text = "peer \(item.key.peerId) • msg \(item.key.id) • observed \(Self.dateString(item.revision.timestamp))"
        case .media:
            guard !self.media.isEmpty else {
                return Self.emptyCell(cell, text: "No archived media metadata")
            }
            let item = self.media[indexPath.row]
            let availability = item.availability == .available ? "available" : "unavailable"
            cell.textLabel?.text = item.relativePath ?? "Media unavailable"
            cell.detailTextLabel?.text = "peer \(item.key.peerId) • msg \(item.key.messageId) • \(availability) • \(Self.byteString(item.byteCount))"
        }
        return cell
    }

    private func reload() {
        do {
            let store = try VeilgramArchiveStoreAPI(
                accountId: self.accountContext.account.peerId.toInt64()
            )
            switch self.mode {
            case .messages:
                self.messages = try store.loadMessages().messages.sorted {
                    if $0.archivedAt != $1.archivedAt {
                        return $0.archivedAt > $1.archivedAt
                    }
                    return $0.key.id > $1.key.id
                }
            case .edits:
                self.edits = try store.loadEdits().records.flatMap { record in
                    record.revisions.map { EditRow(key: record.message, revision: $0) }
                }.sorted {
                    if $0.revision.timestamp != $1.revision.timestamp {
                        return $0.revision.timestamp > $1.revision.timestamp
                    }
                    return $0.key.id > $1.key.id
                }
            case .media:
                self.media = try store.loadMedia().items.sorted {
                    if $0.lastAccessedAt != $1.lastAccessedAt {
                        return $0.lastAccessedAt > $1.lastAccessedAt
                    }
                    return $0.archivedAt > $1.archivedAt
                }
            }
            self.loadError = nil
        } catch {
            self.messages = []
            self.edits = []
            self.media = []
            self.loadError = String(describing: error)
        }
        if self.isViewLoaded {
            self.tableView.reloadData()
        }
    }

    private static func emptyCell(_ cell: UITableViewCell, text: String) -> UITableViewCell {
        cell.textLabel?.text = text
        cell.textLabel?.textColor = .secondaryLabel
        cell.detailTextLabel?.text = nil
        return cell
    }

    private static func preview(_ text: String) -> String {
        let singleLine = text.replacingOccurrences(of: "\n", with: " ")
        if singleLine.isEmpty {
            return "(empty text)"
        }
        return String(singleLine.prefix(220))
    }

    private static func dateString(_ timestamp: Int32) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(
            from: Date(timeIntervalSince1970: TimeInterval(timestamp))
        )
    }

    private static func byteString(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        formatter.isAdaptive = true
        return formatter.string(fromByteCount: max(0, bytes))
    }
}
