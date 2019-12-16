// Copyright © 2018 Stormbird PTE. LTD.

import UIKit
import Foundation
import Eureka
import StoreKit
import MessageUI

protocol SettingsViewControllerDelegate: class, CanOpenURL {
    func didAction(action: AlphaWalletSettingsAction, in viewController: SettingsViewController)
    func assetDefinitionsOverrideViewController(for: SettingsViewController) -> UIViewController?
    func consoleViewController(for: SettingsViewController) -> UIViewController?
}

class SettingsViewController: FormViewController {
    private let iconInset = UIEdgeInsets(top: 0, left: 10, bottom: 0, right: 0)
    private let cellWithSubtitleHeight = CGFloat(80)
    private let cellNoSubtitleHeight = CGFloat(60)
    private let sectionHeaderHeight = CGFloat(50)
    private let sectionPosition = CGPoint(x: 30, y: 12)
    private let lock = Lock()
    private var isPasscodeEnabled: Bool {
        return lock.isPasscodeSet
    }
    private lazy var viewModel: SettingsViewModel = {
        return SettingsViewModel(isDebug: isDebug)
    }()
    private let keystore: Keystore
    private let account: Wallet
    private let promptBackupWalletViewHolder = UIView()

    weak var delegate: SettingsViewControllerDelegate?
    var promptBackupWalletView: UIView? {
        didSet {
            oldValue?.removeFromSuperview()
            if let promptBackupWalletView = promptBackupWalletView {
                promptBackupWalletView.translatesAutoresizingMaskIntoConstraints = false
                promptBackupWalletViewHolder.addSubview(promptBackupWalletView)
                NSLayoutConstraint.activate([
                    promptBackupWalletView.leadingAnchor.constraint(equalTo: promptBackupWalletViewHolder.leadingAnchor, constant: 7),
                    promptBackupWalletView.trailingAnchor.constraint(equalTo: promptBackupWalletViewHolder.trailingAnchor, constant: -7),
                    promptBackupWalletView.topAnchor.constraint(equalTo: promptBackupWalletViewHolder.topAnchor, constant: 7),
                    promptBackupWalletView.bottomAnchor.constraint(equalTo: promptBackupWalletViewHolder.bottomAnchor, constant: 0),
                ])
                tabBarItem.badgeValue = "1"
                showPromptBackupWalletViewAsTableHeaderView()
            } else {
                hidePromptBackupWalletView()
                tabBarItem.badgeValue = nil
            }
        }
    }

    init(keystore: Keystore, account: Wallet) {
        self.keystore = keystore
        self.account = account
        super.init(style: .grouped)
        title = R.string.localizable.aSettingsNavigationTitle()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = Screen.Setting.Color.background
        
        tableView.backgroundColor = GroupedTable.Color.background
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.sectionFooterHeight = 0
        tableView.separatorStyle = .singleLine
        tableView.separatorInsetReference = .fromCellEdges
        tableView.separatorInset = UIEdgeInsets(top: 0, left: 20, bottom: 0, right: 0)
        view.addSubview(tableView)

        let section1 = Section("WALLET") { [weak self] section in
            guard let strongSelf = self else { return }
            var header = HeaderFooterView<UIView>(.class)
            header.onSetupView = { view, _ in
                view.backgroundColor = Screen.Setting.Color.sectionHeaderBackground
                let label = UILabel(frame: CGRect(x: (self?.sectionPosition.x)!, y: (self?.sectionPosition.y)!, width: 200, height: 30))
                label.text = "WALLET"
                label.font = UIFont(name: "SourceSansPro-Semibold", size: 15)
                label.textColor = Screen.Setting.Color.sectionHeaderText
                view.backgroundColor = Screen.Setting.Color.sectionHeaderBackground
                view.addSubview(label)
            }
            section.header = header
            section.header?.height = { strongSelf.sectionHeaderHeight }
        }
        
        //Show My Wallet Address
        <<< AlphaWalletSettingsButtonRow { button in
            button.cellStyle = .value1
        }.onCellSelection { [unowned self] _, _ in
            self.delegate?.didAction(action: .myWalletAddress, in: self)
        }.cellUpdate { [weak self] cell, _ in
            guard let strongSelf = self else { return }
            cell.height = { strongSelf.cellNoSubtitleHeight }
            cell.imageView?.image = R.image.settings_wallet1()?.imageWithInsets(insets: strongSelf.iconInset)?.withRenderingMode(.alwaysOriginal)
            cell.textLabel?.text = R.string.localizable.aSettingsContentsMyWalletAddress()
            cell.accessoryType = .disclosureIndicator
        }

        // Change Wallet
        <<< AlphaWalletSettingsButtonRow { button in
            button.cellStyle = .subtitle
            
        }.onCellSelection { [unowned self] _, _ in
            self.run(action: .wallets)
        }.cellUpdate { [weak self] cell, _ in
            guard let strongSelf = self else { return }
            cell.height = { strongSelf.cellWithSubtitleHeight }
            cell.imageView?.image = R.image.settings_wallet()?.imageWithInsets(insets: strongSelf.iconInset)?.withRenderingMode(.alwaysOriginal)
            cell.textLabel?.text = R.string.localizable.settingsWalletsButtonTitle()
            cell.detailTextLabel?.text = strongSelf.account.address.eip55String
            cell.accessoryType = .disclosureIndicator
        }

        //Back up his Wallet
        switch account.type {
        case .real:
            section1
            <<< AlphaWalletSettingsButtonRow {
                $0.title = R.string.localizable.settingsBackupWalletButtonTitle()
            }.onCellSelection { [unowned self] _, _ in
                self.delegate?.didAction(action: .backupWallet, in: self)
            }.cellUpdate { [weak self] cell, _ in
                guard let strongSelf = self else { return }
                cell.height = { strongSelf.cellNoSubtitleHeight }
                cell.imageView?.image = R.image.settings_wallet_backup()?.imageWithInsets(insets: strongSelf.iconInset)?.withRenderingMode(.alwaysOriginal)
                let walletSecurityLevel = PromptBackupCoordinator(keystore: strongSelf.keystore, wallet: strongSelf.account, config: .init()).securityLevel
                cell.accessoryView = walletSecurityLevel.flatMap { WalletSecurityLevelIndicator(level: $0) }
                cell.textLabel?.textAlignment = .left
            }
        case .watch:
            break
        }

        let section2 = Section("SYSTEM") { [weak self] section in
            guard let strongSelf = self else { return }
            var header = HeaderFooterView<UIView>(.class)
            header.onSetupView = { view, _ in
                view.backgroundColor = Screen.Setting.Color.sectionHeaderBackground
                let label = UILabel(frame: CGRect(x: (self?.sectionPosition.x)!, y: (self?.sectionPosition.y)!, width: 200, height: 30))
                label.text = "SYSTEM"
                label.font = UIFont(name: "SourceSansPro-Semibold", size: 15)
                label.textColor = Screen.Setting.Color.sectionHeaderText
                view.backgroundColor = Screen.Setting.Color.sectionHeaderBackground
                view.addSubview(label)
            }
            section.header = header
            section.header?.height = { strongSelf.sectionHeaderHeight }
        }
        
        section2
        <<<
        AlphaWalletSettingsButtonRow { button in
            button.cellStyle = .value1
        }.cellUpdate { [weak self] cell, _ in
                guard let strongSelf = self else { return }
                cell.height = { strongSelf.cellNoSubtitleHeight }
                cell.imageView?.image = R.image.settings_notification()?.imageWithInsets(insets: strongSelf.iconInset)?.withRenderingMode(.alwaysOriginal)
                cell.textLabel?.text = "Notifications"
                cell.accessoryType = .disclosureIndicator
        }
            
        <<< AlphaWalletSettingsButtonRow { button in
            button.cellStyle = .subtitle
        }.onCellSelection { [unowned self] _, _ in
            self.run(action: .locales)
        }.cellUpdate { [weak self] cell, _ in
            guard let strongSelf = self else { return }
            cell.height = { strongSelf.cellWithSubtitleHeight }
            cell.imageView?.image = R.image.settings_language()?.imageWithInsets(insets: strongSelf.iconInset)?.withRenderingMode(.alwaysOriginal)
            cell.textLabel?.text = strongSelf.viewModel.localeTitle
            cell.detailTextLabel?.text = AppLocale(id: Config.getLocale()).displayName
            cell.accessoryType = .disclosureIndicator
        }

        <<< AlphaWalletSettingsSwitchRow { [weak self] in
            $0.title = self?.viewModel.passcodeTitle
            $0.value = self?.isPasscodeEnabled
        }.onChange { [unowned self] row in
            if row.value == true {
                self.setPasscode { result in
                    row.value = result
                    row.updateCell()
                }
            } else {
                self.lock.deletePasscode()
            }
        }.cellUpdate { cell, _ in
            cell.height = { self.cellNoSubtitleHeight }
            cell.textLabel?.textColor = Screen.Setting.Color.title
            cell.imageView?.tintColor = Screen.Setting.Color.image
            cell.imageView?.image = R.image.settings_lock()?.imageWithInsets(insets: self.iconInset)?.withRenderingMode(.alwaysOriginal)
        }

        // Select Active Networks
        <<< AlphaWalletSettingsButtonRow { button in
            button.cellStyle = .value1
        }.onCellSelection { [unowned self] _, _ in
            self.run(action: .enabledServers)
        }.cellUpdate { cell, _ in
            cell.height = { self.cellNoSubtitleHeight }
            cell.imageView?.image = R.image.settings_server()?.imageWithInsets(insets: self.iconInset)?.withRenderingMode(.alwaysOriginal)
            cell.textLabel?.text = R.string.localizable.settingsEnabledNetworksButtonTitle()
            cell.accessoryType = .disclosureIndicator
        }
        
            // Token Script Overrides
        <<< AlphaWalletSettingsButtonRow { row in
            row.cellStyle = .value1
            row.presentationMode = .show(controllerProvider: ControllerProvider<UIViewController>.callback {
                self.delegate?.assetDefinitionsOverrideViewController(for: self) ?? UIViewController()
            }, onDismiss: { _ in
            })
        }.cellUpdate { cell, _ in
            cell.height = { self.cellNoSubtitleHeight }
            cell.textLabel?.text = R.string.localizable.aHelpAssetDefinitionOverridesTitle()
            cell.imageView?.image = R.image.settings_tokenscript_overrides()?.imageWithInsets(insets: self.iconInset)?.withRenderingMode(.alwaysOriginal)
            cell.accessoryType = .disclosureIndicator
        }
        
        // Console
        <<< AlphaWalletSettingsButtonRow { row in
            row.cellStyle = .value1
            row.presentationMode = .show(controllerProvider: ControllerProvider<UIViewController>.callback {
                self.delegate?.consoleViewController(for: self) ?? UIViewController()
            }, onDismiss: { _ in
            })
        }.cellUpdate { cell, _ in
            cell.height = { self.cellNoSubtitleHeight }
            cell.imageView?.image = R.image.settings_console()?.imageWithInsets(insets: self.iconInset)?.withRenderingMode(.alwaysOriginal)
            cell.textLabel?.text = R.string.localizable.aConsoleTitle()
            cell.accessoryType = .disclosureIndicator
        }
            
        // Clear Browser Cache
        <<< AlphaWalletSettingsButtonRow { row in
            row.cellStyle = .value1
        }.onCellSelection { [unowned self] _, _ in
            self.delegate?.didAction(action: .clearDappBrowserCache, in: self)
        }.cellUpdate { cell, _ in
            cell.height = { self.cellNoSubtitleHeight }
            cell.textLabel?.text = R.string.localizable.aSettingsContentsClearDappBrowserCache()
            cell.imageView?.image = R.image.settings_clear_dapp_cache()?.imageWithInsets(insets: self.iconInset)?.withRenderingMode(.alwaysOriginal)
        }
        
        let section3 = Section("SOCIAL NETWORKING") { [weak self] section in
            guard let strongSelf = self else { return }
            var header = HeaderFooterView<UIView>(.class)
            header.onSetupView = { view, _ in
                view.backgroundColor = Screen.Setting.Color.sectionHeaderBackground
                let label = UILabel(frame: CGRect(x: (self?.sectionPosition.x)!, y: (self?.sectionPosition.y)!, width: 200, height: 30))
                label.text = "SOCIAL NETWORKING"
                label.font = UIFont(name: "SourceSansPro-Semibold", size: 15)
                label.textColor = Screen.Setting.Color.sectionHeaderText
                view.backgroundColor = Screen.Setting.Color.sectionHeaderBackground
                view.addSubview(label)
            }
            section.header = header
            section.header?.height = { strongSelf.sectionHeaderHeight }
        }
        
        section3
        <<< linkProvider(type: .telegram)
        <<< linkProvider(type: .twitter)
        <<< linkProvider(type: .reddit)
        <<< linkProvider(type: .facebook)
        
        let section4 = Section("SUPPORT") { [weak self] section in
            guard let strongSelf = self else { return }
            var header = HeaderFooterView<UIView>(.class)
            header.onSetupView = { view, _ in
                view.backgroundColor = Screen.Setting.Color.sectionHeaderBackground
                let label = UILabel(frame: CGRect(x: (self?.sectionPosition.x)!, y: (self?.sectionPosition.y)!, width: 200, height: 30))
                label.text = "SUPPORT"
                label.font = UIFont(name: "SourceSansPro-Semibold", size: 15)
                label.textColor = Screen.Setting.Color.sectionHeaderText
                view.backgroundColor = Screen.Setting.Color.sectionHeaderBackground
                view.addSubview(label)
            }
            section.header = header
            section.header?.height = { strongSelf.sectionHeaderHeight }
        }
        <<< AlphaWalletSettingsButtonRow { row in
            row.cellStyle = .value1
            row.presentationMode = .show(controllerProvider: ControllerProvider<UIViewController>.callback {
                let vc = HelpViewController(delegate: self)
                vc.hidesBottomBarWhenPushed = true
                return vc
            }, onDismiss: { _ in
            })
        }.cellUpdate { cell, _ in
            cell.imageView?.image = R.image.settings_faq()?.imageWithInsets(insets: self.iconInset)?.withRenderingMode(.alwaysOriginal)
            cell.textLabel?.text = R.string.localizable.aHelpNavigationTitle()
            cell.accessoryType = .disclosureIndicator
            cell.height = { self.cellNoSubtitleHeight }
        }

        <<< AlphaWalletSettingsTextRow {
            $0.disabled = true
        }.cellSetup { cell, _ in
            cell.height = { self.cellNoSubtitleHeight }
            cell.mainLabel.font = UIFont(name: "SourceSansPro-Semibold", size: 15)
            cell.mainLabel.textColor = Screen.Setting.Color.sectionHeaderText
            cell.mainLabel.text = R.string.localizable.settingsVersionLabelTitle()
            cell.subLabel.text = "\(Bundle.main.fullVersion). \(TokenScript.supportedTokenScriptNamespaceVersion)"
        }

        form +++ section1   // Wallet
        form +++ section2   // System
        //form +++ section3   // Social Networking
        form +++ section4   // Support
        
        //Check for nil is important because the prompt might have been shown before viewDidLoad
        if promptBackupWalletView == nil {
            hidePromptBackupWalletView()
        }

        NSLayoutConstraint.activate([
            tableView.anchorsConstraint(to: view),
        ])
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        reflectCurrentWalletSecurityLevel()
    }

    private func showPromptBackupWalletViewAsTableHeaderView() {
        let size = promptBackupWalletViewHolder.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize)
        promptBackupWalletViewHolder.bounds.size.height = size.height
        //Access `view` to force it to be created to avoid crashing when we access `tableView` next, because `tableView` is only created after that, and is defined as `UITableView!`.
        let _ = view
        tableView.tableHeaderView = promptBackupWalletViewHolder
    }

    private func hidePromptBackupWalletView() {
        //`tableView` is defined as `UIUTableView!` and may not have been created yet
        guard tableView != nil && tableView.tableHeaderView != nil else { return }
        tableView.tableHeaderView = nil
    }

    private func reflectCurrentWalletSecurityLevel() {
        tableView.reloadData()
    }

    func setPasscode(completion: ((Bool) -> Void)? = .none) {
        let lock = LockCreatePasscodeCoordinator(navigationController: navigationController!, model: LockCreatePasscodeViewModel())
        lock.start()
        lock.lockViewController.willFinishWithResult = { result in
            completion?(result)
            lock.stop()
        }
    }

    private func linkProvider(
            type: URLServiceProvider
    ) -> AlphaWalletSettingsButtonRow {
        return AlphaWalletSettingsButtonRow {
            $0.title = type.title
        }.onCellSelection { [unowned self] _, _ in
            if let localURL = type.localURL, UIApplication.shared.canOpenURL(localURL) {
                UIApplication.shared.open(localURL, options: convertToUIApplicationOpenExternalURLOptionsKeyDictionary([:]), completionHandler: .none)
            } else {
                self.delegate?.didPressOpenWebPage(type.remoteURL, in: self)
            }
        }.cellUpdate { cell, _ in
            cell.textLabel?.textAlignment = .left
            cell.imageView?.image = type.image?.imageWithInsets(insets: self.iconInset)?.withRenderingMode(.alwaysTemplate)
        }
    }

    func run(action: AlphaWalletSettingsAction) {
        delegate?.didAction(action: action, in: self)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension SettingsViewController: HelpViewControllerDelegate {
}

extension SettingsViewController: CanOpenURL {
    func didPressViewContractWebPage(forContract contract: AlphaWallet.Address, server: RPCServer, in viewController: UIViewController) {
        delegate?.didPressViewContractWebPage(forContract: contract, server: server, in: viewController)
    }

    func didPressViewContractWebPage(_ url: URL, in viewController: UIViewController) {
        delegate?.didPressViewContractWebPage(url, in: viewController)
    }

    func didPressOpenWebPage(_ url: URL, in viewController: UIViewController) {
        delegate?.didPressOpenWebPage(url, in: viewController)
    }
}

// Helper function inserted by Swift 4.2 migrator.
private func convertToUIApplicationOpenExternalURLOptionsKeyDictionary(_ input: [String: Any]) -> [UIApplication.OpenExternalURLOptionsKey: Any] {
	return Dictionary(uniqueKeysWithValues: input.map { key, value in (UIApplication.OpenExternalURLOptionsKey(rawValue: key), value) })
}

extension UIImage {
    fileprivate func imageWithInsets(insets: UIEdgeInsets) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions( CGSize(width: size.width + insets.left + insets.right, height: size.height + insets.top + insets.bottom), false, scale)
        let _ = UIGraphicsGetCurrentContext()
        let origin = CGPoint(x: insets.left, y: insets.top)
        draw(at: origin)
        let imageWithInsets = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return imageWithInsets
    }
}
