import Foundation
import Postbox

// MECHAGRAM_VISUAL_PROFILE_POLICY_BEGIN
public struct MechagramVisualProfile: Codable, Equatable {
    public var enabled = true
    public var anonymousPhone = ""
    public var collectibleUsername = ""
    public var verified = false
    public var nicknameFont = "system"
    public var frameShape = "circle"
    public var framePreset = "none"
    public var frameColor = "FF453A"
    public var frameWidth: Double = 4
    public var decoration = "✨"
    public var profileColor = ""
    public var backgroundImage = ""

    public init() {}

    public static func load(peerId: Int64, defaults: UserDefaults = .standard) -> MechagramVisualProfile {
        guard let data = defaults.data(forKey: "mechagram.visual.profile.v1.\(peerId)"), let value = try? JSONDecoder().decode(Self.self, from: data) else { return Self() }
        return value
    }

    public func save(peerId: Int64, defaults: UserDefaults = .standard) {
        guard let data = try? JSONEncoder().encode(self) else { return }
        defaults.set(data, forKey: "mechagram.visual.profile.v1.\(peerId)")
        DispatchQueue.main.async { NotificationCenter.default.post(name: Notification.Name("MechagramVisualStyleChanged"), object: nil) }
    }

    public static func normalizedPhone(_ text: String) -> String? {
        let digits = text.filter { $0.isASCII && $0.isNumber }
        guard digits.hasPrefix("888"), (7...15).contains(digits.count), text.allSatisfy({ $0.isASCII && ($0.isNumber || "+ -()".contains($0)) }) else { return nil }
        return digits
    }

    public static func normalizedUsername(_ text: String) -> String? {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: "@"))
        guard value.range(of: "^[A-Za-z][A-Za-z0-9_]{0,31}$", options: .regularExpression) != nil else { return nil }
        return value
    }

    public static func normalizedGram(_ text: String) -> String? {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ",", with: ".")
        guard value.range(of: "^[0-9]{1,10}(\\.[0-9]{1,9})?$", options: .regularExpression) != nil,
              let amount = Decimal(string: value, locale: Locale(identifier: "en_US_POSIX")), amount <= Decimal(1_000_000_000) else { return nil }
        return value
    }

    public static func gramNanos(_ text: String) -> Int64? {
        guard let value = normalizedGram(text) else { return nil }
        return NSDecimalNumber(string: value, locale: Locale(identifier: "en_US_POSIX")).multiplying(by: NSDecimalNumber(value: 1_000_000_000)).int64Value
    }

    public static func normalizedRatingNumber(_ text: String, maximum: Int64) -> String? {
        guard !text.isEmpty, text.allSatisfy({ $0.isASCII && $0.isNumber }), let value = Int64(text), value <= maximum else { return nil }
        return String(value)
    }

    public static func normalizedColor(_ text: String) -> String? {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "#", with: "").uppercased()
        guard value.range(of: "^[0-9A-F]{6}$", options: .regularExpression) != nil else { return nil }
        return value
    }
}
// MECHAGRAM_VISUAL_PROFILE_POLICY_END

// This view model is used only by profile rendering. Authentication, contacts,
// username resolution, wallet ownership and Postbox peers retain real data.
public func mechagramVisualProfilePeer(_ peer: EnginePeer) -> EnginePeer {
    guard case let .user(user) = peer else { return peer }
    let style = MechagramVisualProfile.load(peerId: user.id.toInt64())
    guard style.enabled else { return peer }
    var result = user
    if let phone = MechagramVisualProfile.normalizedPhone(style.anonymousPhone) { result = result.withUpdatedPhone(phone) }
    if let username = MechagramVisualProfile.normalizedUsername(style.collectibleUsername) {
        result = result.withUpdatedUsername(username).withUpdatedUsernames([TelegramPeerUsername(flags: [.isActive], username: username)])
    }
    if style.verified { result = result.withUpdatedFlags(result.flags.union(.isVerified)) }
    return .user(result)
}

public func mechagramVisualGramBalance(peerId: PeerId) -> Int64? {
    guard let value = UserDefaults.standard.string(forKey: "mechagram.visual.gram.\(peerId.toInt64())") else { return nil }
    return MechagramVisualProfile.gramNanos(value)
}

public func mechagramVisualRating(peerId: PeerId) -> TelegramStarRating? {
    let prefix = "mechagram.visual.rating.\(peerId.toInt64())."
    let defaults = UserDefaults.standard
    guard MechagramVisualProfile.load(peerId: peerId.toInt64()).enabled,
          let raw = defaults.string(forKey: prefix + "level"),
          let level = MechagramVisualProfile.normalizedRatingNumber(raw, maximum: 1000).flatMap({ Int32($0) }) else { return nil }
    let stars = defaults.string(forKey: prefix + "stars").flatMap({ Int64($0) }) ?? 0
    let next = defaults.string(forKey: prefix + "next").flatMap({ Int64($0) }) ?? 5000
    guard (0...1_000_000_000_000_000).contains(stars), (0...1_000_000_000_000_000).contains(next) else { return nil }
    return TelegramStarRating(level: level, currentLevelStars: 0, stars: stars, nextLevelStars: max(stars + 1, next))
}
