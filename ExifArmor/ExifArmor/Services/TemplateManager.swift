import Foundation
import Observation

@Observable
final class TemplateManager {
    private let defaults = UserDefaults.standard
    private let storageKey = "customStripTemplates_v1"

    private(set) var customTemplates: [StripTemplate] = []

    var allTemplates: [StripTemplate] {
        StripTemplate.builtIns + customTemplates
    }

    var canAddMore: Bool {
        customTemplates.count < StripTemplate.maxCustomTemplates
    }

    init() {
        load()
    }

    func save(template: StripTemplate) {
        guard !template.isBuiltIn else { return }

        if let index = customTemplates.firstIndex(where: { $0.id == template.id }) {
            customTemplates[index] = template
        } else if canAddMore {
            customTemplates.append(template)
        }

        persist()
    }

    func delete(_ template: StripTemplate) {
        guard !template.isBuiltIn else { return }
        customTemplates.removeAll { $0.id == template.id }
        persist()
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(customTemplates) {
            defaults.set(data, forKey: storageKey)
        }
    }

    private func load() {
        guard let data = defaults.data(forKey: storageKey),
              let saved = try? JSONDecoder().decode([StripTemplate].self, from: data)
        else {
            return
        }

        customTemplates = saved
    }
}
