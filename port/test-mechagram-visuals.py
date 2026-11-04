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
let name = "mechagram-visual-tests-" + UUID().uuidString
let defaults = UserDefaults(suiteName: name)!
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
print("Mechagram: 17 visual profile validation, isolation, persistence and reset assertions passed")
'''
with tempfile.TemporaryDirectory() as directory:
    path = Path(directory) / "main.swift"
    executable = Path(directory) / "visual-tests"
    path.write_text(source, encoding="utf-8")
    subprocess.run(["xcrun", "swiftc", "-Onone", str(path), "-o", str(executable)], check=True, timeout=120)
    subprocess.run([str(executable)], check=True, timeout=20)
