import Foundation
import UIKit
import AsyncDisplayKit
import Display
import AccountContext
import TelegramPresentationData
import VeilgramLocalFeatures

final class VeilgramLocalArchiveDetailController: ViewController, UITableViewDataSource, UITableViewDelegate, UIDocumentInteractionControllerDelegate, UISearchResultsUpdating {
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
    private let searchController = UISearchController(searchResultsController: nil)
    private var searchQuery = ""

    private var messages: [VeilgramArchivedMessage] = []
    private var edits: [EditRow] = []
    private var media: [VeilgramMediaItem] = []
    private var loadError: String?
    private var documentInteractionController: UIDocumentInteractionController?

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
        self.tableView.delegate = self
        self.tableView.backgroundColor = .systemGroupedBackground
        self.tableView.rowHeight = UITableView.automaticDimension
        self.displayNode.view.addSubview(self.tableView)

        self.searchController.searchResultsUpdater = self
        self.searchController.obscuresBackgroundDuringPresentation = false
        self.searchController.searchBar.autocapitalizationType = .none
        self.searchController.searchBar.autocorrectionType = .no
        self.searchController.searchBar.placeholder = "Search text, peer:123, msg:456"
        self.navigationItem.searchController = self.searchController
        self.navigationItem.hidesSearchBarWhenScrolling = false

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
            return max(1, self.visibleMessages.count)
        case .edits:
            return max(1, self.visibleEdits.count)
        case .media:
            return max(1, self.visibleMedia.count)
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
            let visibleMessages = self.visibleMessages
            guard !visibleMessages.isEmpty else {
                return Self.emptyCell(cell, text: self.searchQuery.isEmpty ? "No archived messages" : "No matching messages")
            }
            let item = visibleMessages[indexPath.row]
            cell.textLabel?.text = Self.preview(item.text)
            cell.detailTextLabel?.text = "peer \(item.key.peerId) • msg \(item.key.id) • archived \(Self.dateString(item.archivedAt))"
        case .edits:
            let visibleEdits = self.visibleEdits
            guard !visibleEdits.isEmpty else {
                return Self.emptyCell(cell, text: self.searchQuery.isEmpty ? "No saved revisions" : "No matching revisions")
            }
            let item = visibleEdits[indexPath.row]
            let revisionCount = self.edits.reduce(into: 0) { count, candidate in
                if candidate.key == item.key {
                    count += 1
                }
            }
            cell.textLabel?.text = Self.preview(item.revision.text)
            cell.detailTextLabel?.text = "peer \(item.key.peerId) • msg \(item.key.id) • \(revisionCount) revision\(revisionCount == 1 ? "" : "s") • \(Self.dateString(item.revision.timestamp))"
            cell.selectionStyle = .default
            cell.accessoryType = .disclosureIndicator
        case .media:
            let visibleMedia = self.visibleMedia
            guard !visibleMedia.isEmpty else {
                return Self.emptyCell(cell, text: self.searchQuery.isEmpty ? "No archived media metadata" : "No matching media")
            }
            let item = visibleMedia[indexPath.row]
            let availability = item.availability == .available ? "available" : "unavailable"
            cell.textLabel?.text = item.relativePath ?? "Media unavailable"
            cell.detailTextLabel?.text = "peer \(item.key.peerId) • msg \(item.key.messageId) • \(availability) • \(Self.byteString(item.byteCount))"
            if item.availability == .available {
                cell.selectionStyle = .default
                cell.accessoryType = .disclosureIndicator
            }
        }
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard indexPath.section == 0 else {
            return
        }

        if self.mode == .edits {
            let visibleEdits = self.visibleEdits
            guard indexPath.row < visibleEdits.count else {
                return
            }
            let item = visibleEdits[indexPath.row]
            self.searchController.isActive = true
            self.searchController.searchBar.text = "peer:\(item.key.peerId) msg:\(item.key.id)"
            self.searchQuery = self.searchController.searchBar.text ?? ""
            self.tableView.reloadData()
            return
        }

        guard self.mode == .media else {
            return
        }
        let visibleMedia = self.visibleMedia
        guard indexPath.row < visibleMedia.count else {
            return
        }

        let item = visibleMedia[indexPath.row]
        guard item.availability == .available else {
            return
        }

        do {
            let store = try VeilgramArchiveStoreAPI(
                accountId: self.accountContext.account.peerId.toInt64()
            )
            guard let url = try store.archivedMediaURL(for: item) else {
                self.loadError = "Archived media bytes are missing or no longer match their metadata."
                self.tableView.reloadData()
                return
            }

            let controller = UIDocumentInteractionController(url: url)
            controller.delegate = self
            self.documentInteractionController = controller
            if !controller.presentPreview(animated: true) {
                self.documentInteractionController = nil
                let activity = UIActivityViewController(
                    activityItems: [url],
                    applicationActivities: nil
                )
                self.present(activity, animated: true)
            }
        } catch {
            self.loadError = String(describing: error)
            self.tableView.reloadData()
        }
    }

    func documentInteractionControllerViewControllerForPreview(
        _ controller: UIDocumentInteractionController
    ) -> UIViewController {
        return self
    }

    func documentInteractionControllerDidEndPreview(
        _ controller: UIDocumentInteractionController
    ) {
        if self.documentInteractionController === controller {
            self.documentInteractionController = nil
        }
    }

    func updateSearchResults(for searchController: UISearchController) {
        self.searchQuery = searchController.searchBar.text ?? ""
        self.tableView.reloadData()
    }

    private var visibleMessages: [VeilgramArchivedMessage] {
        return self.messages.filter {
            Self.matchesSearch(
                query: self.searchQuery,
                text: $0.text,
                peerId: $0.key.peerId,
                messageId: $0.key.id
            )
        }
    }

    private var visibleEdits: [EditRow] {
        return self.edits.filter {
            Self.matchesSearch(
                query: self.searchQuery,
                text: $0.revision.text,
                peerId: $0.key.peerId,
                messageId: $0.key.id
            )
        }
    }

    private var visibleMedia: [VeilgramMediaItem] {
        return self.media.filter {
            Self.matchesSearch(
                query: self.searchQuery,
                text: $0.relativePath ?? "",
                peerId: $0.key.peerId,
                messageId: $0.key.messageId
            )
        }
    }

    private static func matchesSearch(
        query: String,
        text: String,
        peerId: Int64,
        messageId: Int32
    ) -> Bool {
        let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else {
            return true
        }

        let searchableText = text.lowercased()
        for rawToken in normalized.split(whereSeparator: { $0.isWhitespace }) {
            let token = String(rawToken)
            let lower = token.lowercased()
            if lower.hasPrefix("peer:") {
                guard let value = Int64(lower.dropFirst(5)), value == peerId else {
                    return false
                }
            } else if lower.hasPrefix("msg:") {
                guard let value = Int32(lower.dropFirst(4)), value == messageId else {
                    return false
                }
            } else if !searchableText.contains(lower) {
                return false
            }
        }
        return true
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
