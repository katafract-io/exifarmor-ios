import SwiftUI

struct StripOptionsSheet: View {
    @Binding var options: StripOptions
    let onConfirm: () -> Void

    @Environment(StoreManager.self) private var store
    @Environment(TemplateManager.self) private var templateManager
    @State private var selectedTemplateID: UUID?
    @State private var isCustomizing = false
    @State private var showSaveTemplateAlert = false
    @State private var templateName = ""
    @State private var saveErrorMessage: String?

    var body: some View {
        NavigationStack {
            List {
                Section("Templates") {
                    LazyVStack(spacing: 10) {
                        ForEach(templateManager.allTemplates) { template in
                            Button {
                                selectedTemplateID = template.id
                                isCustomizing = false
                                options = template.options
                            } label: {
                                HStack(spacing: 12) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(template.name)
                                            .foregroundStyle(Color("TextPrimary"))
                                        Text(templateDescription(template))
                                            .font(.caption)
                                            .foregroundStyle(Color("TextSecondary"))
                                            .multilineTextAlignment(.leading)
                                    }

                                    Spacer()

                                    if selectedTemplateID == template.id && !isCustomizing {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(Color("AccentCyan"))
                                    }
                                }
                                .padding(12)
                                .background(Color("CardBackground"))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))

                    Button("Customize") {
                        isCustomizing = true
                        selectedTemplateID = nil
                    }
                    .foregroundStyle(Color("AccentCyan"))
                }

                if selectedTemplateID == nil || isCustomizing {
                    Section {
                        Toggle(isOn: $options.includeVideos) {
                            Label("Include Videos", systemImage: "video.fill")
                        }
                        .tint(Color("AccentCyan"))

                        Toggle(isOn: $options.removeAll) {
                            Label("Remove Everything", systemImage: "trash.fill")
                        }
                        .tint(Color("AccentCyan"))
                        .onChange(of: options.removeAll) { _, newValue in
                            isCustomizing = true
                            selectedTemplateID = nil
                            if newValue {
                                options.removeLocation = true
                                options.removeDateTime = true
                                options.removeDeviceInfo = true
                                options.removeCameraSettings = true
                            }
                        }
                    } footer: {
                        Text("Removes all metadata except image orientation.")
                    }

                    if !options.removeAll {
                        Section("Choose What to Remove") {
                            Toggle(isOn: $options.removeLocation) {
                                Label {
                                    VStack(alignment: .leading) {
                                        Text("GPS Location")
                                        Text("Coordinates, altitude")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                } icon: {
                                    Image(systemName: "location.fill")
                                        .foregroundStyle(Color("WarningRed"))
                                }
                            }
                            .tint(Color("AccentCyan"))
                            .onChange(of: options.removeLocation) { _, _ in markCustomized() }

                            Toggle(isOn: $options.removeDateTime) {
                                Label {
                                    VStack(alignment: .leading) {
                                        Text("Date & Time")
                                        Text("When the photo was taken")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                } icon: {
                                    Image(systemName: "clock.fill")
                                        .foregroundStyle(Color("AccentGold"))
                                }
                            }
                            .tint(Color("AccentCyan"))
                            .onChange(of: options.removeDateTime) { _, _ in markCustomized() }

                            Toggle(isOn: $options.removeDeviceInfo) {
                                Label {
                                    VStack(alignment: .leading) {
                                        Text("Device Info")
                                        Text("Phone model, OS version")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                } icon: {
                                    Image(systemName: "iphone")
                                        .foregroundStyle(Color("AccentMagenta"))
                                }
                            }
                            .tint(Color("AccentCyan"))
                            .onChange(of: options.removeDeviceInfo) { _, _ in markCustomized() }

                            Toggle(isOn: $options.removeCameraSettings) {
                                Label {
                                    VStack(alignment: .leading) {
                                        Text("Camera Settings")
                                        Text("Lens, aperture, ISO, shutter speed")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                } icon: {
                                    Image(systemName: "camera.fill")
                                        .foregroundStyle(Color("AccentCyan"))
                                }
                            }
                            .tint(Color("AccentCyan"))
                            .onChange(of: options.removeCameraSettings) { _, _ in markCustomized() }
                        }
                    }
                }

                Section {
                    if store.isPro {
                        Button("Save as Template") {
                            guard templateManager.canAddMore else {
                                saveErrorMessage = "You've reached the 5 custom template limit."
                                return
                            }
                            templateName = ""
                            showSaveTemplateAlert = true
                        }
                        .foregroundStyle(optionsMatchExistingTemplate ? Color("TextSecondary") : Color("AccentCyan"))
                        .disabled(optionsMatchExistingTemplate)
                    } else {
                        NavigationLink {
                            ProUpgradeView()
                        } label: {
                            HStack {
                                Image(systemName: "star.fill")
                                    .foregroundStyle(Color("AccentGold"))
                                Text("Upgrade to Pro to save templates")
                                    .foregroundStyle(Color("TextPrimary"))
                            }
                        }
                    }
                }
            }
            .navigationTitle("Strip Options")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Strip", action: onConfirm)
                        .bold()
                }
            }
            .onAppear {
                selectedTemplateID = templateManager.allTemplates.first(where: { $0.options == options })?.id
            }
            .alert("Save as Template", isPresented: $showSaveTemplateAlert) {
                TextField("Template Name", text: $templateName)
                Button("Cancel", role: .cancel) {}
                Button("Save") {
                    let trimmedName = templateName.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmedName.isEmpty else { return }
                    templateManager.save(template: StripTemplate(name: trimmedName, options: options))
                    selectedTemplateID = templateManager.customTemplates.last(where: { $0.name == trimmedName && $0.options == options })?.id
                    isCustomizing = false
                }
            } message: {
                Text("Create a reusable strip profile for these options.")
            }
            .alert("Templates", isPresented: Binding(
                get: { saveErrorMessage != nil },
                set: { if !$0 { saveErrorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(saveErrorMessage ?? "")
            }
        }
    }

    private var optionsMatchExistingTemplate: Bool {
        templateManager.allTemplates.contains { $0.options == options }
    }

    private func templateDescription(_ template: StripTemplate) -> String {
        if template.options.removeAll {
            return "Removes all metadata while preserving orientation."
        }

        var parts: [String] = []
        if template.options.removeLocation { parts.append("location") }
        if template.options.removeDateTime { parts.append("date/time") }
        if template.options.removeDeviceInfo { parts.append("device info") }
        if template.options.removeCameraSettings { parts.append("camera settings") }

        return parts.isEmpty ? "No metadata categories selected." : "Removes " + parts.joined(separator: ", ") + "."
    }

    private func markCustomized() {
        isCustomizing = true
        selectedTemplateID = nil
        if !options.removeLocation || !options.removeDateTime || !options.removeDeviceInfo || !options.removeCameraSettings {
            options.removeAll = false
        }
    }
}
