# RAG (Retrieval-Augmented Generation) 实现指南

## 📋 概述

本文档详细介绍了在AI插件系统中实现RAG功能的完整方案。RAG通过将知识库检索与AI生成相结合，能够为用户提供基于特定知识库的准确回答。

## 🎯 功能特性

- ✅ **知识库选择**: 用户可以在对话界面选择已配置的知识库
- ✅ **智能检索**: 基于向量相似度的语义搜索
- ✅ **上下文增强**: 自动将检索到的相关内容添加到AI提示中
- ✅ **透明体验**: 用户界面保持简洁，RAG过程在后台进行
- ✅ **灵活配置**: 可调整检索参数、相似度阈值等设置
- ✅ **多语言支持**: 完整的中英文本地化

## 🏗️ 架构设计

### 核心组件

```
┌─────────────────────────────────────────────────────────────┐
│                        UI Layer                             │
├─────────────────────────────────────────────────────────────┤
│  ExpandableTextInput  │  RAGSettingsView  │  PluginDetailView│
├─────────────────────────────────────────────────────────────┤
│                      Business Logic                         │
├─────────────────────────────────────────────────────────────┤
│     RAGService        │   PluginViewModel  │ KnowledgeBase   │
├─────────────────────────────────────────────────────────────┤
│                       Data Layer                            │
├─────────────────────────────────────────────────────────────┤
│ KnowledgeBaseService  │  EmbeddingService  │ SQLiteVectorDB  │
└─────────────────────────────────────────────────────────────┘
```

### 数据流程

```
用户输入 → 知识库检索 → 上下文构建 → 提示增强 → AI处理 → 回复显示
```

## 🔧 核心实现

### 1. RAG服务 (`RAGService.swift`)

主要负责RAG流程的协调和管理：

```swift
@MainActor
class RAGService: ObservableObject {
    static let shared = RAGService()
    
    @Published var configuration = RAGConfiguration()
    
    // 核心功能：增强用户提示
    func enhancePrompt(_ originalPrompt: String, 
                      using knowledgeBase: KnowledgeBase) async throws -> RAGContext
    
    // 构建系统提示
    func buildSystemPrompt(with context: RAGContext) -> String
}
```

**主要方法**:
- `enhancePrompt()`: 检索相关内容并增强用户提示
- `buildSystemPrompt()`: 为AI模型构建包含知识库上下文的系统提示
- `hasRelevantContent()`: 检查知识库是否包含相关信息

### 2. RAG配置 (`RAGConfiguration`)

可配置的参数：

```swift
struct RAGConfiguration: Codable {
    var enabled: Bool = true              // 是否启用RAG
    var maxResults: Int = 5               // 最大检索结果数
    var similarityThreshold: Float = 0.7  // 相似度阈值
    var maxContextLength: Int = 2000      // 最大上下文长度
    var includeMetadata: Bool = false     // 是否包含元数据
    var contextTemplate: String          // 上下文模板
}
```

### 3. 用户界面集成

#### 知识库选择器
```swift
// ExpandableTextInput中的知识库选择按钮
ToolbarButton(
    icon: selectedKnowledgeBase != nil ? "books.vertical.fill" : "books.vertical",
    tooltip: selectedKnowledgeBase?.name ?? "Select knowledge base"
) {
    showingKnowledgeBaseSelection.toggle()
}
```

#### 插件执行增强
```swift
// PluginViewModel中的RAG增强执行
private func executePluginWithRAG(prompt: String) {
    guard let knowledgeBase = selectedKnowledgeBase else {
        executePlugin(prompt: prompt)
        return
    }
    
    Task { @MainActor in
        do {
            let ragContext = try await ragService.enhancePrompt(prompt, using: knowledgeBase)
            executePlugin(prompt: ragContext.enhancedPrompt)
        } catch {
            executePlugin(prompt: prompt) // 降级处理
        }
    }
}
```

## 💻 使用方法

### 1. 基础使用

1. **配置知识库**: 在设置中创建和配置知识库
2. **选择知识库**: 在输入框下方点击知识库选择按钮
3. **正常对话**: 输入问题，系统自动使用RAG增强回复

### 2. 高级配置

进入 `设置 → RAG配置` 调整以下参数：

- **最大检索结果数**: 控制从知识库检索的内容块数量
- **相似度阈值**: 过滤低相关性的内容
- **最大上下文长度**: 限制传递给AI的上下文文本长度
- **上下文模板**: 自定义上下文格式

### 3. 开发者集成

```swift
// 在插件中使用RAG
let ragService = RAGService.shared
let context = try await ragService.enhancePrompt(userQuery, using: knowledgeBase)

// 获取增强后的提示
let enhancedPrompt = context.enhancedPrompt

// 获取系统提示
let systemPrompt = ragService.buildSystemPrompt(with: context)
```

## ⚙️ 配置参数详解

### RAGConfiguration 参数说明

| 参数 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `enabled` | Bool | true | 全局RAG开关 |
| `maxResults` | Int | 5 | 检索结果数量限制 |
| `similarityThreshold` | Float | 0.7 | 相似度阈值(0.0-1.0) |
| `maxContextLength` | Int | 2000 | 上下文文本长度限制 |
| `includeMetadata` | Bool | false | 是否显示相似度分数 |
| `contextTemplate` | String | 预定义模板 | 上下文格式模板 |

### 推荐配置

**通用场景**:
```swift
maxResults = 5
similarityThreshold = 0.7
maxContextLength = 2000
```

**高精度场景**:
```swift
maxResults = 3
similarityThreshold = 0.8
maxContextLength = 1500
```

**广泛覆盖场景**:
```swift
maxResults = 10
similarityThreshold = 0.6
maxContextLength = 3000
```

## 🧪 测试和验证

项目包含完整的测试套件 `test_rag_functionality.swift`:

```bash
# 运行RAG功能测试
swift test_rag_functionality.swift
```

测试覆盖：
- ✅ 配置管理
- ✅ 知识库选择
- ✅ 上下文构建
- ✅ 提示增强
- ✅ 性能测试
- ✅ 错误处理

## 🔍 调试和监控

### 日志输出

RAG服务会输出详细的调试信息：

```
RAGService: Enhanced prompt with 3 relevant chunks
PluginViewModel: RAG enhanced prompt with 3 results
```

### 性能监控

- 上下文构建时间: < 1秒
- 提示增强平均时间: < 0.001秒
- 大数据集处理: < 5秒

### 调试技巧

1. **检查知识库状态**: 确保知识库为 `ready` 状态
2. **调整相似度阈值**: 如果没有检索到结果，降低阈值
3. **查看日志**: 观察检索到的块数量和相似度分数
4. **测试查询**: 使用简单明确的问题测试

## ⚠️ 故障排除

### 常见问题

**1. 没有检索到相关内容**
- 检查知识库是否包含相关内容
- 降低 `similarityThreshold` 参数
- 检查知识库索引是否完整

**2. 上下文过长**
- 减少 `maxResults` 参数
- 降低 `maxContextLength` 参数
- 优化上下文模板

**3. 响应质量不佳**
- 提高 `similarityThreshold` 参数
- 检查知识库内容质量
- 调整上下文模板

**4. 性能问题**
- 减少 `maxResults` 参数
- 优化知识库索引
- 检查向量数据库性能

### 错误代码

| 错误 | 描述 | 解决方案 |
|------|------|----------|
| `knowledgeBaseNotReady` | 知识库未就绪 | 完成知识库配置和索引 |
| `searchFailed` | 搜索失败 | 检查向量数据库连接 |
| `noRelevantContent` | 无相关内容 | 调整搜索参数或更新知识库 |
| `configurationError` | 配置错误 | 检查RAG配置参数 |

## 📝 最佳实践

### 知识库管理
1. 保持知识库内容的更新和质量
2. 定期清理和优化索引
3. 合理分类不同类型的知识库

### RAG配置
1. 根据应用场景调整参数
2. 定期评估和优化配置
3. 监控性能和质量指标

### 用户体验
1. 提供清晰的知识库选择界面
2. 在适当时机提示用户RAG的使用
3. 保持界面简洁，避免过度复杂化

## 🔗 相关文件

### 核心文件
- `Services/RAGService.swift` - RAG核心服务
- `Views/Components/ExpandableTextInput.swift` - 输入组件
- `ViewModels/PluginViewModel.swift` - 插件视图模型
- `Views/Settings/RAGSettingsView.swift` - RAG设置界面

### 配置文件
- `Models/SettingsSection.swift` - 设置分类
- `Resources/*/Localizable.strings` - 本地化字符串

### 测试文件
- `test_rag_functionality.swift` - 功能测试脚本

## 🚀 未来扩展

### 计划功能
- [ ] 多知识库同时检索
- [ ] 检索结果缓存机制
- [ ] 自适应相似度阈值
- [ ] RAG使用统计和分析
- [ ] 更多上下文模板选项

### 性能优化
- [ ] 异步检索优化
- [ ] 向量索引性能提升
- [ ] 内存使用优化
- [ ] 批量处理支持

## 📞 支持和反馈

如有问题或建议，请：
1. 查阅本文档的故障排除部分
2. 运行测试脚本验证功能
3. 检查系统日志获取详细信息
4. 联系开发团队获取支持

---

*本文档随RAG功能的更新而持续维护*