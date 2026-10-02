import Foundation

enum VeilgramProtectedStoreError: Error, Equatable {
    case invalidFileName
    case payloadTooLarge
    case missingApplicationSupportDirectory
}

/// Small account-scoped store for Veilgram-owned local documents.
///
/// It never stores Telegram auth/session material. Callers own their schema and
/// privacy eligibility checks. Files are written atomically, directories are
/// mode 0700 and files mode 0600; iOS additionally receives complete file
/// protection while the device is locked.
struct VeilgramProtectedLocalStore {
    static let maximumFileBytes = 48 * 1024 * 1024

    let rootURL: URL

    static func accountStore(accountId: Int64) throws -> VeilgramProtectedLocalStore {
        guard let applicationSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else {
            throw VeilgramProtectedStoreError.missingApplicationSupportDirectory
        }
        return VeilgramProtectedLocalStore(
            rootURL: applicationSupport
                .appendingPathComponent("Veilgram", isDirectory: true)
                .appendingPathComponent("Accounts", isDirectory: true)
                .appendingPathComponent(String(accountId), isDirectory: true)
        )
    }

    func write(_ data: Data, fileName: String) throws {
        guard data.count <= Self.maximumFileBytes else {
            throw VeilgramProtectedStoreError.payloadTooLarge
        }
        let fileURL = try url(for: fileName)
        try ensureDirectory()

        try data.write(to: fileURL, options: [.atomic])
        try applyProtection(to: fileURL)
    }

    func read(fileName: String) throws -> Data? {
        let fileURL = try url(for: fileName)
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return nil
        }
        let values = try fileURL.resourceValues(forKeys: [.fileSizeKey])
        if let fileSize = values.fileSize, fileSize > Self.maximumFileBytes {
            throw VeilgramProtectedStoreError.payloadTooLarge
        }
        let data = try Data(contentsOf: fileURL, options: [.mappedIfSafe])
        guard data.count <= Self.maximumFileBytes else {
            throw VeilgramProtectedStoreError.payloadTooLarge
        }
        return data
    }

    func copyFile(
        from sourceURL: URL,
        fileName: String,
        maximumBytes: Int64
    ) throws -> Int64 {
        let destinationURL = try url(for: fileName)
        try ensureDirectory()

        let values = try sourceURL.resourceValues(forKeys: [
            .isRegularFileKey,
            .fileSizeKey
        ])
        guard values.isRegularFile == true else {
            throw VeilgramProtectedStoreError.invalidFileName
        }
        let byteCount = Int64(values.fileSize ?? 0)
        guard byteCount >= 0, byteCount <= maximumBytes else {
            throw VeilgramProtectedStoreError.payloadTooLarge
        }

        let temporaryName = ".\(fileName).tmp"
        let temporaryURL = try url(for: temporaryName)
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: temporaryURL.path) {
            try fileManager.removeItem(at: temporaryURL)
        }
        try fileManager.copyItem(at: sourceURL, to: temporaryURL)
        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }
        try fileManager.moveItem(at: temporaryURL, to: destinationURL)

        try applyProtection(to: destinationURL)
        return byteCount
    }

    func removeFiles(withPrefix prefix: String) throws {
        guard Self.isSafeFileName(prefix) else {
            throw VeilgramProtectedStoreError.invalidFileName
        }
        guard FileManager.default.fileExists(atPath: rootURL.path) else {
            return
        }
        let contents = try FileManager.default.contentsOfDirectory(
            at: rootURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )
        for url in contents where url.lastPathComponent.hasPrefix(prefix) {
            try FileManager.default.removeItem(at: url)
        }
    }

    func remove(fileName: String) throws {
        let fileURL = try url(for: fileName)
        if FileManager.default.fileExists(atPath: fileURL.path) {
            try FileManager.default.removeItem(at: fileURL)
        }
    }

    func fileExists(fileName: String) throws -> Bool {
        let fileURL = try url(for: fileName)
        return FileManager.default.fileExists(atPath: fileURL.path)
    }

    func existingFileURL(fileName: String) throws -> URL? {
        let fileURL = try url(for: fileName)
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return nil
        }
        let values = try fileURL.resourceValues(forKeys: [.isRegularFileKey])
        guard values.isRegularFile == true else {
            return nil
        }
        return fileURL
    }

    private func applyProtection(to fileURL: URL) throws {
        try FileManager.default.setAttributes(
            [.posixPermissions: NSNumber(value: 0o600)],
            ofItemAtPath: fileURL.path
        )
        var fileResourceValues = URLResourceValues()
        fileResourceValues.isExcludedFromBackup = true
        var mutableFileURL = fileURL
        try mutableFileURL.setResourceValues(fileResourceValues)

        #if os(iOS)
        try FileManager.default.setAttributes(
            [.protectionKey: FileProtectionType.complete],
            ofItemAtPath: fileURL.path
        )
        #endif
    }

    private func ensureDirectory() throws {
        try FileManager.default.createDirectory(
            at: rootURL,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: NSNumber(value: 0o700)]
        )
        try FileManager.default.setAttributes(
            [.posixPermissions: NSNumber(value: 0o700)],
            ofItemAtPath: rootURL.path
        )
        var directoryResourceValues = URLResourceValues()
        directoryResourceValues.isExcludedFromBackup = true
        var mutableRootURL = rootURL
        try mutableRootURL.setResourceValues(directoryResourceValues)

        #if os(iOS)
        try FileManager.default.setAttributes(
            [.protectionKey: FileProtectionType.complete],
            ofItemAtPath: rootURL.path
        )
        #endif
    }

    private func url(for fileName: String) throws -> URL {
        guard Self.isSafeFileName(fileName) else {
            throw VeilgramProtectedStoreError.invalidFileName
        }
        return rootURL.appendingPathComponent(fileName, isDirectory: false)
    }

    static func isSafeFileName(_ value: String) -> Bool {
        guard !value.isEmpty, value.count <= 80 else {
            return false
        }
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._-")
        guard value.unicodeScalars.allSatisfy({ allowed.contains($0) }) else {
            return false
        }
        return value != "." && value != ".." && !value.contains("..")
    }
}
