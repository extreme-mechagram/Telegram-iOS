"""Run the production transaction-store and server-selection code with host Swift."""
from pathlib import Path
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
source = r'''
import Foundation
import Dispatch
public struct PeerId { let value: Int64; func toInt64() -> Int64 { value } }
public struct AccountRecordId { let int64: Int64 }
public struct MechagramLocalStarTransaction: Codable { let id: String }
'''
for file, marker in [
    ("submodules/TelegramCore/Sources/TelegramEngine/Payments/StarGifts.swift", "TRANSACTION_STORE"),
    ("submodules/TelegramCore/Sources/Network/MechagramCustomServer.swift", "CUSTOM_SERVER"),
]:
    text = (root / file).read_text()
    source += text.split(f"// MECHAGRAM_{marker}_POLICY_BEGIN\n")[1].split(f"// MECHAGRAM_{marker}_POLICY_END")[0]
source += r'''
let account = PeerId(value: Int64.random(in: 1 ... Int64.max))
let otherAccount = PeerId(value: account.value == 1 ? 2 : 1)
assert(mechagramReadLocalTransactions(accountId: account).isEmpty)
let observer = NotificationCenter.default.addObserver(forName: Notification.Name("MechagramLocalTransactionsChanged"), object: nil, queue: nil) { _ in
    // A synchronous observer must be able to read after each committed write.
    assert(!mechagramReadLocalTransactions(accountId: account).isEmpty)
}
mechagramRecordLocalTransaction(accountId: account, transaction: .init(id: "first"))
assert(mechagramReadLocalTransactions(accountId: account).map { $0.id } == ["first"])
DispatchQueue.concurrentPerform(iterations: 32) { index in
    mechagramRecordLocalTransaction(accountId: account, transaction: .init(id: String(index)))
}
let history = mechagramReadLocalTransactions(accountId: account)
assert(history.count == 33)
assert(Set(history.map { $0.id }).count == 33)
assert(mechagramReadLocalTransactions(accountId: otherAccount).isEmpty)
NotificationCenter.default.removeObserver(observer)
UserDefaults.standard.removeObject(forKey: "mechagram.localTransactions.v1.\(account.value)")
let name = "mechagram-server-tests-" + UUID().uuidString
let defaults = UserDefaults(suiteName: name)!
assert(mechagramCustomServerSelection(defaults: defaults).isEmpty)
defaults.set(mechagramDefaultCustomServerIP, forKey: "mechagram.customServer.ip")
assert(mechagramCustomServerSelection(defaults: defaults)["rsa"] == mechagramDefaultCustomServerRSA)
let customAccount = AccountRecordId(int64: 1)
let officialAccount = AccountRecordId(int64: 2)
mechagramBindServerSelection(accountId: customAccount, defaults: defaults)
defaults.removeObject(forKey: "mechagram.customServer.ip")
mechagramBindServerSelection(accountId: officialAccount, defaults: defaults)
mechagramBindServerSelection(accountId: customAccount, defaults: defaults)
assert((defaults.dictionary(forKey: mechagramServerAccountKey(customAccount))?["ip"] as? String) == mechagramDefaultCustomServerIP)
assert(defaults.dictionary(forKey: mechagramServerAccountKey(officialAccount))?.isEmpty == true)
defaults.set(mechagramDefaultCustomServerIP, forKey: "mechagram.customServer.ip")
assert(mechagramCustomServerSelection(defaults: defaults)["port"] == "443")
defaults.set("2398", forKey: "mechagram.customServer.port")
assert(mechagramCustomServerSelection(defaults: defaults)["port"] == "2398")
defaults.set("0", forKey: "mechagram.customServer.port")
assert(mechagramCustomServerSelection(defaults: defaults).isEmpty)
defaults.set("65536", forKey: "mechagram.customServer.port")
assert(mechagramCustomServerSelection(defaults: defaults).isEmpty)
defaults.set("443", forKey: "mechagram.customServer.port")
defaults.set("192.0.2.1", forKey: "mechagram.customServer.ip")
assert(mechagramCustomServerSelection(defaults: defaults).isEmpty)
defaults.set(mechagramDefaultCustomServerRSA.replacingOccurrences(of: "\n", with: "\\n"), forKey: "mechagram.customServer.rsa")
assert(mechagramCustomServerSelection(defaults: defaults)["rsa"] == mechagramDefaultCustomServerRSA)
defaults.removePersistentDomain(forName: name)
print("Mechagram: transaction deadlock, observer reentry, concurrent writes, account isolation and server selection regressions passed")
'''
with tempfile.TemporaryDirectory() as directory:
    path = Path(directory) / "main.swift"
    executable = Path(directory) / "regression-tests"
    path.write_text(source)
    subprocess.run(["xcrun", "swiftc", "-Onone", str(path), "-o", str(executable)], check=True, timeout=120)
    # The previous nested NSLock implementation hangs here, rather than failing
    # an assertion. Keep that regression bounded and visible in CI.
    subprocess.run([str(executable)], check=True, timeout=20)
