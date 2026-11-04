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
