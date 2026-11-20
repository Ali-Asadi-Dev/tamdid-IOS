import SwiftUI
import TamdidCore
import TamdidData
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.appFormat) private var format
    @Environment(\.openURL) private var openURL

    @State private var exportDocument: ExportDocument?
    @State private var importing = false
    @State private var pendingImport: AppData?
    @State private var message: LocalizedStringKey?

    private static let reminderOptions: [Int?] = [nil, 0, 1, 2, 3, 7]

    var body: some View {
        let settings = model.settings
        Form {
            Section("General") {
                Button {
                    // iOS sets each app's language in the Settings app.
                    if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                } label: {
                    LabeledContent("Language", value: format.language.nativeName)
                }
                .foregroundStyle(.primary)

                Picker("Main currency", selection: binding(\.primaryCurrency)) {
                    ForEach(CurrencyCode.allCases) { Text(verbatim: "\($0.displayName(format.language)) (\($0.rawValue))").tag($0) }
                }
                Picker("Calendar", selection: binding(\.calendar)) {
                    Text("Gregorian").tag(CalendarSystem.gregorian)
                    Text("Solar Hijri").tag(CalendarSystem.jalali)
                }
                Picker("Default reminder", selection: binding(\.defaultReminderDays)) {
                    ForEach(Self.reminderOptions, id: \.self) { Text(format.reminder($0)).tag($0) }
                }
                Picker("Appearance", selection: binding(\.theme)) {
                    Text("System").tag(ThemePreference.system)
                    Text("Light").tag(ThemePreference.light)
                    Text("Dark").tag(ThemePreference.dark)
                }
            }

            // Rates are only needed for currencies the user actually pays in.
            let others = Set(model.subscriptions.map(\.price.currency)).subtracting([settings.primaryCurrency])
            if !others.isEmpty {
                Section("Exchange rates") {
                    ForEach(CurrencyCode.allCases.filter(others.contains)) { currency in
                        RateRow(currency: currency, primary: settings.primaryCurrency)
                    }
                }
            }

            Section("Your data") {
                Button {
                    if let data = try? BackupCodec.encode(model.data) {
                        exportDocument = ExportDocument(data: data, type: .json, name: "tamdid-backup-\(format.today.iso)")
                    }
                } label: {
                    Label("Export backup (JSON)", systemImage: "square.and.arrow.up")
                }
                Button {
                    let csv = BackupCodec.csv(model.subscriptions, today: format.today)
                    exportDocument = ExportDocument(data: Data(csv.utf8), type: .commaSeparatedText, name: "tamdid-\(format.today.iso)")
                } label: {
                    Label("Export spreadsheet (CSV)", systemImage: "tablecells")
                }
                Button {
                    importing = true
                } label: {
                    Label("Restore from backup", systemImage: "square.and.arrow.down")
                }
            }

            Section("About") {
                LabeledContent("Tamdid", value: format.digits(String(localized: "Version \(Bundle.main.shortVersion)")))
                Link(destination: URL(string: "https://github.com/Ali-Asadi-Dev/tamdid-IOS")!) {
                    Label("Free and open source", systemImage: "chevron.left.forwardslash.chevron.right")
                }
                Text("No account, no ads, no tracking. Your data never leaves this phone unless you export it.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Settings")
        .fileExporter(
            isPresented: Binding(get: { exportDocument != nil }, set: { if !$0 { exportDocument = nil } }),
            document: exportDocument,
            contentType: exportDocument?.type ?? .json,
            defaultFilename: exportDocument?.name
        ) { result in
            if case .success = result { message = "Saved" }
            exportDocument = nil
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.json, .plainText, .data]) { result in
            guard case .success(let url) = result else { return }
            let access = url.startAccessingSecurityScopedResource()
            defer { if access { url.stopAccessingSecurityScopedResource() } }
            do {
                pendingImport = try BackupCodec.decode(Data(contentsOf: url))
            } catch StorageError.unsupportedSchemaVersion {
                message = "This backup is from a newer version of Tamdid. Update the app first."
            } catch {
                message = "That file isn’t a Tamdid backup"
            }
        }
        .alert("Replace your data?", isPresented: Binding(get: { pendingImport != nil }, set: { if !$0 { pendingImport = nil } })) {
            Button("Restore from backup", role: .destructive) {
                if let pendingImport { model.restore(pendingImport) }
                pendingImport = nil
                message = "Backup restored"
            }
            Button("Cancel", role: .cancel) { pendingImport = nil }
        } message: {
            Text(format.digits(String(localized: "The backup will replace all \(model.subscriptions.count) subscriptions and your settings.")))
        }
        .alert(message ?? "", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button("Done") { message = nil }
        }
    }

    /// A binding into one setting that saves through the model.
    private func binding<Value>(_ keyPath: WritableKeyPath<AppSettings, Value>) -> Binding<Value> {
        Binding(
            get: { model.settings[keyPath: keyPath] },
            set: { value in model.updateSettings { $0[keyPath: keyPath] = value } }
        )
    }
}

private struct RateRow: View {
    let currency: CurrencyCode
    let primary: CurrencyCode
    @Environment(AppModel.self) private var model
    @Environment(\.appFormat) private var format
    @State private var text = ""

    var body: some View {
        LabeledContent {
            TextField("Rate", text: $text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .onChange(of: text) { _, newValue in save(newValue) }
        } label: {
            Text(format.digits(String(localized: "1 \(currency.rawValue) = ? \(primary.rawValue)")))
        }
        .onAppear {
            if let rate = model.settings.exchangeRates[currency] {
                text = rate.truncatingRemainder(dividingBy: 1) == 0 ? String(Int64(rate)) : String(rate)
            }
        }
    }

    private func save(_ input: String) {
        let normalized = Digits.latinize(input)
            .replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: "\u{066C}", with: "")
            .replacingOccurrences(of: "\u{066B}", with: ".")
        let rate = Double(normalized)
        model.updateSettings { settings in
            if let rate, rate > 0 {
                settings.exchangeRates[currency] = rate
            } else if normalized.isEmpty {
                settings.exchangeRates[currency] = nil
            }
        }
    }
}

/// A file handed to the system share/save sheet.
struct ExportDocument: FileDocument {
    static let readableContentTypes: [UTType] = [.json, .commaSeparatedText]
    let data: Data
    let type: UTType
    let name: String

    init(data: Data, type: UTType, name: String) {
        self.data = data
        self.type = type
        self.name = name
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
        type = .json
        name = "tamdid"
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

extension Bundle {
    var shortVersion: String { infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0" }
}
