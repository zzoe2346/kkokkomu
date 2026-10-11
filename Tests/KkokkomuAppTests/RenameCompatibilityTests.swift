import Foundation
import Testing

@testable import KkokkomuApp

@Test @MainActor func renamedAppKeepsExistingLibraryAndDefaultsIdentity() throws {
    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent()
    let info = try #require(
        PropertyListSerialization.propertyList(
            from: Data(contentsOf: root.appendingPathComponent("AppResources/Info.plist")),
            format: nil) as? [String: Any])
    // This identifier selects the existing production UserDefaults domain.
    #expect(info["CFBundleIdentifier"] as? String == "com.zzoe.tail")
    #expect(info["CFBundleName"] as? String == "꼬꼬무")
    #expect(info["CFBundleDisplayName"] as? String == "꼬꼬무")
    #expect(info["CFBundleExecutable"] as? String == "Kkokkomu")

    // Constructing the store does not open or write the user's real library.
    let store = StudyStore()
    let existing = try #require(
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
    ).appendingPathComponent("Tail")
    #expect(store.dataDirectory == existing)
}
