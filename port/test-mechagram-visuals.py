"""Exercise the production visual-profile persistence and input validation."""
from pathlib import Path
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
text = (root / "submodules/TelegramCore/Sources/TelegramEngine/Peers/MechagramVisualProfile.swift").read_text(encoding="utf-8")
policy = text.split("// MECHAGRAM_VISUAL_PROFILE_POLICY_BEGIN\n")[1].split("// MECHAGRAM_VISUAL_PROFILE_POLICY_END")[0]
source = "import Foundation\nimport Dispatch\n" + policy + r'''
assert(MechagramVisualProfile.normalizedPhone("+888 0189 1745") == "88801891745")
assert(MechagramVisualProfile.normalizedPhone("+7 999 123 45 67") == nil)
assert(MechagramVisualProfile.normalizedPhone("888abc1234") == nil)
assert(MechagramVisualProfile.normalizedPhone("+888 ١٢٣٤") == nil)
assert(MechagramVisualProfile.normalizedUsername("@architect") == "architect")
assert(MechagramVisualProfile.normalizedUsername("a") == "a")
assert(MechagramVisualProfile.normalizedUsername("1invalid") == nil)
assert(MechagramVisualProfile.normalizedUsername("bad/name") == nil)
assert(MechagramVisualProfile.normalizedUsername(String(repeating: "a", count: 33)) == nil)
assert(MechagramVisualProfile.normalizedColor("#ff453a") == "FF453A")
assert(MechagramVisualProfile.normalizedColor("GG0000") == nil)
assert(MechagramVisualProfile.normalizedGram("1,234567891") == "1.234567891")
assert(MechagramVisualProfile.gramNanos("1.234567891") == 1_234_567_891)
assert(MechagramVisualProfile.gramNanos("0.000000001") == 1)
assert(MechagramVisualProfile.gramNanos("1000000000") == 1_000_000_000_000_000_000)
assert(MechagramVisualProfile.gramNanos("0") == 0)
assert(MechagramVisualProfile.normalizedGram("1000000001") == nil)
assert(MechagramVisualProfile.normalizedGram("1.0000000001") == nil)
assert(MechagramVisualProfile.normalizedGram("-1") == nil)
assert(MechagramVisualProfile.normalizedGram("nan") == nil)
assert(MechagramVisualProfile.normalizedGram("1e9") == nil)
assert(MechagramVisualProfile.normalizedRatingNumber("1000", maximum: 1000) == "1000")
assert(MechagramVisualProfile.normalizedRatingNumber("1001", maximum: 1000) == nil)
assert(MechagramVisualProfile.normalizedRatingNumber("-1", maximum: 1000) == nil)
assert(MechagramVisualProfile.normalizedRatingNumber("١", maximum: 1000) == nil)
assert(MechagramVisualProfile.normalizedRatingNumber("999999999999999999999", maximum: 1000) == nil)
let name = "mechagram-visual-tests-" + UUID().uuidString
let defaults = UserDefaults(suiteName: name)!
assert(MechagramVisualProfile.gramBalance(peerId: 100, defaults: defaults) == nil)
defaults.set(true, forKey: "mechagram.visualBalances")
defaults.set("42.000000001", forKey: "mechagram.visualTON")
assert(MechagramVisualProfile.gramBalance(peerId: 100, defaults: defaults) == 42_000_000_001)
defaults.set("7.5", forKey: "mechagram.visual.gram.100")
assert(MechagramVisualProfile.gramBalance(peerId: 100, defaults: defaults) == 7_500_000_000)
assert(MechagramVisualProfile.gramBalance(peerId: 200, defaults: defaults) == 42_000_000_001)
defaults.set(false, forKey: "mechagram.visualBalances")
assert(MechagramVisualProfile.gramBalance(peerId: 200, defaults: defaults) == nil)
assert(MechagramVisualProfile.gramBalance(peerId: 100, defaults: defaults) == 7_500_000_000)
defaults.removeObject(forKey: "mechagram.visual.gram.100")
assert(MechagramVisualProfile.gramBalance(peerId: 100, defaults: defaults) == nil)
var wallpaper = MechagramVisualProfile()
assert(!wallpaper.hasWallpaper)
wallpaper.backgroundImage = "/local/wallpaper.jpg"
assert(wallpaper.hasWallpaper)
wallpaper.enabled = false
assert(!wallpaper.hasWallpaper)
wallpaper.enabled = true
wallpaper.backgroundImage = ""
wallpaper.profileColor = "FF0000"
assert(wallpaper.hasWallpaper)
var profile = MechagramVisualProfile()
profile.anonymousPhone = "88801891745"
profile.collectibleUsername = "architect"
profile.verified = true
profile.nicknameFont = "serif"
profile.frameShape = "hex"
profile.framePreset = "beads"
profile.frameColor = "FF453A"
profile.backgroundImage = "/local/profile.jpg"
profile.save(peerId: 100, defaults: defaults)
assert(MechagramVisualProfile.load(peerId: 100, defaults: defaults) == profile)
assert(MechagramVisualProfile.load(peerId: 200, defaults: defaults) == MechagramVisualProfile())
let reopened = UserDefaults(suiteName: name)!
assert(MechagramVisualProfile.load(peerId: 100, defaults: reopened) == profile)
profile.enabled = false
profile.save(peerId: 100, defaults: defaults)
assert(!MechagramVisualProfile.load(peerId: 100, defaults: defaults).enabled)
MechagramVisualProfile().save(peerId: 100, defaults: defaults)
assert(MechagramVisualProfile.load(peerId: 100, defaults: defaults) == MechagramVisualProfile())
defaults.set(Data("broken".utf8), forKey: "mechagram.visual.profile.v1.100")
assert(MechagramVisualProfile.load(peerId: 100, defaults: defaults) == MechagramVisualProfile())
defaults.removePersistentDomain(forName: name)
print("Mechagram: 43 visual profile validation, isolation, persistence and reset assertions passed")
'''
with tempfile.TemporaryDirectory() as directory:
    path = Path(directory) / "main.swift"
    executable = Path(directory) / "visual-tests"
    path.write_text(source, encoding="utf-8")
    subprocess.run(["xcrun", "swiftc", "-Onone", str(path), "-o", str(executable)], check=True, timeout=120)
    subprocess.run([str(executable)], check=True, timeout=20)
