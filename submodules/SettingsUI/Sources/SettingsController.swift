import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import TelegramCore
import AccountContext
import PasswordSetupUI
import ItemListUI
import TelegramPresentationData

public protocol SettingsController: AnyObject {
    func updateContext(context: AccountContext)
}

public func makePrivacyAndSecurityController(context: AccountContext) -> ViewController {
    return privacyAndSecurityController(context: context, focusOnItemTag: PrivacyAndSecurityEntryTag.autoArchive)
}

public func makeBioPrivacyController(context: AccountContext, settings: Promise<AccountPrivacySettings?>, present: @escaping (ViewController) -> Void) {
    let signal = settings.get()
    |> take(1)
    |> deliverOnMainQueue
    
    let _ = signal.startStandalone(next: { info in
        if let info = info {
            present(selectivePrivacySettingsController(context: context, kind: .bio, current: info.bio, updated: { updated, _, _, _ in
                let applySetting: Signal<Void, NoError> = settings.get()
                |> filter { $0 != nil }
                |> take(1)
                |> deliverOnMainQueue
                |> mapToSignal { value -> Signal<Void, NoError> in
                    if let value = value {
                        settings.set(.single(AccountPrivacySettings(presence: value.presence, groupInvitations: value.groupInvitations, voiceCalls: value.voiceCalls, voiceCallsP2P: value.voiceCallsP2P, profilePhoto: value.profilePhoto, forwards: value.forwards, phoneNumber: value.phoneNumber, phoneDiscoveryEnabled: value.phoneDiscoveryEnabled, voiceMessages: value.voiceMessages, bio: updated, birthday: value.birthday, giftsAutoSave: value.giftsAutoSave, noPaidMessages: value.noPaidMessages, savedMusic: value.savedMusic,  globalSettings: value.globalSettings, accountRemovalTimeout: value.accountRemovalTimeout, messageAutoremoveTimeout: value.messageAutoremoveTimeout)))
                    }
                    return .complete()
                }
                let _ = applySetting.startStandalone()
            }))
        }
    })
}

public func makeBirthdayPrivacyController(context: AccountContext, settings: Promise<AccountPrivacySettings?>, openedFromBirthdayScreen: Bool, present: @escaping (ViewController) -> Void) {
    let signal = settings.get()
    |> take(1)
    |> deliverOnMainQueue
    
    let _ = signal.startStandalone(next: { info in
        if let info = info {
            present(selectivePrivacySettingsController(context: context, kind: .birthday, current: info.birthday, openedFromBirthdayScreen: openedFromBirthdayScreen, updated: { updated, _, _, _ in
                let applySetting: Signal<Void, NoError> = settings.get()
                |> filter { $0 != nil }
                |> take(1)
                |> deliverOnMainQueue
                |> mapToSignal { value -> Signal<Void, NoError> in
                    if let value = value {
                        settings.set(.single(AccountPrivacySettings(presence: value.presence, groupInvitations: value.groupInvitations, voiceCalls: value.voiceCalls, voiceCallsP2P: value.voiceCallsP2P, profilePhoto: value.profilePhoto, forwards: value.forwards, phoneNumber: value.phoneNumber, phoneDiscoveryEnabled: value.phoneDiscoveryEnabled, voiceMessages: value.voiceMessages, bio: value.bio, birthday: updated, giftsAutoSave: value.giftsAutoSave, noPaidMessages: value.noPaidMessages, savedMusic: value.savedMusic, globalSettings: value.globalSettings, accountRemovalTimeout: value.accountRemovalTimeout, messageAutoremoveTimeout: value.messageAutoremoveTimeout)))
                    }
                    return .complete()
                }
                let _ = applySetting.startStandalone()
            }))
        }
    })
}

public func makeSetupTwoFactorAuthController(context: AccountContext) -> ViewController {
    let presentationData = context.sharedContext.currentPresentationData.with { $0 }
    let controller = TwoFactorAuthSplashScreen(sharedContext: context.sharedContext, engine: .authorized(context.engine), mode: .intro(.init(
        title: presentationData.strings.TwoFactorSetup_Intro_Title,
        text: presentationData.strings.TwoFactorSetup_Intro_Text,
        actionText: presentationData.strings.TwoFactorSetup_Intro_Action,
        doneText: presentationData.strings.TwoFactorSetup_Done_Action,
        phoneNumber: nil
    )))
    return controller
}

private final class ExteraPortSettingsArguments {
    let update: (Int32, Bool) -> Void
    var editBalance: ((Bool) -> Void)?
    var hideSettings: (() -> Void)?

    init(update: @escaping (Int32, Bool) -> Void) {
        self.update = update
    }
}

private enum ExteraPortSettingsEntry: ItemListNodeEntry {
    case toggle(Int32, String, Bool)
    case footer(String)
    case balance(Int32, String, Bool)
    case hide(String)

    var section: ItemListSectionId { return 0 }

    var stableId: Int32 {
        switch self {
        case let .toggle(index, _, _): return index
        case let .balance(index, _, _): return 20 + index
        case .footer: return 100
        case .hide: return 90
        }
    }

    static func < (lhs: ExteraPortSettingsEntry, rhs: ExteraPortSettingsEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! ExteraPortSettingsArguments
        switch self {
        case let .toggle(index, title, value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: title, value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.update(index, value)
            })
        case let .balance(_, title, isTon):
            return ItemListActionItem(presentationData: presentationData, systemStyle: .glass, title: title, kind: .generic, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                arguments.editBalance?(isTon)
            })
        case let .footer(text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
        case let .hide(title):
            return ItemListActionItem(presentationData: presentationData, systemStyle: .glass, title: title, kind: .generic, alignment: .natural, sectionId: self.section, style: .blocks, action: { arguments.hideSettings?() })
        }
    }
}

public func exteraPortSettingsController(context: AccountContext) -> ViewController {
    let keys = ["exteraPort.showMessageDetails", "exteraPort.hideOwnPhoneNumber", "exteraPort.hideStories", "exteraPort.messageSeconds", "exteraPort.fullCounts", "mechagram.keepDeleted", "mechagram.visualBalances", "mechagram.visualGifts", mechagramSkipGiftConfirmationKey]
    let defaults = [true, false, false, false, false, true, false, false, true]
    let readValues: () -> [Bool] = {
        return keys.enumerated().map { index, key in
            if key == mechagramSkipGiftConfirmationKey { return mechagramSkipGiftConfirmation() }
            return UserDefaults.standard.object(forKey: key) as? Bool ?? defaults[index]
        }
    }
    weak var resultController: ViewController?
    var revisionValue = 0
    let revision = ValuePromise<Int>(0)
    let values = ValuePromise<[Bool]>(readValues(), ignoreRepeated: true)
    let arguments = ExteraPortSettingsArguments(update: { index, value in
        guard keys.indices.contains(Int(index)) else { return }
        let key = keys[Int(index)]
        if key == mechagramSkipGiftConfirmationKey {
            mechagramSetSkipGiftConfirmation(value)
        } else {
            UserDefaults.standard.set(value, forKey: key)
        }
        values.set(readValues())
    })
    arguments.hideSettings = {
        mechagramHideSettingsSessionOnly = true
        UserDefaults.standard.removeObject(forKey: "mechagram.hideSettings.v1")
        let _ = resultController?.navigationController?.popViewController(animated: true)
    }

    arguments.editBalance = { isTon in
        let key = isTon ? "mechagram.visualTON" : "mechagram.visualStars"
        let alert = UIAlertController(title: isTon ? "TON" : "Stars", message: "Только отображение. Покупки и переводы используют настоящий баланс.", preferredStyle: .alert)
        alert.addTextField { field in
            field.keyboardType = .decimalPad
            field.text = UserDefaults.standard.string(forKey: key) ?? "0"
            field.placeholder = "0"
        }
        alert.addAction(UIAlertAction(title: "Отмена", style: .cancel))
        alert.addAction(UIAlertAction(title: "Сбросить", style: .destructive, handler: { _ in
            UserDefaults.standard.removeObject(forKey: key)
            revisionValue += 1
            revision.set(revisionValue)
        }))
        alert.addAction(UIAlertAction(title: "Сохранить", style: .default, handler: { _ in
            let text = (alert.textFields?.first?.text ?? "").replacingOccurrences(of: ",", with: ".").trimmingCharacters(in: .whitespacesAndNewlines)
            guard let amount = Double(text), amount.isFinite, amount >= 0, amount <= 1_000_000_000_000, isTon || amount.rounded() == amount else {
                let error = UIAlertController(title: "Некорректное значение", message: "Введите положительное число до 1 000 000 000 000. Stars — целое число.", preferredStyle: .alert)
                error.addAction(UIAlertAction(title: "OK", style: .default))
                resultController?.view.window?.rootViewController?.present(error, animated: true)
                return
            }
            UserDefaults.standard.set(text, forKey: key)
            revisionValue += 1
            revision.set(revisionValue)
        }))
        resultController?.view.window?.rootViewController?.present(alert, animated: true)
    }
    let signal = combineLatest(queue: .mainQueue(),
        context.sharedContext.presentationData,
        values.get(),
        revision.get()
    )
    |> map { presentationData, values, _ -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let isRussian = (Locale.current.languageCode ?? "en") == "ru"
        let titles = isRussian
            ? ["Данные сообщения", "Скрывать номер в шапке настроек", "Скрывать истории над чатами", "Секунды во времени сообщений", "Полные числа вместо K/M", "Сохранять удалённые сообщения", "Балансы", "Локальные подарки", "Отправлять подарки без подтверждения"]
            : ["Message details", "Hide phone number in settings header", "Hide stories above chats", "Seconds in message timestamps", "Full counts instead of K/M", "Keep deleted messages", "Balances", "Local gifts", "Send gifts without confirmation"]
        let title = "Mechagram"
        let footer = isRussian
            ? "Некоторые параметры требуют перезапуска. Переключатель отправки без подтверждения действует сразу. Параметры действуют для всех аккаунтов на этом устройстве."
            : "Some options require a restart. Sending without confirmation takes effect immediately. Options apply to all accounts on this device."
        var entries: [ExteraPortSettingsEntry] = []
        for (index, label) in titles.enumerated() {
            entries.append(.toggle(Int32(index), label, values[index]))
        }
        entries.append(.balance(0, "Stars: " + (UserDefaults.standard.string(forKey: "mechagram.visualStars") ?? "—"), false))
        entries.append(.balance(1, "TON: " + (UserDefaults.standard.string(forKey: "mechagram.visualTON") ?? "—"), true))
        entries.append(.hide(isRussian ? "Скрыть пункт настроек мода" : "Hide mod settings entry"))
        entries.append(.footer(footer + (isRussian ? " Чтобы вернуть скрытый пункт, удерживайте строку «Оформление» в настройках Telegram. Функции мода продолжают работать. Подарки и действия с ними — копии Mechagram; настоящие покупки используют настоящий баланс." : " To restore the hidden entry, hold Appearance in Telegram settings. Mod features continue working. Gifts and their actions are Mechagram copies; real purchases use the real balance.")))
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(title), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: entries, style: .blocks, animateChanges: false)
        return (controllerState, (listState, arguments))
    }

    let controller = ItemListController(context: context, state: signal)
    resultController = controller
    return controller
}
