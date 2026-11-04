import Foundation
import UIKit
import AsyncDisplayKit
import Display
import AccountContext
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences
import SwiftSignalKit
import UniformTypeIdentifiers
import ImageIO

public func mechagramVisualController(context: AccountContext) -> ViewController {
    return MechagramVisualController(context: context)
}

private final class MechagramVisualController: ViewController, UITableViewDataSource, UITableViewDelegate, UIDocumentPickerDelegate, UIColorPickerViewControllerDelegate {
    private let context: AccountContext
    private let table = UITableView(frame: .zero, style: .insetGrouped)
    private var style: MechagramVisualProfile
    private let presentationDisposable = MetaDisposable()
    private var applyingColor: ((String) -> Void)?
    private var peerValue: Int64 { return self.context.account.peerId.toInt64() }
    private let fontNames = ["Системный", "Скруглённый", "С засечками", "Моноширинный"]
    private let fontValues = ["system", "rounded", "serif", "monospace"]

    init(context: AccountContext) {
        self.context = context
        self.style = MechagramVisualProfile.load(peerId: context.account.peerId.toInt64())
        let data = context.sharedContext.currentPresentationData.with { $0 }
        super.init(navigationBarPresentationData: NavigationBarPresentationData(presentationData: data))
        self.navigationItem.title = "Визуал"
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Сбросить", style: .plain, target: self, action: #selector(self.resetProfile))
        self.presentationDisposable.set((context.sharedContext.presentationData |> deliverOnMainQueue).start(next: { [weak self] data in
            guard let self else { return }
            if self.isViewLoaded { self.displayNode.backgroundColor = data.theme.list.blocksBackgroundColor }
            self.table.reloadData()
        }))
    }

    required init(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    deinit { self.presentationDisposable.dispose() }

    override func loadDisplayNode() {
        self.displayNode = ASDisplayNode()
        self.displayNode.backgroundColor = self.context.sharedContext.currentPresentationData.with { $0 }.theme.list.blocksBackgroundColor
        self.table.backgroundColor = .clear
        self.table.dataSource = self
        self.table.delegate = self
        self.displayNode.view.addSubview(self.table)
        self.displayNodeDidLoad()
    }

    override func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition: transition)
        self.table.frame = CGRect(origin: .zero, size: layout.size)
        self.table.contentInset = UIEdgeInsets(top: navigationBarHeight, left: 0, bottom: layout.intrinsicInsets.bottom, right: 0)
        self.table.scrollIndicatorInsets = self.table.contentInset
    }

    private func save() {
        self.style.save(peerId: self.peerValue)
        self.table.reloadData()
    }

    func numberOfSections(in tableView: UITableView) -> Int { return 4 }
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { return [4, 4, 5, 2][section] }
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? { return ["Приложение", "Мой профиль", "Аватар и фон", "Ник и украшения"][section] }
    func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        if section == 0 { return "Цвет применяется средствами Telegram. После смены общего шрифта перезапустите приложение, чтобы обновить все экраны." }
        if section == 1 { return "Номер +888, NFT-юзернейм и галочка меняют оформление профиля на этом устройстве. Они не меняют номер входа, владение Fragment или статус верификации Telegram." }
        if section == 2 { return "Фон можно выбрать из Файлов. Удерживайте строку с цветом, чтобы сбросить его. Параметры профиля сохраняются отдельно для каждого аккаунта." }
        return nil
    }

    private func fontName(_ value: String) -> String { return self.fontNames[self.fontValues.firstIndex(of: value) ?? 0] }

    private func pickColor(_ title: String, value: String, apply: @escaping (String) -> Void) {
        let picker = UIColorPickerViewController()
        picker.title = title
        picker.supportsAlpha = false
        if let rgb = UInt32(value, radix: 16) { picker.selectedColor = UIColor(red: CGFloat((rgb >> 16) & 255) / 255, green: CGFloat((rgb >> 8) & 255) / 255, blue: CGFloat(rgb & 255) / 255, alpha: 1) }
        picker.delegate = self
        self.applyingColor = apply
        self.show(picker)
    }

    func colorPickerViewControllerDidFinish(_ viewController: UIColorPickerViewController) {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard viewController.selectedColor.getRed(&r, green: &g, blue: &b, alpha: &a) else { return }
        func channel(_ value: CGFloat) -> Int { return min(255, max(0, Int((value * 255).rounded()))) }
        self.applyingColor?(String(format: "%02X%02X%02X", channel(r), channel(g), channel(b)))
        self.applyingColor = nil
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
        let data = self.context.sharedContext.currentPresentationData.with { $0 }
        cell.backgroundColor = data.theme.list.itemBlocksBackgroundColor
        cell.textLabel?.textColor = data.theme.list.itemPrimaryTextColor
        cell.detailTextLabel?.textColor = data.theme.list.itemSecondaryTextColor
        cell.textLabel?.font = Font.regular(17)
        cell.detailTextLabel?.font = Font.regular(15)
        cell.accessoryType = .disclosureIndicator
        let titles = [["Цвет приложения", "Светлая / тёмная тема", "Шрифт приложения", "Фон чатов и оформление"], ["Показывать оформление профиля", "Анонимный номер +888", "NFT-юзернейм", "Галочка в профиле"], ["Рамка аватара", "Форма рамки", "Цвет рамки", "Цвет фона профиля", "Изображение фона профиля"], ["Шрифт ника", "Декоративный значок"]]
        cell.textLabel?.text = titles[indexPath.section][indexPath.row]
        if indexPath.section == 1 && (indexPath.row == 0 || indexPath.row == 3) {
            let control = UISwitch()
            control.isOn = indexPath.row == 0 ? self.style.enabled : self.style.verified
            control.tag = indexPath.row
            control.addTarget(self, action: #selector(self.toggle(_:)), for: .valueChanged)
            cell.accessoryView = control
            cell.selectionStyle = .none
        }
        switch (indexPath.section, indexPath.row) {
        case (0, 0): cell.detailTextLabel?.text = "Палитра"
        case (0, 2): cell.detailTextLabel?.text = self.fontName(UserDefaults.standard.string(forKey: "mechagram.visual.font.app") ?? "system")
        case (1, 1): cell.detailTextLabel?.text = self.style.anonymousPhone.isEmpty ? "Не задан" : "+" + self.style.anonymousPhone
        case (1, 2): cell.detailTextLabel?.text = self.style.collectibleUsername.isEmpty ? "Не задан" : "@" + self.style.collectibleUsername
        case (2, 0): cell.detailTextLabel?.text = ["none": "Нет", "ring": "Обод", "beads": "Бусины", "gem": "Камень", "sparks": "Искры"][self.style.framePreset]
        case (2, 1): cell.detailTextLabel?.text = ["circle": "Круг", "rounded": "Скруглённый", "square": "Квадрат", "hex": "Шестиугольник"][self.style.frameShape]
        case (2, 2): cell.detailTextLabel?.text = "#" + self.style.frameColor
        case (2, 3): cell.detailTextLabel?.text = self.style.profileColor.isEmpty ? "Стандартный" : "#" + self.style.profileColor
        case (2, 4): cell.detailTextLabel?.text = self.style.backgroundImage.isEmpty ? "Выбрать" : "Выбрано"
        case (3, 0): cell.detailTextLabel?.text = self.fontName(self.style.nicknameFont)
        case (3, 1): cell.detailTextLabel?.text = self.style.decoration
        default: break
        }
        return cell
    }

    @objc private func toggle(_ sender: UISwitch) {
        if sender.tag == 0 { self.style.enabled = sender.isOn } else { self.style.verified = sender.isOn }
        self.save()
    }

    private func show(_ controller: UIViewController) {
        if let popover = controller.popoverPresentationController { popover.sourceView = self.table; popover.sourceRect = CGRect(x: self.table.bounds.midX, y: 80, width: 1, height: 1) }
        self.present(controller, animated: true)
    }

    private func choices(_ title: String, values: [String], select: @escaping (Int) -> Void) {
        let sheet = UIAlertController(title: title, message: nil, preferredStyle: .actionSheet)
        for (index, value) in values.enumerated() { sheet.addAction(UIAlertAction(title: value, style: .default, handler: { _ in select(index) })) }
        sheet.addAction(UIAlertAction(title: "Отмена", style: .cancel))
        self.show(sheet)
    }

    private func edit(_ title: String, value: String, placeholder: String, validate: @escaping (String) -> String?, apply: @escaping (String) -> Void) {
        let alert = UIAlertController(title: title, message: nil, preferredStyle: .alert)
        alert.addTextField { field in field.text = value; field.placeholder = placeholder; field.autocorrectionType = .no; field.autocapitalizationType = .none }
        alert.addAction(UIAlertAction(title: "Отмена", style: .cancel))
        alert.addAction(UIAlertAction(title: "Убрать", style: .destructive, handler: { _ in apply("") }))
        alert.addAction(UIAlertAction(title: "Сохранить", style: .default, handler: { [weak self] _ in
            guard let normalized = validate(alert.textFields?.first?.text ?? "") else {
                let error = UIAlertController(title: "Проверьте значение", message: placeholder, preferredStyle: .alert)
                error.addAction(UIAlertAction(title: "OK", style: .default))
                self?.show(error)
                return
            }
            apply(normalized)
        }))
        self.show(alert)
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        switch (indexPath.section, indexPath.row) {
        case (0, 0):
            self.pickColor("Цвет приложения", value: UserDefaults.standard.string(forKey: "mechagram.visual.accent") ?? "FF453A", apply: { [weak self] value in self?.applyAccent(value) })
        case (0, 1):
            self.choices("Тема", values: ["Светлая", "Тёмная", "Тонированная тёмная"]) { [weak self] index in
                guard let self else { return }
                let reference: PresentationBuiltinThemeReference = index == 0 ? .day : (index == 1 ? .night : .nightAccent)
                let _ = updatePresentationThemeSettingsInteractively(accountManager: self.context.sharedContext.accountManager, { current in
                    var automatic = current.automaticThemeSwitchSetting
                    automatic.force = index != 0
                    if index != 0 { automatic.theme = .builtin(reference) }
                    return current.withUpdatedTheme(.builtin(reference)).withUpdatedAutomaticThemeSwitchSetting(automatic)
                }).startStandalone()
            }
        case (0, 2):
            self.choices("Шрифт приложения", values: self.fontNames) { [weak self] index in
                guard let self else { return }; UserDefaults.standard.set(self.fontValues[index], forKey: "mechagram.visual.font.app"); self.save()
            }
        case (0, 3): self.push(themeSettingsController(context: self.context))
        case (1, 1): self.edit("Анонимный номер", value: self.style.anonymousPhone, placeholder: "+888 и от 7 до 15 цифр", validate: MechagramVisualProfile.normalizedPhone) { [weak self] value in self?.style.anonymousPhone = value; self?.save() }
        case (1, 2): self.edit("NFT-юзернейм", value: self.style.collectibleUsername, placeholder: "От 1 до 32 латинских букв, цифр и _; первая — буква", validate: MechagramVisualProfile.normalizedUsername) { [weak self] value in self?.style.collectibleUsername = value; self?.save() }
        case (2, 0): self.choices("Рамка", values: ["Нет", "Обод", "Бусины", "Камень", "Искры"]) { [weak self] index in self?.style.framePreset = ["none", "ring", "beads", "gem", "sparks"][index]; self?.save() }
        case (2, 1): self.choices("Форма рамки", values: ["Круг", "Скруглённый", "Квадрат", "Шестиугольник"]) { [weak self] index in self?.style.frameShape = ["circle", "rounded", "square", "hex"][index]; self?.save() }
        case (2, 2): self.pickColor("Цвет рамки", value: self.style.frameColor) { [weak self] value in self?.style.frameColor = value; self?.save() }
        case (2, 3): self.pickColor("Цвет фона профиля", value: self.style.profileColor) { [weak self] value in self?.style.profileColor = value; self?.save() }
        case (2, 4): self.choices("Фон профиля", values: ["Выбрать изображение из Файлов", "Убрать изображение"]) { [weak self] index in
            guard let self else { return }
            if index == 1 { self.style.backgroundImage = ""; self.save(); return }
            let picker: UIDocumentPickerViewController
            if #available(iOS 14.0, *) { picker = UIDocumentPickerViewController(forOpeningContentTypes: [.image], asCopy: true) }
            else { picker = UIDocumentPickerViewController(documentTypes: ["public.image"], in: .import) }
            picker.delegate = self
            self.show(picker)
        }
        case (3, 0): self.choices("Шрифт ника", values: self.fontNames) { [weak self] index in guard let self else { return }; self.style.nicknameFont = self.fontValues[index]; self.save() }
        case (3, 1): self.edit("Украшение аватара", value: self.style.decoration, placeholder: "До 4 символов, например 🎀 или 💎", validate: { $0.count <= 4 ? $0 : nil }) { [weak self] value in self?.style.decoration = value; self?.save() }
        default: break
        }
    }

    func tableView(_ tableView: UITableView, contextMenuConfigurationForRowAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        guard (indexPath.section == 0 && indexPath.row == 0) || (indexPath.section == 2 && (indexPath.row == 2 || indexPath.row == 3)) else { return nil }
        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil, actionProvider: { [weak self] _ in
            guard let self else { return UIMenu(children: []) }
            let reset = UIAction(title: "Сбросить цвет", image: UIImage(systemName: "arrow.counterclockwise")) { [weak self] _ in
                guard let self else { return }
                if indexPath.section == 0 { self.applyAccent("") }
                else if indexPath.row == 2 { self.style.frameColor = "FF453A"; self.save() }
                else { self.style.profileColor = ""; self.save() }
            }
            return UIMenu(children: [reset])
        })
    }

    private func applyAccent(_ value: String) {
        UserDefaults.standard.set(value, forKey: "mechagram.visual.accent")
        let rgb = UInt32(value, radix: 16)
        let _ = updatePresentationThemeSettingsInteractively(accountManager: self.context.sharedContext.accountManager, { current in
            var colors = current.themeSpecificAccentColors
            let bases: [PresentationBuiltinThemeReference] = [.dayClassic, .day, .night, .nightAccent]
            let indexes = Set(bases.map { PresentationThemeReference.builtin($0).index } + [current.theme.index, current.automaticThemeSwitchSetting.theme.index])
            for key in indexes {
                if let rgb { colors[key] = PresentationThemeAccentColor(index: 0, baseColor: .custom, accentColor: rgb) }
                else { colors.removeValue(forKey: key) }
            }
            return current.withUpdatedThemeSpecificAccentColors(colors)
        }).startStandalone()
        self.table.reloadData()
    }

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first else { return }
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            let options: [CFString: Any] = [kCGImageSourceCreateThumbnailFromImageAlways: true, kCGImageSourceCreateThumbnailWithTransform: true, kCGImageSourceThumbnailMaxPixelSize: 2048, kCGImageSourceShouldCacheImmediately: true]
            guard ((attributes[.size] as? NSNumber)?.intValue ?? Int.max) <= 20_000_000,
                  let source = CGImageSourceCreateWithURL(url as CFURL, nil),
                  let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary),
                  let data = UIImage(cgImage: thumbnail).jpegData(compressionQuality: 0.85) else { throw NSError(domain: "MechagramImage", code: 1) }
            let directory = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true).appendingPathComponent("MechagramVisuals", isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let previous = URL(fileURLWithPath: self.style.backgroundImage)
            let destination = directory.appendingPathComponent("profile-\(self.peerValue)-\(UUID().uuidString).jpg")
            try data.write(to: destination, options: .atomic)
            self.style.backgroundImage = destination.path
            self.save()
            if previous.deletingLastPathComponent().standardizedFileURL == directory.standardizedFileURL && previous.lastPathComponent.hasPrefix("profile-\(self.peerValue)") { try? FileManager.default.removeItem(at: previous) }
        } catch {
            let alert = UIAlertController(title: "Не удалось открыть изображение", message: "Выберите JPG, PNG или HEIC размером до 20 МБ.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            self.show(alert)
        }
    }

    @objc private func resetProfile() {
        let sheet = UIAlertController(title: "Сбросить оформление?", message: "Будут убраны локальный номер, юзернейм, галочка, рамка и фон этого аккаунта. Общий шрифт, цвет и тема Telegram останутся выбранными.", preferredStyle: .alert)
        sheet.addAction(UIAlertAction(title: "Отмена", style: .cancel))
        sheet.addAction(UIAlertAction(title: "Сбросить", style: .destructive, handler: { [weak self] _ in self?.style = MechagramVisualProfile(); self?.save() }))
        self.show(sheet)
    }
}
