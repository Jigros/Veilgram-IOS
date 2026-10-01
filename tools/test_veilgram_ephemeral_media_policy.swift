import Foundation

@main
enum VeilgramEphemeralMediaPolicyTests {
    static func main() throws {
        var checks = 0

        func expect(_ value: @autoclosure () -> Bool, _ message: String) {
            precondition(value(), message)
            checks += 1
        }

        let tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("veilgram-ephemeral-tests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        let store = VeilgramProtectedLocalStore(rootURL: tempRoot)
        let coordinator = VeilgramEphemeralMediaArchiveCoordinator(store: store)
        let bytes = Data("fixture".utf8)

        let synthetic = VeilgramEphemeralMediaDescriptor(origin: .syntheticFixture, isEphemeral: true)
        let outgoingSelfTest = VeilgramEphemeralMediaDescriptor(origin: .outgoingSelfTest, isEphemeral: true)
        let incoming = VeilgramEphemeralMediaDescriptor(origin: .incomingViewOnce, isEphemeral: true)
        let secret = VeilgramEphemeralMediaDescriptor(origin: .secretMedia, isEphemeral: true)
        let copyProtected = VeilgramEphemeralMediaDescriptor(origin: .copyProtected, isEphemeral: true)
        let paid = VeilgramEphemeralMediaDescriptor(origin: .paidContent, isEphemeral: true)
        let regular = VeilgramEphemeralMediaDescriptor(origin: .regularTelegramMedia, isEphemeral: false)

        expect(VeilgramEphemeralMediaPolicy.isFeatureEnabled == false, "production kill switch must stay off")
        expect(VeilgramEphemeralMediaPolicy.evaluate(synthetic) == .featureDisabled, "synthetic fixture should be disabled in production")
        expect(VeilgramEphemeralMediaPolicy.evaluate(outgoingSelfTest) == .featureDisabled, "outgoing self-test should be disabled in production")
        expect(VeilgramEphemeralMediaPolicy.evaluate(incoming) == .deniedProtectedIncoming, "incoming view-once must be denied")
        expect(VeilgramEphemeralMediaPolicy.evaluate(secret) == .deniedProtectedIncoming, "secret media must be denied")
        expect(VeilgramEphemeralMediaPolicy.evaluate(copyProtected) == .deniedProtectedIncoming, "copy-protected media must be denied")
        expect(VeilgramEphemeralMediaPolicy.evaluate(paid) == .deniedProtectedIncoming, "paid media must be denied")
        expect(VeilgramEphemeralMediaPolicy.evaluate(regular) == .notEphemeral, "regular media should not enter ephemeral archive")

        let disabledOutcome = try coordinator.archive(bytes, fileName: "disabled.bin", descriptor: synthetic)
        expect(disabledOutcome == .featureDisabled, "production archive should remain disabled")
        expect(!(try store.fileExists(fileName: "disabled.bin")), "disabled path wrote a file")

        let syntheticOutcome = try coordinator.archiveForTesting(
            bytes,
            fileName: "synthetic.bin",
            descriptor: synthetic,
            enabled: true
        )
        expect(syntheticOutcome == .storedForTestHarness, "synthetic fixture did not store in test mode")
        expect(try store.fileExists(fileName: "synthetic.bin"), "synthetic test file missing")

        let selfTestOutcome = try coordinator.archiveForTesting(
            bytes,
            fileName: "self-test.bin",
            descriptor: outgoingSelfTest,
            enabled: true
        )
        expect(selfTestOutcome == .storedForTestHarness, "outgoing self-test did not store in test mode")
        expect(try store.fileExists(fileName: "self-test.bin"), "self-test file missing")

        for (name, descriptor) in [
            ("incoming.bin", incoming),
            ("secret.bin", secret),
            ("copy.bin", copyProtected),
            ("paid.bin", paid)
        ] {
            let outcome = try coordinator.archiveForTesting(bytes, fileName: name, descriptor: descriptor, enabled: true)
            expect(outcome == .deniedProtectedIncoming, "\(name) unexpectedly authorized")
            expect(!(try store.fileExists(fileName: name)), "\(name) unexpectedly persisted")
        }

        print("PASS: \(checks) ephemeral-media policy checks")
    }
}
