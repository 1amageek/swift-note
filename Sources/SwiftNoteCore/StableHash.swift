import Foundation

public enum StableHash {
    public static func hex(_ value: String) -> String {
        hexBytes(value.utf8)
    }

    public static func hex(_ data: Data) -> String {
        hexBytes(data)
    }

    private static func hexBytes<Bytes: Sequence>(_ bytes: Bytes) -> String where Bytes.Element == UInt8 {
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in bytes {
            hash ^= UInt64(byte)
            hash = hash &* 1_099_511_628_211
        }
        return String(hash, radix: 16)
    }
}
