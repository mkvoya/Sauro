import SwiftUI

struct SettingsView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(PipelineCoordinator.self) private var coordinator
    @State private var availableCalendars: [String] = []
    @State private var displays: [DisplayInfo] = []

    var body: some View {
        @Bindable var settings = settings

        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Settings")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 6) {
                    Text("LLM Provider")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Picker("Provider", selection: $settings.llmProvider) {
                        Text("Ollama").tag(LLMProviderChoice.ollama)
                        Text("OpenAI").tag(LLMProviderChoice.openAI)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }

                switch settings.llmProvider {
                case .ollama:
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Ollama Model")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("Model name", text: $settings.ollamaModel)
                            .textFieldStyle(.roundedBorder)
                    }

                case .openAI:
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Base URL")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("https://api.openai.com", text: $settings.openAIBaseURL)
                            .textFieldStyle(.roundedBorder)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("API Key")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        SecureField("sk-...", text: $settings.openAIAPIKey)
                            .textFieldStyle(.roundedBorder)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Model")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("Model name", text: $settings.openAIModel)
                            .textFieldStyle(.roundedBorder)
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Capture Interval: \(Int(settings.captureInterval))s")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Slider(value: $settings.captureInterval, in: 1...30, step: 1)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Confidence Threshold: \(Int(settings.confidenceThreshold * 100))%")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Slider(value: $settings.confidenceThreshold, in: 0.1...1.0, step: 0.05)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Target Calendar")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Picker("Calendar", selection: $settings.targetCalendar) {
                        Text("Default").tag(nil as String?)
                        ForEach(availableCalendars, id: \.self) { title in
                            Text(title).tag(title as String?)
                        }
                    }
                    .labelsHidden()
                }

                if displays.count > 1 {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Capture Display")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Picker("Display", selection: $settings.selectedDisplayID) {
                            Text("Primary").tag(UInt32(0))
                            ForEach(displays, id: \.displayID) { display in
                                Text("Display \(display.displayID) (\(display.width)x\(display.height))")
                                    .tag(display.displayID)
                            }
                        }
                        .labelsHidden()
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Daily API Call Limit: \(settings.dailyAPICallLimit)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Slider(
                        value: Binding(
                            get: { Double(settings.dailyAPICallLimit) },
                            set: { settings.dailyAPICallLimit = Int($0) }
                        ),
                        in: 10...1000,
                        step: 10
                    )
                }

                Toggle("Pause When Screen Locked", isOn: $settings.pauseWhenIdle)
                    .font(.caption)

                Toggle("Verbose Logging", isOn: $settings.verboseLogging)
                    .font(.caption)
            }
        }
        .task {
            availableCalendars = await coordinator.calendarManager.availableCalendarTitles()
            displays = (try? await coordinator.screenCapture.availableDisplays()) ?? []
        }
    }
}
