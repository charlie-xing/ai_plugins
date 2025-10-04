# AI 插件平台项目概要

## 1. 核心目标
构建一个基于 Swift (macOS) 的插件平台，能够运行用户编写的 JavaScript 插件。
- **专注于 AI 大模型交互**：插件的核心功能是与 AI 大模型进行交互。
- **支持多种 AI 服务商**：平台设计为与 OpenAI API 兼容协议 的 LLM 服务商（如 OpenRouter.ai, OpenAI, Claude/Gemini 兼容层等）通用。

## 2. 主要功能要求
### 2.1 插件管理系统
- **加载与发现**：能够从指定本地目录加载 .js 格式的插件文件。
- **元数据解析**：解析插件 JS 文件中定义的元数据（名称、描述、作者、版本、入口函数、模式等）。
- **启用/禁用**：用户可以启用或禁用已安装的插件。
- **配置管理**：为每个插件提供独立的配置界面，允许用户设置插件特有的参数。
- **插件模式识别**：支持并识别多种插件交互模式。

### 2.2 AI 大模型交互
- **通用 API 适配**：通过一个统一的 Swift 服务层 (AIAPIService)，适配所有兼容 OpenAI API 协议的 LLM 服务商。
- **API Key 管理**：在本地安全存储和管理 AI 服务商的 API Key，支持切换不同的服务商及对应的 API Key 和 Base URL。
- **模型选择**：能够获取并展示当前配置服务商下的可用 AI 模型列表，允许用户选择默认模型。
- **请求与响应**：能够向 AI 模型发送聊天完成请求，并接收多种类型的结果。

### 2.3 结果展示与 UI 交互
- **WebView 渲染**：将 AI 交互返回的结果（文本、HTML、JSON、SVG、图片、视频 URL 等）渲染到 WKWebView 中。
- **动态更新**：支持替换或追加内容到 WKWebView，以实现流畅的交互体验。

### 2.4 用户界面 (macOS SwiftUI)
- **认证/配置界面 (AuthView)**：
  - 在首次启动或未配置时显示。
  - 允许用户选择 AI 服务提供商（OpenRouter.ai, OpenAI, Custom URL）。
  - 输入对应的 API Base URL 和 API Key。
  - 保存配置。
- **主界面 (MainView)**：
  - 采用 NavigationSplitView 布局（侧边栏 + 内容区）。
  - 侧边栏：显示已启用插件列表、插件中心、设置入口。
  - 内容区：根据选择显示插件交互界面、插件中心或设置界面。
- **设置界面 (SettingsView)**：
  - 配置全局 API 设置（服务商、Base URL、API Key）。
  - 选择默认 AI 模型。
  - 其他通用平台设置（如日志级别、插件目录）。
- **插件详情/交互界面 (PluginDetailView)**：
  - 显示插件信息。
  - 提供用户输入区域（Prompt）。
  - 集成 WKWebView 实时显示插件与 AI 交互的结果。
  - 提供插件特定配置入口。

### 2.5 JavaScript 插件功能
- **标准入口函数**：插件通过定义统一的入口函数 (runPlugin) 来接收 Swift 平台传递的参数。
- **Swift-JS 桥接 (JSBridge)**：
  - 允许 JS 插件调用 Swift 提供的功能，尤其是与 AI 模型进行交互 (fetchAIResult)。
  - 允许 JS 插件访问其自身配置 (getConfiguration)。
  - 提供日志输出 (log)。
  - 未来可扩展：支持存储状态、调用 Swift 工具函数、更丰富的 UI 更新指令等。
- **结果结构化**：JS 插件返回一个包含 content、type (html, text, imageUrl 等) 和 replace (是否替换 WebView 内容) 的结果对象。

## 3. 插件模式 (交互类型)
- **Chat 模式**：
  - **特点**：持续对话，保持上下文。
  - **机制**：JS 插件内部管理对话历史，或通过 Swift 桥接层存储和获取上下文。
- **BOT 模式**：
  - **特点**：事件驱动，自动化执行。
  - **机制**：Swift 平台监听外部事件（例如新邮件），调用 JS 插件处理事件，插件与 AI 交互并执行预设动作。
- **Agent 模式**：
  - **特点**：多步任务，AI 工具调用。
  - **机制**：JS 插件与 AI 进行多轮交互，AI 建议调用 Swift 提供的“工具”（例如预订票），JS 通过桥接层调用工具，并将结果反馈给 AI。
- **Role 模式**：
  - **特点**：特定角色，单次交互。
  - **机制**：JS 插件预设 AI 角色/指令，接收用户输入，进行单次 AI 交互，返回特定功能结果。
- **其他可能模式 (待定，但平台应支持扩展)**：
  - Monitor 模式 (监控数据流)
  - Transform 模式 (数据格式转换)
  - Creative 模式 (创意内容生成)
  - Workflow 模式 (复杂工作流编排)

## 4. 技术栈与安全
- **技术栈**：Swift, SwiftUI, WKWebView, JavaScriptCore, URLSession。
- **安全性**：
  - JS 插件执行在沙盒环境 (JavaScriptCore) 中。
  - 所有网络请求（包括 AI API 调用）通过 Swift 桥接层处理，可进行白名单和权限控制。
  - 敏感信息（如 API Key）本地存储，建议使用 Keychain (但初期可简化为 UserDefaults)。
  - 文件系统访问受限。
