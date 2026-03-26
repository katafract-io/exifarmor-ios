import Foundation

struct StripTemplate: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String
    var options: StripOptions
    var isBuiltIn: Bool = false

    static let builtIns: [StripTemplate] = [
        StripTemplate(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            name: "Full Strip",
            options: .all,
            isBuiltIn: true
        ),
        StripTemplate(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
            name: "Location Only",
            options: .locationOnly,
            isBuiltIn: true
        ),
        StripTemplate(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!,
            name: "Privacy Focused",
            options: .privacyFocused,
            isBuiltIn: true
        ),
    ]

    static let maxCustomTemplates = 5
}
