import Foundation
import Postbox
import MtProtoKit

// MECHAGRAM_CUSTOM_SERVER_POLICY_BEGIN
let mechagramDefaultCustomServerIP = "177.3.213.27"
let mechagramDefaultCustomServerRSA = """
-----BEGIN RSA PUBLIC KEY-----
MIIBCgKCAQEA51YKn8z7Ajz8P7P4fppIsVe/KSL787NZYXC56A/ECWLzIBwLkQfe
dL8KgMDYTWek7RC66hDfvTEf5N6Rv2RlXt3wZ/xmR16K9TKu8qO3x5UkAFdLzniZ
jnj17rsH/1L9cv/ktDp91GaeF5MPqrFY3sopue7icVtwa2f5J8THTQs5Fw0GYooE
FmmVwg7eTs8clpZKya3SyigSmJTfCTYInPIoRE8u7XCzM9CQ6PS4/x6HADTIIcDy
mYypda3Lj8BsrT+z2gxDzS70CO/NaLGh8C/mIMD0MBp/q/GiE3MAhIFW1vOq64/Y
I/c9Ylh22m6i8glsqa1DxgTDvVCdzjg2ZQIDAQAB
-----END RSA PUBLIC KEY-----
"""

func mechagramCustomServerSelection(defaults: UserDefaults = .standard) -> [String: String] {
    let host = (defaults.string(forKey: "mechagram.customServer.ip") ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    guard !host.isEmpty else { return [:] }
    let rawPort = (defaults.string(forKey: "mechagram.customServer.port") ?? "443").trimmingCharacters(in: .whitespacesAndNewlines)
    guard let port = UInt16(rawPort), port > 0 else { return [:] }
    let rawRSA = (defaults.string(forKey: "mechagram.customServer.rsa") ?? "").replacingOccurrences(of: "\\n", with: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    let rsa = rawRSA.isEmpty && host == mechagramDefaultCustomServerIP ? mechagramDefaultCustomServerRSA : rawRSA
    guard rsa.contains("-----BEGIN "), rsa.contains("PUBLIC KEY-----"), rsa.contains("-----END ") else { return [:] }
    return ["ip": host, "port": String(port), "rsa": rsa, "name": defaults.string(forKey: "mechagram.customServer.name") ?? "Custom Server"]
}
func mechagramServerAccountKey(_ id: AccountRecordId) -> String {
    return "mechagram.accountServer.v1.\(id.int64)"
}

func mechagramBindServerSelection(accountId: AccountRecordId, defaults: UserDefaults = .standard) {
    let key = mechagramServerAccountKey(accountId)
    if defaults.dictionary(forKey: key) == nil {
        defaults.set(mechagramCustomServerSelection(defaults: defaults), forKey: key)
    }
}
// MECHAGRAM_CUSTOM_SERVER_POLICY_END

func mechagramConfigureCustomServer(context: MTContext, configuration: [String: String]) {
    guard let host = configuration["ip"], let rawPort = configuration["port"], let port = UInt16(rawPort), port > 0, let rsa = configuration["rsa"] else {
        context.mechagramCustomPublicKey = nil
        context.mechagramCustomAddressSet = nil
        return
    }
    var ports = [port]
    if host == mechagramDefaultCustomServerIP {
        let fallback: UInt16 = port == 443 ? 2398 : 443
        if !ports.contains(fallback) { ports.append(fallback) }
    }
    context.mechagramCustomPublicKey = rsa
    context.mechagramCustomAddressSet = MTDatacenterAddressSet(addressList: ports.map { MTDatacenterAddress(ip: host, port: $0, preferForMedia: false, restrictToTcp: true, cdn: false, preferForProxy: false, secret: nil) })
}

public func mechagramApplyCustomServer(network: Network) {
    // Only login controllers may switch an unauthenticated network. Authorized
    // accounts retain the configuration bound to their own AccountRecordId.
    guard network.mechagramCanSelectServer else { return }
    let configuration = mechagramCustomServerSelection()
    let previous = network.context.mechagramCustomPublicKey
    let previousAddress = network.context.mechagramCustomAddressSet
    mechagramConfigureCustomServer(context: network.context, configuration: configuration)
    if let key = network.context.mechagramServerAccountKey { UserDefaults.standard.set(configuration, forKey: key) }
    let oldAddress = previousAddress?.addressList.first as? MTDatacenterAddress
    let newAddress = network.context.mechagramCustomAddressSet?.addressList.first as? MTDatacenterAddress
    if previous != network.context.mechagramCustomPublicKey || oldAddress?.ip != newAddress?.ip || oldAddress?.port != newAddress?.port {
        network.context.performBatchUpdates {
            if previousAddress != nil && newAddress == nil {
                let official: [Int: [String]] = network.context.isTestingEnvironment
                    ? [1: ["149.154.175.10"], 2: ["149.154.167.40"], 3: ["149.154.175.117"]]
                    : [1: ["149.154.175.50"], 2: ["149.154.167.50", "95.161.76.100"], 3: ["149.154.175.100"], 4: ["149.154.167.91"], 5: ["149.154.171.5"]]
                for (id, hosts) in official {
                    let addresses = hosts.map { MTDatacenterAddress(ip: $0, port: 443, preferForMedia: false, restrictToTcp: false, cdn: false, preferForProxy: false, secret: nil) }
                    network.context.updateAddressSetForDatacenter(withId: id, addressSet: MTDatacenterAddressSet(addressList: addresses), forceUpdateSchemes: true)
                }
            }
            for id in 1...5 {
                network.context.updateAuthInfoForDatacenter(withId: id, authInfo: nil, selector: .persistent)
                network.context.updateAuthInfoForDatacenter(withId: id, authInfo: nil, selector: .ephemeralMain)
            }
            network.context.invalidateTransportSchemesForKnownDatacenterIds()
        }
    }
}
