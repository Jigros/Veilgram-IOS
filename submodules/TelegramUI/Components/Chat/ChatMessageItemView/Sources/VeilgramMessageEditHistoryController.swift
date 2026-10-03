import Foundation
import UIKit
import AsyncDisplayKit
import Display
import AccountContext
import TelegramPresentationData
import VeilgramLocalFeatures

final class VeilgramMessageEditHistoryController: ViewController, UITableViewDataSource {
    private struct Row {
        let title: String
        let detail: String
    }

    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private let rows: [Row]

    init(
        context: AccountContext,
        key: VeilgramMessageKey,
        currentText: String
    ) {
        let revisions = VeilgramArchiveRuntimeIndex.editRevisions(
            accountId: context.account.peerId.toInt64(),
            key: key
        )

        var rows: [Row] = []
        rows.append(Row(
            title: currentText.isEmpty ? "(empty message text)" : currentText,
            detail: "Current version"
        ))
        for (index, revision) in revisions.reversed().enumerated() {
            let label = index == 0 ? "Previous version" : "Previous version \(index + 1)"
            rows.append(Row(
                title: revision.text.isEmpty ? "(empty message text)" : revision.text,
                detail: "\(label) • \(Self.dateString(revision.timestamp))"
            ))
        }
        self.rows = rows

        let presentation = context.sharedContext.currentPresentationData.with { $0 }
        super.init(
            navigationBarPresentationData: NavigationBarPresentationData(
                presentationData: presentation,
                style: .glass
            )
        )
        self.title = "Edit history"
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

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.rows.count
    }

    func tableView(
        _ tableView: UITableView,
        cellForRowAt indexPath: IndexPath
    ) -> UITableViewCell {
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
        cell.selectionStyle = .none
        cell.textLabel?.numberOfLines = 0
        cell.detailTextLabel?.numberOfLines = 1
        let row = self.rows[indexPath.row]
        cell.textLabel?.text = row.title
        cell.detailTextLabel?.text = row.detail
        return cell
    }

    private static func dateString(_ timestamp: Int32) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        return formatter.string(from: Date(timeIntervalSince1970: TimeInterval(timestamp)))
    }
}
