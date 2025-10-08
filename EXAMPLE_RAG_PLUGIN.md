# RAG插件使用示例

本文档展示如何创建一个利用RAG功能的AI插件。

## 📋 插件概述

**插件名称**: Knowledge Assistant (知识助手)  
**功能**: 基于选定知识库回答用户问题，并明确标示信息来源  
**RAG集成**: 自动检索相关内容，提供基于知识库的准确回答

## 🔧 插件代码结构

### 1. HTML结构

```html
<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Knowledge Assistant</title>
    <style>
        /* RAG特定样式 */
        .rag-indicator {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 8px 12px;
            border-radius: 16px;
            font-size: 12px;
            margin: 8px 0;
            display: inline-flex;
            align-items: center;
            gap: 6px;
        }
        
        .knowledge-source {
            background: #f0f4ff;
            border-left: 4px solid #4f46e5;
            padding: 12px;
            margin: 8px 0;
            border-radius: 0 8px 8px 0;
            font-size: 13px;
            color: #374151;
        }
        
        .similarity-badge {
            background: #10b981;
            color: white;
            padding: 2px 8px;
            border-radius: 12px;
            font-size: 10px;
            font-weight: 600;
        }
    </style>
</head>
<body>
    <div id="chat-container">
        <div id="messages"></div>
    </div>
    
    <script>
        // 插件核心代码
        class KnowledgeAssistantPlugin {
            constructor() {
                this.settings = window.INITIAL_SETTINGS || {};
                this.messages = window.SAVED_MESSAGES || [];
                this.ragContext = this.settings.ragContext || null;
                
                this.init();
            }
            
            init() {
                this.render();
                console.log('Knowledge Assistant initialized');
                console.log('RAG Context:', this.ragContext);
            }
            
            // 检查是否启用了RAG
            isRAGEnabled() {
                return this.settings.hasKnowledgeBase && this.ragContext && this.ragContext.resultsCount > 0;
            }
            
            // 添加消息
            addMessage(role, content, ragInfo = null) {
                const message = {
                    id: Date.now(),
                    role,
                    content,
                    timestamp: new Date().toISOString(),
                    ragInfo
                };
                
                this.messages.push(message);
                this.render();
                return message;
            }
            
            // 处理用户输入
            async handleUserInput(prompt) {
                // 添加用户消息
                this.addMessage('user', prompt);
                
                // 显示RAG指示器（如果启用）
                if (this.isRAGEnabled()) {
                    this.showRAGIndicator();
                }
                
                // 构建AI请求
                const aiRequest = this.buildAIRequest(prompt);
                
                try {
                    // 发送到AI服务
                    const response = await this.callAIService(aiRequest);
                    
                    // 添加AI回复，包含RAG信息
                    this.addMessage('assistant', response.content, {
                        knowledgeBase: this.settings.knowledgeBaseName,
                        resultsCount: this.ragContext?.resultsCount || 0,
                        averageSimilarity: this.ragContext?.averageSimilarity || 0,
                        contextLength: this.ragContext?.contextLength || 0
                    });
                    
                } catch (error) {
                    console.error('AI request failed:', error);
                    this.addMessage('assistant', '抱歉，处理您的请求时出现了问题。');
                }
            }
            
            // 构建AI请求
            buildAIRequest(prompt) {
                let messages = [];
                
                // 如果有RAG上下文，添加系统提示
                if (this.settings.systemPrompt) {
                    messages.push({
                        role: 'system',
                        content: this.settings.systemPrompt
                    });
                }
                
                // 添加历史消息
                const recentMessages = this.messages.slice(-10); // 最近10条消息
                messages.push(...recentMessages.map(msg => ({
                    role: msg.role,
                    content: msg.content
                })));
                
                return {
                    model: this.settings.selectedModel,
                    messages: messages,
                    temperature: 0.7,
                    max_tokens: 2000
                };
            }
            
            // 模拟AI服务调用
            async callAIService(request) {
                // 在实际插件中，这里会调用真实的AI API
                // 这里返回模拟响应以展示RAG集成
                
                await new Promise(resolve => setTimeout(resolve, 1000)); // 模拟延迟
                
                if (this.isRAGEnabled()) {
                    return {
                        content: `基于知识库"${this.settings.knowledgeBaseName}"的信息，我来回答您的问题：

${this.generateRAGResponse()}

*此回答基于 ${this.ragContext.resultsCount} 个相关文档片段，平均相似度 ${(this.ragContext.averageSimilarity * 100).toFixed(1)}%*`
                    };
                } else {
                    return {
                        content: "我将基于我的训练知识来回答您的问题。如果您希望获得更准确的答案，建议选择相关的知识库。"
                    };
                }
            }
            
            // 生成RAG增强回复
            generateRAGResponse() {
                // 这是示例响应，实际会由AI模型生成
                const responses = [
                    "根据文档资料，这个问题涉及到以下几个关键点...",
                    "从知识库中检索到的信息显示...",
                    "基于相关文档的分析，我可以为您详细解释...",
                    "参考知识库中的专业资料..."
                ];
                
                return responses[Math.floor(Math.random() * responses.length)];
            }
            
            // 显示RAG指示器
            showRAGIndicator() {
                const indicator = document.createElement('div');
                indicator.className = 'rag-indicator';
                indicator.innerHTML = `
                    📚 正在检索知识库"${this.settings.knowledgeBaseName}"...
                    <div class="similarity-badge">${this.ragContext.resultsCount} 个结果</div>
                `;
                
                const messagesContainer = document.getElementById('messages');
                messagesContainer.appendChild(indicator);
                
                // 3秒后移除指示器
                setTimeout(() => {
                    if (indicator.parentNode) {
                        indicator.parentNode.removeChild(indicator);
                    }
                }, 3000);
            }
            
            // 渲染消息
            render() {
                const messagesContainer = document.getElementById('messages');
                messagesContainer.innerHTML = '';
                
                this.messages.forEach(message => {
                    const messageEl = this.createMessageElement(message);
                    messagesContainer.appendChild(messageEl);
                });
                
                // 滚动到底部
                messagesContainer.scrollTop = messagesContainer.scrollHeight;
            }
            
            // 创建消息元素
            createMessageElement(message) {
                const div = document.createElement('div');
                div.className = `message ${message.role}`;
                
                let contentHtml = `
                    <div class="message-content">
                        ${this.formatContent(message.content)}
                    </div>
                `;
                
                // 如果是AI消息且有RAG信息，添加知识源指示
                if (message.role === 'assistant' && message.ragInfo) {
                    contentHtml += this.createRAGInfoElement(message.ragInfo);
                }
                
                div.innerHTML = contentHtml;
                return div;
            }
            
            // 创建RAG信息元素
            createRAGInfoElement(ragInfo) {
                return `
                    <div class="knowledge-source">
                        📖 <strong>知识来源:</strong> ${ragInfo.knowledgeBase}<br>
                        📊 检索了 ${ragInfo.resultsCount} 个相关片段，平均相似度 ${(ragInfo.averageSimilarity * 100).toFixed(1)}%<br>
                        📏 上下文长度: ${ragInfo.contextLength} 字符
                    </div>
                `;
            }
            
            // 格式化内容
            formatContent(content) {
                // 简单的markdown格式化
                return content
                    .replace(/\*\*(.*?)\*\*/g, '<strong>$1</strong>')
                    .replace(/\*(.*?)\*/g, '<em>$1</em>')
                    .replace(/\n/g, '<br>');
            }
        }
        
        // 全局函数供系统调用
        let pluginInstance;
        
        function initializePlugin() {
            pluginInstance = new KnowledgeAssistantPlugin();
            window.chatApp = pluginInstance; // 供系统访问
        }
        
        function runPlugin(prompt) {
            if (pluginInstance) {
                pluginInstance.handleUserInput(prompt);
            }
        }
        
        // 页面加载完成后初始化
        document.addEventListener('DOMContentLoaded', initializePlugin);
        
        // 如果DOM已经加载完成，立即初始化
        if (document.readyState === 'loading') {
            document.addEventListener('DOMContentLoaded', initializePlugin);
        } else {
            initializePlugin();
        }
    </script>
</body>
</html>
```

## 📊 RAG数据流

### 1. 用户输入处理

```javascript
// 用户输入 "什么是RAG技术？"
handleUserInput("什么是RAG技术？")
  ↓
// 系统自动检索知识库
[RAG检索] → "检索到3个相关片段，相似度0.92"
  ↓
// 构建增强提示
"基于以下知识库内容：[检索内容]，请回答：什么是RAG技术？"
  ↓
// AI生成回复
"根据文档资料，RAG(检索增强生成)是..."
```

### 2. 系统集成点

```javascript
// 检查RAG状态
isRAGEnabled() {
    return this.settings.hasKnowledgeBase && 
           this.ragContext && 
           this.ragContext.resultsCount > 0;
}

// 获取RAG上下文
this.ragContext = {
    resultsCount: 3,        // 检索到的结果数
    averageSimilarity: 0.89, // 平均相似度
    contextLength: 1500,     // 上下文长度
    knowledgeBaseName: "技术文档"
}
```

## 🎨 用户界面增强

### RAG状态指示器

```css
.rag-indicator {
    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
    color: white;
    padding: 8px 12px;
    border-radius: 16px;
    animation: pulse 2s infinite;
}

@keyframes pulse {
    0% { opacity: 1; }
    50% { opacity: 0.7; }
    100% { opacity: 1; }
}
```

### 知识来源展示

```html
<div class="knowledge-source">
    📖 <strong>知识来源:</strong> API文档
    📊 检索了 5 个相关片段，平均相似度 94.2%
    📏 上下文长度: 1,847 字符
</div>
```

## 📝 最佳实践

### 1. RAG检测
```javascript
// 总是检查RAG是否可用
if (this.isRAGEnabled()) {
    // 使用RAG增强的回复
    this.showRAGIndicator();
} else {
    // 降级到普通回复
    console.log('RAG not available, using general knowledge');
}
```

### 2. 错误处理
```javascript
try {
    const response = await this.callAIService(aiRequest);
    this.addMessage('assistant', response.content, ragInfo);
} catch (error) {
    console.error('RAG request failed:', error);
    // 提供友好的错误消息
    this.addMessage('assistant', '知识库查询失败，将使用通用知识回答。');
}
```

### 3. 性能优化
```javascript
// 限制历史消息数量
const recentMessages = this.messages.slice(-10);

// 异步处理RAG检索
async handleUserInput(prompt) {
    this.addMessage('user', prompt);
    
    if (this.isRAGEnabled()) {
        this.showRAGIndicator();
    }
    
    // 异步处理，不阻塞UI
    const response = await this.callAIService(aiRequest);
    // ...
}
```

## 🔧 调试技巧

### 控制台输出
```javascript
console.log('RAG Context:', this.ragContext);
console.log('Knowledge Base:', this.settings.knowledgeBaseName);
console.log('System Prompt:', this.settings.systemPrompt);
```

### RAG信息显示
```javascript
// 在开发模式下显示详细RAG信息
if (window.DEBUG_MODE) {
    this.addMessage('system', `
        RAG Debug Info:
        - Results: ${ragInfo.resultsCount}
        - Similarity: ${ragInfo.averageSimilarity}
        - Context Length: ${ragInfo.contextLength}
    `);
}
```

## 🚀 扩展功能

### 1. 多知识库支持
```javascript
// 未来支持多个知识库
this.multipleKnowledgeBases = this.settings.selectedKnowledgeBases || [];
```

### 2. 实时相似度调整
```javascript
// 根据用户反馈调整相似度阈值
adjustSimilarityThreshold(feedback) {
    if (feedback === 'not_relevant') {
        this.similarityThreshold += 0.1;
    } else if (feedback === 'too_strict') {
        this.similarityThreshold -= 0.1;
    }
}
```

### 3. 引用追踪
```javascript
// 追踪引用的文档片段
trackCitations(ragInfo) {
    this.citations.push({
        timestamp: new Date(),
        knowledgeBase: ragInfo.knowledgeBase,
        resultsCount: ragInfo.resultsCount,
        query: this.lastQuery
    });
}
```

---

这个示例展示了如何创建一个完全集成RAG功能的AI插件，包括用户界面增强、错误处理和性能优化。开发者可以基于此示例创建自己的RAG增强插件。