# Sauro (macOS)

一个 macOS GUI App：
- 每 5 秒全屏截屏
- OCR 提取文本
- 调用大模型识别新日程
- 自动写入 Apple Calendar
- 弹通知并支持「撤销添加」

## 运行

```bash
cd /Users/dongmk/code/Sauro
swift run
```

启动后在 App 顶部配置区填写并保存：
- API Key
- Base URL（例如 `https://api.openai.com/v1`）
- Model（例如 `gpt-4.1-mini`）

## 用 Xcode 构建成 .app（推荐）

本仓库包含 `xcodegen` 配置，可生成原生 Xcode 工程并构建 `.app`：

```bash
cd /Users/dongmk/code/Sauro
xcodegen generate
xcodebuild -project Sauro.xcodeproj -scheme Sauro -configuration Debug -destination 'platform=macOS' -derivedDataPath build_xcode build
open /Users/dongmk/code/Sauro/build_xcode/Build/Products/Debug/Sauro.app
```

## 首次权限

第一次运行会触发系统权限：
- 屏幕录制（System Settings > Privacy & Security > Screen Recording）
- 日历（Calendars）
- 通知（Notifications）

若 OCR 一直为空，通常是屏幕录制权限未放开。
若权限被拒绝，App 会弹窗并提供「去设置」按钮引导你直接打开对应系统设置页。

## 代码结构

- `Sources/SauroApp/SauroApp.swift`: App 入口
- `Sources/SauroApp/ContentView.swift`: GUI
- `Sources/SauroApp/AppCoordinator.swift`: 5 秒轮询主流程
- `Sources/SauroApp/Services/ScreenCaptureService.swift`: 截屏
- `Sources/SauroApp/Services/OCRService.swift`: OCR
- `Sources/SauroApp/Services/LLMService.swift`: 大模型抽取事件
- `Sources/SauroApp/Services/CalendarService.swift`: 写入/删除 Calendar
- `Sources/SauroApp/Services/NotificationService.swift`: 添加完成通知 + 撤销动作
- `Sources/SauroApp/AppDelegate.swift`: 处理通知按钮回调

## 当前策略

- 只要 OCR 文本变化才会再次调用模型，避免重复消耗。
- 事件按 `title+start+end+location` 做去重。
- 点击通知中的「撤销添加」会删除刚创建的 Calendar 事件。
