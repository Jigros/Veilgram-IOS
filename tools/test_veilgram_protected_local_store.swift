import Foundation

@main
enum VeilgramProtectedLocalStoreTests {
    static func main() throws {
        var checks = 0
        func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
            precondition(condition(), message)
            checks += 1
        }

        let base = FileManager.default.temporaryDirectory
            .appendingPathComponent("veilgram-store-tests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: base) }

        let store = VeilgramProtectedLocalStore(rootURL: base)
        expect(VeilgramProtectedLocalStore.isSafeFileName("filters-v1.json"), "valid name rejected")
        expect(!VeilgramProtectedLocalStore.isSafeFileName("../secret"), "traversal name accepted")
        expect(!VeilgramProtectedLocalStore.isSafeFileName("a/b"), "slash name accepted")
        expect(!VeilgramProtectedLocalStore.isSafeFileName(".."), "dot-dot accepted")

        let payload = Data("hello".utf8)
        try store.write(payload, fileName: "archive.json")
        expect(try store.fileExists(fileName: "archive.json"), "written file missing")
        expect(try store.read(fileName: "archive.json") == payload, "read payload mismatch")

        let rootAttrs = try FileManager.default.attributesOfItem(atPath: base.path)
        let rootMode = (rootAttrs[.posixPermissions] as? NSNumber)?.intValue
        expect(rootMode == 0o700, "directory permissions are not 0700")

        let fileURL = base.appendingPathComponent("archive.json")
        let fileAttrs = try FileManager.default.attributesOfItem(atPath: fileURL.path)
        let fileMode = (fileAttrs[.posixPermissions] as? NSNumber)?.intValue
        expect(fileMode == 0o600, "file permissions are not 0600")

        try store.write(Data("updated".utf8), fileName: "archive.json")
        expect(try store.read(fileName: "archive.json") == Data("updated".utf8), "atomic replacement mismatch")

        try store.remove(fileName: "archive.json")
        expect(!(try store.fileExists(fileName: "archive.json")), "remove failed")
        expect(try store.read(fileName: "archive.json") == nil, "missing read should return nil")

        do {
            try store.write(payload, fileName: "../escape")
            preconditionFailure("unsafe path write accepted")
        } catch VeilgramProtectedStoreError.invalidFileName {
            checks += 1
        }

        print("PASS: \(checks) protected local-store checks")
    }
}
