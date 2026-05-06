import UIKit
import UniformTypeIdentifiers
import ImageIO
import Photos

/// Share extension that receives images, strips sensitive metadata, then lets the
/// user share the cleaned copies onward or save them back to Photos.
final class ShareViewController: UIViewController {

    private let appGroupID = "group.com.katafract.exifarmor"
    private let sharedProAccessKey = "sharedProAccessUnlocked"
    private let enclaveGroupID = "group.com.katafract.enclave"

    private var imageDataItems: [(Data, String)] = []
    private var cleanedDataItems: [(Data, String)] = []
    private var tempShareURLs: [URL] = []

    // UI
    private let statusLabel = UILabel()
    private let progressView = UIProgressView(progressViewStyle: .default)
    private let containerView = UIView()
    private let subtitleLabel = UILabel()
    private let actionStack = UIStackView()
    private let shareButton = UIButton(type: .system)
    private let saveButton = UIButton(type: .system)
    private let doneButton = UIButton(type: .system)

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        if hasProOrEnclaveAccess {
            loadSharedItems()
        } else {
            showPremiumRequired()
        }
    }

    // MARK: - UI Setup

    private func setupUI() {
        view.backgroundColor = UIColor(named: "BackgroundDark")
            ?? UIColor(red: 0.035, green: 0.035, blue: 0.063, alpha: 1)

        containerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(containerView)

        let titleLabel = UILabel()
        titleLabel.text = "ExifArmor"
        titleLabel.font = .systemFont(ofSize: 20, weight: .bold)
        titleLabel.textColor = UIColor(named: "AccentCyan") ?? .systemCyan
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        subtitleLabel.text = "Cleaning metadata…"
        subtitleLabel.font = .systemFont(ofSize: 13)
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.textAlignment = .center
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false

        statusLabel.text = ""
        statusLabel.font = .systemFont(ofSize: 14)
        statusLabel.textColor = .secondaryLabel
        statusLabel.textAlignment = .center
        statusLabel.numberOfLines = 0
        statusLabel.translatesAutoresizingMaskIntoConstraints = false

        progressView.progressTintColor = UIColor(named: "AccentCyan") ?? .systemCyan
        progressView.translatesAutoresizingMaskIntoConstraints = false

        actionStack.axis = .vertical
        actionStack.spacing = 10
        actionStack.translatesAutoresizingMaskIntoConstraints = false
        actionStack.isHidden = true

        configurePrimaryButton(shareButton, title: "Share Clean Copy", action: #selector(shareTapped))
        configureSecondaryButton(saveButton, title: "Save to Photos", action: #selector(saveTapped))
        configureSecondaryButton(doneButton, title: "Done", action: #selector(doneTapped))

        actionStack.addArrangedSubview(shareButton)
        actionStack.addArrangedSubview(saveButton)
        actionStack.addArrangedSubview(doneButton)

        let cancelButton = UIButton(type: .system)
        cancelButton.setTitle("Cancel", for: .normal)
        cancelButton.titleLabel?.font = .systemFont(ofSize: 14)
        cancelButton.setTitleColor(.secondaryLabel, for: .normal)
        cancelButton.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
        cancelButton.translatesAutoresizingMaskIntoConstraints = false

        containerView.addSubview(titleLabel)
        containerView.addSubview(subtitleLabel)
        containerView.addSubview(progressView)
        containerView.addSubview(statusLabel)
        containerView.addSubview(actionStack)
        containerView.addSubview(cancelButton)

        NSLayoutConstraint.activate([
            containerView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            containerView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            containerView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),

            titleLabel.topAnchor.constraint(equalTo: containerView.topAnchor),
            titleLabel.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            subtitleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            subtitleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),

            progressView.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 20),
            progressView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            progressView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),

            statusLabel.topAnchor.constraint(equalTo: progressView.bottomAnchor, constant: 12),
            statusLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            statusLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),

            actionStack.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 20),
            actionStack.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            actionStack.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),

            cancelButton.topAnchor.constraint(equalTo: actionStack.bottomAnchor, constant: 20),
            cancelButton.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            cancelButton.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
        ])
    }

    private func configurePrimaryButton(_ button: UIButton, title: String, action: Selector) {
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        button.setTitleColor(UIColor(named: "BackgroundDark") ?? .black, for: .normal)
        button.backgroundColor = UIColor(named: "AccentCyan") ?? .systemCyan
        button.layer.cornerRadius = 12
        button.heightAnchor.constraint(equalToConstant: 50).isActive = true
        button.addTarget(self, action: action, for: .touchUpInside)
    }

    private func configureSecondaryButton(_ button: UIButton, title: String, action: Selector) {
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 16, weight: .medium)
        button.setTitleColor(UIColor(named: "AccentCyan") ?? .systemCyan, for: .normal)
        button.backgroundColor = UIColor.secondarySystemBackground.withAlphaComponent(0.6)
        button.layer.cornerRadius = 12
        button.heightAnchor.constraint(equalToConstant: 46).isActive = true
        button.addTarget(self, action: action, for: .touchUpInside)
    }

    // MARK: - Load Shared Items

    private func loadSharedItems() {
        guard let extensionItems = extensionContext?.inputItems as? [NSExtensionItem] else {
            showError("No items received")
            return
        }

        let group = DispatchGroup()

        for item in extensionItems {
            guard let attachments = item.attachments else { continue }
            for provider in attachments where provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                group.enter()
                provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { [weak self] data, _ in
                    defer { group.leave() }
                    guard let data else { return }
                    let filename = provider.suggestedName ?? "photo_\(UUID().uuidString.prefix(8)).jpg"
                    self?.imageDataItems.append((data, filename))
                }
            }
        }

        group.notify(queue: .main) { [weak self] in
            guard let self else { return }
            if self.imageDataItems.isEmpty {
                self.showError("No images found")
            } else {
                self.processImages()
            }
        }
    }

    // MARK: - Process

    private func processImages() {
        let total = imageDataItems.count

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }

            self.cleanedDataItems = []

            for (index, (data, filename)) in self.imageDataItems.enumerated() {
                let cleanedData = self.stripAllMetadata(from: data) ?? data
                self.cleanedDataItems.append((cleanedData, filename))

                let progress = Float(index + 1) / Float(max(total, 1))
                DispatchQueue.main.async {
                    self.progressView.setProgress(progress, animated: true)
                    self.statusLabel.text = "\(index + 1) of \(total)"
                }
            }

            DispatchQueue.main.async {
                self.incrementSharedCounter(by: self.cleanedDataItems.count)
                self.showReady(total: total)
            }
        }
    }

    // MARK: - Strip Metadata

    private func stripAllMetadata(from data: Data) -> Data? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let uti = CGImageSourceGetType(source),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any]
        else {
            return nil
        }

        var cleaned = properties
        cleaned.removeValue(forKey: kCGImagePropertyExifDictionary as String)
        cleaned.removeValue(forKey: kCGImagePropertyGPSDictionary as String)
        cleaned.removeValue(forKey: kCGImagePropertyIPTCDictionary as String)
        cleaned.removeValue(forKey: kCGImagePropertyExifAuxDictionary as String)
        cleaned.removeValue(forKey: kCGImagePropertyMakerAppleDictionary as String)
        cleaned.removeValue(forKey: kCGImagePropertyJFIFDictionary as String)

        // Preserve only orientation to avoid rotated output.
        if var tiff = cleaned[kCGImagePropertyTIFFDictionary as String] as? [String: Any] {
            let orientation = tiff[kCGImagePropertyTIFFOrientation as String]
            tiff.removeAll()
            if let orientation {
                tiff[kCGImagePropertyTIFFOrientation as String] = orientation
            }
            cleaned[kCGImagePropertyTIFFDictionary as String] = tiff
        }

        let destData = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(destData as CFMutableData, uti, 1, nil) else {
            return nil
        }
        CGImageDestinationAddImage(dest, image, cleaned as CFDictionary)
        guard CGImageDestinationFinalize(dest) else {
            return nil
        }

        return destData as Data
    }

    // MARK: - Save

    private func saveCleanCopies() {
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { [weak self] status in
            DispatchQueue.main.async {
                switch status {
                case .authorized, .limited:
                    self?.performSave()
                default:
                    self?.showError("Photos access denied.\nPlease enable in Settings > ExifArmor.")
                }
            }
        }
    }

    private func performSave() {
        let total = cleanedDataItems.count
        var savedCount = 0

        subtitleLabel.text = "Saving cleaned copies…"
        statusLabel.text = ""
        statusLabel.textColor = .secondaryLabel
        actionStack.isHidden = true

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }

            for (index, (data, _)) in self.cleanedDataItems.enumerated() {
                let semaphore = DispatchSemaphore(value: 0)
                PHPhotoLibrary.shared().performChanges({
                    let request = PHAssetCreationRequest.forAsset()
                    request.addResource(with: .photo, data: data, options: nil)
                }) { success, _ in
                    if success {
                        savedCount += 1
                    }
                    semaphore.signal()
                }
                semaphore.wait()

                let progress = Float(index + 1) / Float(max(total, 1))
                DispatchQueue.main.async {
                    self.progressView.setProgress(progress, animated: true)
                }
            }

            DispatchQueue.main.async {
                self.subtitleLabel.text = "Done"
                self.statusLabel.text = "✓ \(savedCount) clean photo\(savedCount == 1 ? "" : "s") saved to Photos"
                self.statusLabel.textColor = UIColor(named: "SuccessGreen") ?? .systemGreen
                self.actionStack.isHidden = false
            }
        }
    }

    // MARK: - Share

    private func temporaryFileURLsForCleanedItems() -> [URL] {
        cleanupTemporaryFiles()
        let tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("CleanedShare", isDirectory: true)
        try? FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)

        let urls = cleanedDataItems.compactMap { data, filename in
            let safeName = filename.isEmpty ? "ExifArmor-\(UUID().uuidString).jpg" : filename
            let url = tempDirectory.appendingPathComponent(safeName)
            do {
                try data.write(to: url, options: .atomic)
                return url
            } catch {
                return nil
            }
        }

        tempShareURLs = urls
        return urls
    }

    private func cleanupTemporaryFiles() {
        for url in tempShareURLs {
            try? FileManager.default.removeItem(at: url)
        }
        tempShareURLs = []

        let tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("CleanedShare", isDirectory: true)
        try? FileManager.default.removeItem(at: tempDirectory)
    }

    // MARK: - App Group Counter

    private func incrementSharedCounter(by count: Int) {
        guard let defaults = UserDefaults(suiteName: appGroupID) else { return }
        let current = defaults.integer(forKey: "totalPhotosStripped")
        defaults.set(current + count, forKey: "totalPhotosStripped")
    }

    // MARK: - UI State

    private func showReady(total: Int) {
        subtitleLabel.text = "Clean copies ready"
        statusLabel.text = "✓ \(total) photo\(total == 1 ? "" : "s") cleaned. Share them now or save them to Photos."
        statusLabel.textColor = UIColor(named: "SuccessGreen") ?? .systemGreen
        progressView.setProgress(1.0, animated: true)
        actionStack.isHidden = false
    }

    private func showPremiumRequired() {
        subtitleLabel.text = "ExifArmor Pro Required"
        statusLabel.text = "Clean and forward photos straight from the iOS share sheet with ExifArmor Pro. Upgrade in the app to unlock this premium extension for a $3.99 one-time purchase."
        statusLabel.textColor = UIColor(named: "AccentGold") ?? .systemYellow
        progressView.isHidden = true
        actionStack.isHidden = true
    }

    private func showError(_ message: String) {
        statusLabel.text = message
        statusLabel.textColor = .systemRed
        actionStack.isHidden = true
    }

    /// Check for Pro access via ExifArmor purchase OR Enclave/Sovereign platform subscription
    private var hasProOrEnclaveAccess: Bool {
        // Check ExifArmor Pro purchase via app group
        if let defaults = UserDefaults(suiteName: appGroupID),
           defaults.bool(forKey: sharedProAccessKey) {
            return true
        }

        // Check active Enclave/Sovereign platform token via Enclave app group
        if let enclaveDefaults = UserDefaults(suiteName: enclaveGroupID),
           let plan = enclaveDefaults.string(forKey: "enclave_plan") {
            let validPlans = ["enclave", "enclave_annual", "sovereign", "sovereign_annual", "founder"]
            if validPlans.contains(plan) {
                // Also check expiry if token_expires_at is stored
                if let expiry = enclaveDefaults.object(forKey: "enclave_token_expires_at") as? Date,
                   expiry < Date() {
                    return false // Token expired
                }
                return true
            }
        }

        return false
    }

    @objc private func shareTapped() {
        let urls = temporaryFileURLsForCleanedItems()
        guard !urls.isEmpty else {
            showError("Could not prepare files for sharing.")
            return
        }

        let controller = UIActivityViewController(activityItems: urls, applicationActivities: nil)
        controller.completionWithItemsHandler = { [weak self] _, _, _, _ in
            self?.cleanupTemporaryFiles()
            self?.extensionContext?.completeRequest(returningItems: nil)
        }

        if let popover = controller.popoverPresentationController {
            popover.sourceView = shareButton
            popover.sourceRect = shareButton.bounds
        }

        present(controller, animated: true)
    }

    @objc private func saveTapped() {
        saveCleanCopies()
    }

    @objc private func doneTapped() {
        cleanupTemporaryFiles()
        extensionContext?.completeRequest(returningItems: nil)
    }

    @objc private func cancelTapped() {
        cleanupTemporaryFiles()
        extensionContext?.cancelRequest(withError: NSError(
            domain: "ExifArmor",
            code: 0,
            userInfo: [NSLocalizedDescriptionKey: "Cancelled"]
        ))
    }
}
