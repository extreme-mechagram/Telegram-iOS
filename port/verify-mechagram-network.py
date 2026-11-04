"""Verify the official network fallback after removing only the custom branch."""
import hashlib
import re
from pathlib import Path

root = Path(__file__).resolve().parents[1]
checks = {
    "submodules/TelegramCore/Sources/Network/Network.swift": "7a8db1d8722fe803f8166be1643ecd48afd5f3d7",
    "submodules/MtProtoKit/Sources/MTContext.m": "91d362c64f8a027c24cf38e7413621fda5d030e9",
    "submodules/MtProtoKit/Sources/MTDatacenterAuthMessageService.m": "7684c21b790c9eee1799528bc94782a5877aad2d",
}
for name, expected in checks.items():
    text = (root / name).read_text()
    if name.endswith("Network.swift"):
        text = re.sub(r"            // MECHAGRAM_NETWORK_(BINDING|RESET|ENGINE)_BEGIN\n.*?            // MECHAGRAM_NETWORK_\1_END\n", "", text, flags=re.S)
        text = text.replace("    public var mechagramCanSelectServer = false\n", "")
    elif name.endswith("MTContext.m"):
        branch = "    if (self.mechagramCustomAddressSet != nil && datacenterId >= 1 && datacenterId <= 5) {\n        return self.mechagramCustomAddressSet;\n    }\n"
        assert text.count(branch) == 1
        text = text.replace(branch, "")
        text = text.replace("MTDatacenterAddressSet *seedAddress = (self.mechagramCustomAddressSet != nil && datacenterId >= 1 && datacenterId <= 5) ? self.mechagramCustomAddressSet : _datacenterSeedAddressSetById[@(datacenterId)];", "MTDatacenterAddressSet *seedAddress = _datacenterSeedAddressSetById[@(datacenterId)];")
    else:
        branch = "    if (!mtProto.cdn && mtProto.context.mechagramCustomPublicKey.length != 0) {\n        _publicKeys = @[[[MTDatacenterAuthPublicKey alloc] initWithPublicKey:mtProto.context.mechagramCustomPublicKey]];\n        _stage = MTDatacenterAuthStagePQ;\n    } else if (mtProto.cdn) {"
        assert text.count(branch) == 1
        text = text.replace(branch, "    if (mtProto.cdn) {")
    data = text.encode()
    actual = hashlib.sha1(b"blob " + str(len(data)).encode() + b"\0" + data).hexdigest()
    assert actual == expected, (name, actual, expected)
print("Official endpoints, RSA keys and authentication fallback match the verified upstream files")
