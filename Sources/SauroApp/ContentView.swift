import SwiftUI
import AppKit

struct ContentView: View {
    @EnvironmentObject private var coordinator: AppCoordinator
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Sauro")
                .font(.largeTitle.bold())
            Text("每 5 秒截屏 -> OCR -> 大模型识别日程 -> 自动写入 Apple Calendar")
                .foregroundStyle(.secondary)

            GroupBox("LLM 配置") {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("API Key")
                            .frame(width: 90, alignment: .leading)
                        SecureField("sk-...", text: $settings.apiKey)
                    }

                    HStack {
                        Text("Base URL")
                            .frame(width: 90, alignment: .leading)
                        TextField("https://api.openai.com/v1", text: $settings.baseURL)
                    }

                    HStack {
                        Text("Model")
                            .frame(width: 90, alignment: .leading)
                        TextField("gpt-4.1-mini", text: $settings.model)
                    }

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
            }

            Divider()

            HStack(alignment: .top, spacing: 12) {
                GroupBox("OCR 文本（最近一次）") {
                    ScrollView {
                        Text(coordinator.latestOCRText.isEmpty ? "暂无数据" : coordinator.latestOCRText)
                            .font(.system(.body, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(minHeight: 130)
                }

                GroupBox("发给大模型的请求（最近一次）") {
                    ScrollView {
                        Text(coordinator.latestLLMRequest.isEmpty ? "暂无数据" : coordinator.latestLLMRequest)
                            .font(.system(.body, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(minHeight: 130)
                }

                GroupBox("大模型回复（最近一次）") {
                    ScrollView {
                        Text(coordinator.latestLLMResponse.isEmpty ? "暂无数据" : coordinator.latestLLMResponse)
                            .font(.system(.body, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(minHeight: 130)
                }
            }

            Text("运行日志")
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
