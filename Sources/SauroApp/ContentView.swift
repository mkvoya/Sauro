import SwiftUI
import AppKit

struct ContentView: View {
    @EnvironmentObject private var coordinator: AppCoordinator
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.openURL) private var openURL
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Sauro")
                .font(.largeTitle.bold())
            Text("每 5 秒截屏 -> OCR -> 大模型识别日程 -> 自动写入 Apple Calendar")
                .foregroundStyle(.secondary)

            GroupBox("LLM 配置") {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Provider")
                            .frame(width: 90, alignment: .leading)
                        Picker("Provider", selection: $settings.providerRawValue) {
                            ForEach(AppSettings.Provider.allCases) { provider in
                                Text(provider.displayName).tag(provider.rawValue)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.segmented)
                    }

                    if settings.provider == .openAICompatible {
                    HStack {
                        Text("API Key")
                            .frame(width: 90, alignment: .leading)
                        SecureField("sk-...", text: $settings.apiKey)
                    }
                    }

                    HStack {
                        Text("Base URL")
                            .frame(width: 90, alignment: .leading)
                        TextField(settings.provider == .ollama ? "http://127.0.0.1:11434" : "https://api.openai.com/v1", text: $settings.baseURL)
                    }

                    HStack {
                        Text("Model")
                            .frame(width: 90, alignment: .leading)
                        TextField("gpt-4.1-mini", text: $settings.model)
                    }

                    Toggle("直接添加到日历", isOn: $settings.directAddToCalendar)
                        .toggleStyle(.switch)

                    Text(settings.directAddToCalendar ? "当前模式：识别到后自动写入日历（可撤销）" : "当前模式：识别到后先发通知，手动选择“添加”或“忽略”")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    HStack {
                        Button("保存配置") {
                            settings.save()
                            coordinator.appendLog("LLM 配置已保存。")
                        }
                        .buttonStyle(.bordered)

                        Text(settings.hasRequiredFields ? "配置完整" : "配置不完整")
                            .foregroundStyle(settings.hasRequiredFields ? .green : .red)
                            .font(.caption)
                    }
                }
                .textFieldStyle(.roundedBorder)
                .padding(.top, 4)
            }

            HStack(spacing: 12) {
                Button(coordinator.isRunning ? "停止" : "开始") {
                    if coordinator.isRunning {
                        Task { await coordinator.stop() }
                    } else {
                        coordinator.start()
                    }
                }
                .buttonStyle(.borderedProminent)

                Text(coordinator.isRunning ? "状态: 运行中" : "状态: 未运行")
                    .font(.headline)

                Button("清空 OCR 去重缓存") {
                    coordinator.clearOCRDedupCache()
                }
                .buttonStyle(.bordered)

                Button("打开日志页面") {
                    openWindow(id: "terminal-log")
                }
                .buttonStyle(.bordered)
            }

            Divider()

            Text("最近运行日志")
                .font(.headline)

            List(coordinator.logs) { log in
                VStack(alignment: .leading, spacing: 4) {
                    Text(log.message)
                    Text(log.time.formatted(date: .omitted, time: .standard))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .listStyle(.plain)
        }
        .padding(20)
        .alert(item: $coordinator.permissionPrompt) { prompt in
            if let settingsURL = prompt.settingsURL {
                return Alert(
                    title: Text(prompt.title),
                    message: Text(prompt.message),
                    primaryButton: .default(Text("去设置")) {
                        openURL(settingsURL)
                    },
                    secondaryButton: .cancel(Text("稍后"))
                )
            }
            return Alert(
                title: Text(prompt.title),
                message: Text(prompt.message),
                dismissButton: .default(Text("知道了"))
            )
        }
    }
}

struct TerminalLogView: View {
    @EnvironmentObject private var coordinator: AppCoordinator

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("实时日志（Terminal）")
                    .font(.title3.bold())
                Spacer()
                Button("清空日志") {
                    coordinator.clearTerminalLogs()
                }
                .buttonStyle(.bordered)
            }

            ScrollView {
                Text(coordinator.terminalLogText.isEmpty ? "暂无日志输出。" : coordinator.terminalLogText)
                    .font(.system(size: 12, weight: .regular, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .padding(12)
            }
            .background(Color.black.opacity(0.92))
            .foregroundStyle(Color.green)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .padding(16)
    }
}
