import Foundation
import UIKit
import AsyncDisplayKit
import Display
import AccountContext
import TelegramPresentationData
import VeilgramLocalFeatures

final class VeilgramLocalTransferController: ViewController, UITableViewDataSource, UITableViewDelegate {
    private enum Kind: Int, CaseIterable {
        case messages
        case edits
        case media

        var title: String {
            switch self {
            case .messages: return "Message archive"
            case .edits: return "Edit history"
            case .media: return "Media archive metadata"
            }
        }
    }

    private let context: AccountContext
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)

    init(context: AccountContext) {
        self.context = context
        let presentation = context.sharedContext.currentPresentationData.with { $0 }
        super.init(
            navigationBarPresentationData: NavigationBarPresentationData(
                presentationData: presentation,
                style: .glass
            )
        )
        self.title = "Local data transfer"
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

    func numberOfSections(in tableView: UITableView) -> Int { 2 }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return Kind.allCases.count
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return section == 0 ? "Export to clipboard" : "Import from clipboard"
    }

    func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        if section == 0 {
            return "Exports use a versioned Veilgram JSON envelope with checksum. Veilgram transfer schemas do not contain Telegram session/auth fields; ordinary message text is not keyword-filtered."
        }
        return "Import validates version, checksum, document type and payload before replacing only the selected Veilgram local document for this account."
    }

    func tableView(
        _ tableView: UITableView,
        cellForRowAt indexPath: IndexPath
    ) -> UITableViewCell {
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
        let kind = Kind(rawValue: indexPath.row)!
        cell.textLabel?.text = kind.title
        cell.selectionStyle = .default
        if indexPath.section == 0 {
            cell.detailTextLabel?.text = "Copy versioned JSON envelope"
        } else {
            cell.detailTextLabel?.text = "Validate and replace this local document"
        }
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard let kind = Kind(rawValue: indexPath.row) else { return }
        if indexPath.section == 0 {
            self.export(kind)
        } else {
            self.confirmImport(kind)
        }
    }

    private func store() throws -> VeilgramArchiveStoreAPI {
        return try VeilgramArchiveStoreAPI(
            accountId: self.context.account.peerId.toInt64()
        )
    }

    private func export(_ kind: Kind) {
        do {
            let store = try self.store()
            let createdAt = Int32(Date().timeIntervalSince1970)
            let data: Data
            switch kind {
            case .messages:
                data = try store.exportMessages(createdAt: createdAt)
            case .edits:
                data = try store.exportEdits(createdAt: createdAt)
            case .media:
                data = try store.exportMediaMetadata(createdAt: createdAt)
            }
            guard let text = String(data: data, encoding: .utf8) else {
                self.showError("Could not encode local data export.")
                return
            }
            UIPasteboard.general.string = text
            self.showInfo(
                title: "Export copied",
                message: "\(kind.title) Veilgram JSON was copied to the clipboard."
            )
        } catch {
            self.showError("Could not export \(kind.title.lowercased()).")
        }
    }

    private func confirmImport(_ kind: Kind) {
        guard let text = UIPasteboard.general.string, !text.isEmpty else {
            self.showError("Clipboard does not contain text.")
            return
        }
        let data = Data(text.utf8)
        let alert = UIAlertController(
            title: "Replace \(kind.title.lowercased())?",
            message: "The clipboard JSON will be validated first. If valid, it replaces only this Veilgram local document for the current account.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Import", style: .destructive, handler: { [weak self] _ in
            self?.importData(data, kind: kind)
        }))
        self.present(alert, animated: true)
    }

    private func importData(_ data: Data, kind: Kind) {
        let accountPeerId = self.context.account.peerId.toInt64()
        let completion: (Result<Void, Error>) -> Void = { [weak self] result in
            guard let self else {
                return
            }
            switch result {
            case .success:
                self.showInfo(
                    title: "Import complete",
                    message: "\(kind.title) was replaced for this Veilgram account."
                )
            case .failure:
                self.showError(
                    "Import rejected: invalid, corrupted, incompatible or wrong-type Veilgram data."
                )
            }
        }

        switch kind {
        case .messages:
            VeilgramArchiveRuntimeWriter.importMessages(
                accountPeerId: accountPeerId,
                data: data,
                completion: completion
            )
        case .edits:
            VeilgramArchiveRuntimeWriter.importEdits(
                accountPeerId: accountPeerId,
                data: data,
                completion: completion
            )
        case .media:
            VeilgramArchiveRuntimeWriter.importMediaMetadata(
                accountPeerId: accountPeerId,
                data: data,
                completion: completion
            )
        }
    }

    private func showInfo(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        self.present(alert, animated: true)
    }

    private func showError(_ message: String) {
        self.showInfo(title: "Veilgram", message: message)
    }
}