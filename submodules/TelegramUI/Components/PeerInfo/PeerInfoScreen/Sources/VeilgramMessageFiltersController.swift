import Foundation
import UIKit
import AsyncDisplayKit
import Display
import AccountContext
import TelegramPresentationData
import VeilgramLocalFeatures

private final class VeilgramFilterSwitch: UISwitch {
    var ruleId: String = ""
}

final class VeilgramMessageFiltersController: ViewController, UITableViewDataSource, UITableViewDelegate {
    private let context: AccountContext
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private var store: VeilgramFilterStoreAPI?
    private var rules: [VeilgramFilterRuleSummary] = []
    private var loadError: String?

    init(context: AccountContext) {
        self.context = context
        let presentation = context.sharedContext.currentPresentationData.with { $0 }
        super.init(
            navigationBarPresentationData: NavigationBarPresentationData(
                presentationData: presentation,
                style: .glass
            )
        )
        self.title = "Message filters"
        self.statusBar.statusBarStyle = presentation.theme.rootController.statusBarStyle.style
        self.navigationItem.backBarButtonItem = UIBarButtonItem(
            title: presentation.strings.Common_Back,
            style: .plain,
            target: nil,
            action: nil
        )
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .add,
            target: self,
            action: #selector(self.addPressed)
        )

        do {
            self.store = try VeilgramFilterStoreAPI(accountId: context.account.id.int64)
            self.reloadRules()
        } catch {
            self.loadError = "Local filter storage is unavailable."
        }
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
        return 1
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return max(1, self.rules.count)
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return "Local rules"
    }

    func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        if let loadError = self.loadError {
            return loadError
        }
        return "Rules are stored only on this device for the current account. This first editor creates case-insensitive “text contains” rules. Regex, scopes and import/export are supported by the core but will be exposed in a later UI."
    }

    func tableView(
        _ tableView: UITableView,
        cellForRowAt indexPath: IndexPath
    ) -> UITableViewCell {
        guard !self.rules.isEmpty else {
            let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
            cell.selectionStyle = .none
            cell.textLabel?.text = self.loadError == nil ? "No filters yet" : "Filters unavailable"
            cell.detailTextLabel?.text = self.loadError == nil
                ? "Tap + to add a local text rule."
                : self.loadError
            cell.textLabel?.textColor = .secondaryLabel
            return cell
        }

        let rule = self.rules[indexPath.row]
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
        cell.selectionStyle = .none
        cell.textLabel?.text = rule.name
        cell.detailTextLabel?.text = "(rule.detail) • (rule.action)"
        let control = VeilgramFilterSwitch()
        control.ruleId = rule.id
        control.isOn = rule.isEnabled
        control.addTarget(self, action: #selector(self.ruleSwitchChanged(_:)), for: .valueChanged)
        cell.accessoryView = control
        return cell
    }

    func tableView(
        _ tableView: UITableView,
        canEditRowAt indexPath: IndexPath
    ) -> Bool {
        return !self.rules.isEmpty
    }

    func tableView(
        _ tableView: UITableView,
        commit editingStyle: UITableViewCell.EditingStyle,
        forRowAt indexPath: IndexPath
    ) {
        guard editingStyle == .delete, self.rules.indices.contains(indexPath.row) else {
            return
        }
        let id = self.rules[indexPath.row].id
        do {
            try self.store?.remove(ruleId: id)
            self.reloadRules()
            self.tableView.reloadData()
        } catch {
            self.showError("Could not remove this filter.")
        }
    }

    @objc private func addPressed() {
        guard self.store != nil else {
            self.showError("Local filter storage is unavailable.")
            return
        }

        let alert = UIAlertController(
            title: "New filter",
            message: "Create a local rule that labels messages containing text.",
            preferredStyle: .alert
        )
        alert.addTextField { field in
            field.placeholder = "Rule name"
            field.autocapitalizationType = .sentences
        }
        alert.addTextField { field in
            field.placeholder = "Text to match"
            field.autocapitalizationType = .none
            field.autocorrectionType = .no
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Add", style: .default, handler: { [weak self, weak alert] _ in
            guard let self else {
                return
            }
            let name = alert?.textFields?.first?.text ?? ""
            let needle = alert?.textFields?.dropFirst().first?.text ?? ""
            do {
                _ = try self.store?.addTextContainsRule(
                    name: name,
                    needle: needle,
                    collapse: false,
                    peerId: nil
                )
                self.reloadRules()
                self.tableView.reloadData()
            } catch {
                self.showError("Enter both a rule name and text to match.")
            }
        }))
        self.present(alert, animated: true)
    }

    @objc private func ruleSwitchChanged(_ sender: VeilgramFilterSwitch) {
        do {
            try self.store?.setEnabled(ruleId: sender.ruleId, enabled: sender.isOn)
            self.reloadRules()
        } catch {
            sender.setOn(!sender.isOn, animated: true)
            self.showError("Could not update this filter.")
        }
    }

    private func reloadRules() {
        do {
            self.rules = try self.store?.listRules() ?? []
            self.loadError = nil
        } catch {
            self.rules = []
            self.loadError = "Could not read local filter rules."
        }
    }

    private func showError(_ message: String) {
        let alert = UIAlertController(title: "Veilgram", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        self.present(alert, animated: true)
    }
}
