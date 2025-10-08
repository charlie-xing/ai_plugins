# 知识库功能 / Knowledge Base Feature

## 概述 / Overview

本项目新增了强大的知识库管理功能，支持三种类型的知识库：本地文件夹、网站爬虫和企业API。用户可以通过设置界面配置和管理知识库，对文档进行向量化处理，以支持智能问答和语义搜索。

This project has added powerful knowledge base management functionality, supporting three types of knowledge bases: local folders, web crawling, and enterprise APIs. Users can configure and manage knowledge bases through the settings interface, perform vectorization processing on documents to support intelligent Q&A and semantic search.

## 功能特性 / Features

### 📁 本地文件夹 / Local Folder
- 扫描指定文件夹及子文件夹
- 支持多种文件格式（.txt, .md, .pdf 等）
- 可配置文件大小限制和扩展名过滤
- 自动提取和分块文档内容

### 🌐 网站爬虫 / Web Crawler  
- 智能爬取网站内容
- 支持爬取深度和页面数量限制
- 遵循 robots.txt 协议
- 自动提取网页文本内容

### 🏢 企业API / Enterprise API
- 连接企业知识库API
- 支持自定义认证方式
- 批量同步文档数据
- 灵活的数据格式适配

## 使用方法 / Usage

### 1. 访问知识库设置 / Access Knowledge Base Settings
1. 打开应用程序
2. 点击左侧边栏的"设置"标签
3. 选择"知识库"设置项

### 2. 添加知识库 / Add Knowledge Base
1. 点击"添加知识库"按钮
2. 填写知识库名称和描述
3. 选择知识库类型
4. 配置相应的参数
5. 点击"保存"

### 3. 配置参数 / Configuration Parameters

#### 本地文件夹配置 / Local Folder Configuration
- **文件夹路径**: 选择要索引的本地文件夹
- **包含子文件夹**: 是否递归扫描子文件夹
- **支持的扩展名**: 要处理的文件类型（如：txt,md,pdf）
- **最大文件大小**: 单个文件的大小限制

#### 网站爬虫配置 / Web Crawler Configuration  
- **网站地址**: 起始URL地址
- **爬取深度**: 链接跳转的最大层数
- **最大页面数**: 爬取页面的数量上限
- **遵循robots.txt**: 是否尊重网站的爬虫协议

#### 企业API配置 / Enterprise API Configuration
- **API端点**: 企业知识库API的地址
- **API密钥**: 用于认证的密钥
- **超时时间**: 请求超时设置（秒）
- **批次大小**: 每次同步的文档数量

### 4. 处理知识库 / Process Knowledge Base
1. 在知识库列表中选择要处理的知识库
2. 点击"配置"按钮打开详细设置
3. 根据知识库类型点击相应的处理按钮：
   - 本地文件夹：点击"索引文件"
   - 网站爬虫：点击"爬取网站"  
   - 企业API：点击"同步数据"
4. 等待处理完成

## 技术实现 / Technical Implementation

### 架构设计 / Architecture
```
KnowledgeBaseSettingsView (UI层)
         ↓
KnowledgeBaseManager (数据管理)
         ↓
KnowledgeBaseService (业务逻辑)
         ↓
Processors (具体处理器)
├── LocalFolderProcessor
├── WebCrawlerProcessor
└── EnterpriseAPIProcessor
         ↓
VectorDatabaseManager (向量数据库)
```

### 数据存储 / Data Storage
- 配置文件: `~/.ai_plugins_data/knowledge_bases/knowledge_bases.json`
- 向量数据: `~/.ai_plugins_data/knowledge_bases/vectors/{kb_id}/`
- 支持的向量维度: 384/768/1536（可配置）

### 文件结构 / File Structure
```
Sources/ai_plugins/
├── Models/
│   └── KnowledgeBase.swift          # 数据模型
├── Views/Settings/
│   ├── KnowledgeBaseSettingsView.swift    # 主设置界面
│   ├── AddKnowledgeBaseView.swift         # 添加知识库界面
│   └── EditKnowledgeBaseView.swift        # 编辑知识库界面
└── Services/KnowledgeBase/
    ├── KnowledgeBaseService.swift         # 服务管理器
    ├── LocalFolderProcessor.swift         # 本地文件处理器
    ├── WebCrawlerProcessor.swift          # 网站爬虫处理器
    └── EnterpriseAPIProcessor.swift       # 企业API处理器
```

## 支持的文件格式 / Supported File Formats

| 格式 | 扩展名 | 描述 |
|------|--------|------|
| 纯文本 | .txt | 普通文本文件 |
| Markdown | .md, .markdown | Markdown格式文档 |
| PDF | .pdf | PDF文档（需要文本提取） |
| HTML | .html, .htm | 网页文档 |
| RTF | .rtf | 富文本格式 |

## 状态说明 / Status Descriptions

| 状态 | 说明 | 操作建议 |
|------|------|----------|
| 就绪 | 知识库已配置完成，可以使用 | 正常使用 |
| 未配置 | 缺少必要的配置信息 | 完成配置设置 |
| 需要索引 | 本地文件夹需要重新索引 | 点击"索引文件" |
| 需要爬取 | 网站需要重新爬取 | 点击"爬取网站" |
| 需要同步 | 企业API需要同步数据 | 点击"同步数据" |
| 已禁用 | 知识库被暂时禁用 | 启用开关 |
| 处理中 | 正在处理中，请等待 | 等待或取消 |
| 错误 | 处理过程中出现错误 | 检查配置和日志 |

## 最佳实践 / Best Practices

### 性能优化 / Performance Optimization
1. **合理设置文件大小限制**: 避免处理过大的文件
2. **控制爬取频率**: 为网站爬虫设置适当的延迟
3. **批量处理**: 对于大量文档，使用适当的批次大小
4. **定期维护**: 清理过时的向量数据

### 安全建议 / Security Recommendations
1. **API密钥保护**: 确保API密钥的安全存储
2. **权限控制**: 限制文件夹访问权限
3. **网络安全**: 使用HTTPS连接企业API
4. **数据加密**: 考虑对敏感数据进行加密存储

### 故障排除 / Troubleshooting

#### 常见问题 / Common Issues

**Q: 本地文件夹扫描失败**
A: 检查文件夹路径是否正确，确保有读取权限

**Q: 网站爬取无内容**
A: 检查网站是否可访问，robots.txt是否允许爬取

**Q: 企业API连接失败**
A: 验证API端点和密钥是否正确，检查网络连接

**Q: 处理速度过慢**
A: 减少批次大小，优化文档内容，检查系统资源

## 更新日志 / Changelog

### v1.0.0 (2024-10-08)
- ✨ 新增三种知识库类型支持
- 🎨 完整的用户界面设计
- 🔧 灵活的配置选项
- 📊 实时处理进度显示
- 🌐 多语言支持（中文/英文）
- 🔒 数据安全存储

## 许可证 / License

本功能遵循项目的开源许可证。

## 贡献 / Contributing

欢迎提交Issue和Pull Request来改进知识库功能！

---

**注意**: 这是一个新功能，仍在持续改进中。如有问题请及时反馈。