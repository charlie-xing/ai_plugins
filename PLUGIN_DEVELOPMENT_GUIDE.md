# AI Plugins 插件开发指南

> 版本: 1.0.0
> 更新日期: 2025-01-14

## 📖 目录

1. [简介](#简介)
2. [快速开始](#快速开始)
3. [插件架构](#插件架构)
4. [PluginSDK API参考](#pluginsdk-api参考)
5. [插件基类](#插件基类)
6. [完整示例](#完整示例)
7. [最佳实践](#最佳实践)
8. [常见问题](#常见问题)

---

## 简介

AI Plugins 提供了一个灵活的插件系统,允许开发者通过 JavaScript 创建自定义插件,无需重新编译应用即可动态加载和更新。

### 核心特性

- ✅ **动态加载**: 插件存放在用户目录,无需重新编译
- ✅ **标准化API**: 统一的 PluginSDK 提供完整的功能接口
- ✅ **类型化开发**: 清晰的插件基类和生命周期管理
- ✅ **权限管理**: 细粒度的权限控制系统
- ✅ **热重载**: 支持插件热重载(开发模式)
- ✅ **向后兼容**: 兼容旧版插件格式

---

## 快速开始

### 1. 创建插件目录

所有用户插件存放在以下目录:

```
~/Library/Application Support/ai_plugins/plugins/
```

创建你的插件文件夹:

```bash
mkdir -p ~/Library/Application\ Support/ai_plugins/plugins/my_plugin
cd ~/Library/Application\ Support/ai_plugins/plugins/my_plugin
```

### 2. 创建插件清单 (plugin.json)

`plugin.json` 是插件的元数据文件:

```json
{
  "id": "com.yourname.my_plugin",
  "name": "我的插件",
  "version": "1.0.0",
  "author": "Your Name",
  "description": "插件描述",
  "mode": "Chat",
  "entry": "main.js",
  "api": {
    "apiVersion": "1.0",
    "minAppVersion": "1.0.0",
    "permissions": [
      "ai_stream",
      "settings_read"
    ],
    "lifecycle": {
      "autoInit": true,
      "singleton": true
    }
  }
}
```

**字段说明:**

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `id` | string | ✅ | 插件唯一标识符(建议使用反向域名) |
| `name` | string | ✅ | 插件显示名称 |
| `version` | string | ✅ | 版本号(语义化版本) |
| `author` | string | ✅ | 作者名称 |
| `description` | string | ✅ | 插件描述 |
| `mode` | string | ✅ | 插件模式: `Chat`, `BOT`, `Agent`, `Role` |
| `entry` | string | ✅ | 入口JavaScript文件名 |
| `api.apiVersion` | string | ✅ | 使用的API版本 |
| `api.permissions` | array | ✅ | 权限列表 |
| `api.lifecycle` | object | ❌ | 生命周期配置 |

**可用权限:**

- `ai_stream`: 调用AI流式API
- `settings_read`: 读取应用设置
- `python_exec`: 执行Python脚本
- `file_system`: 文件系统访问
- `command_exec`: 执行系统命令

### 3. 创建插件脚本 (main.js)

创建最简单的插件:

```javascript
// 继承ChatPlugin基类
class MyPlugin extends ChatPlugin {
    constructor() {
        super();
        this.name = 'MyPlugin';
        this.version = '1.0.0';
    }

    async onInit(context) {
        await super.onInit(context);
        this.log('插件初始化完成');
        this.setupUI();
    }

    setupUI() {
        // 设置UI界面
        this.addStyles(`
            body {
                font-family: -apple-system, BlinkMacSystemFont, sans-serif;
                padding: 20px;
            }
        `);

        this.setHTML('<div id="chat-container"></div>');
    }

    async onRun(userInput) {
        this.log(`收到输入: ${userInput}`);
        await this.sendMessage(userInput);
    }
}

// 入口函数 - 必须挂载到 window 对象
window.runPlugin = async function(userInput) {
    // 创建实例（如果不存在）
    if (!window.pluginInstance) {
        window.pluginInstance = new MyPlugin();
    }

    // 初始化（如果未初始化）
    if (!window.pluginInstance.isInitialized) {
        await window.pluginInstance.onInit(PluginSDK.getContext());
    }

    await window.pluginInstance.onRun(userInput);
    return undefined;
};
```

### 4. 测试插件

1. 重启应用或使用热重载功能
2. 在插件列表中找到你的插件
3. 点击运行测试

---

## 插件架构

### 目录结构

```
~/Library/Application Support/ai_plugins/
├── plugins/                          # 用户插件目录
│   ├── my_chat/
│   │   ├── plugin.json              # 插件元数据
│   │   ├── main.js                  # 插件主文件
│   │   ├── styles.css               # 可选样式
│   │   └── assets/                  # 可选资源
│   └── my_tool/
│       ├── plugin.json
│       ├── main.js
│       └── script.py                # 支持的Python脚本
```

### 加载流程

```
1. DynamicPluginManager 扫描插件目录
   ↓
2. 解析 plugin.json 元数据
   ↓
3. 验证权限和API版本
   ↓
4. 加载 PluginSDK.js 和 PluginBase.js
   ↓
5. 加载插件 main.js
   ↓
6. 调用插件生命周期方法
   ↓
7. 插件就绪,可接收用户输入
```

---

## PluginSDK API参考

### 全局对象

插件可以访问以下全局对象:

```javascript
window.PluginSDK      // SDK主对象
window.PluginBase     // 插件基类
window.ChatPlugin     // 聊天插件基类
window.UIPlugin       // UI插件基类
window.PLUGIN_ID      // 当前插件ID
window.TAB_ID         // 当前标签页ID
window.INITIAL_SETTINGS // 应用设置
```

### PluginSDK.getContext()

获取插件上下文信息。

```javascript
const context = PluginSDK.getContext();
// {
//   settings: {...},      // 应用设置
//   pluginId: "...",     // 插件ID
//   tabId: "...",        // 标签页ID
//   apiVersion: "1.0.0"  // API版本
// }
```

### PluginSDK.AI

与AI模型交互的API。

#### streamChat(params)

调用AI流式聊天API。

**参数:**

```javascript
PluginSDK.AI.streamChat({
  message: '你好',              // 当前消息
  messages: [                   // 历史消息(可选)
    {role: 'user', content: '之前的消息'},
    {role: 'assistant', content: 'AI回复'}
  ],
  onChunk: (chunk) => {         // 接收数据块
    console.log(chunk);
  },
  onComplete: () => {           // 完成回调
    console.log('完成');
  },
  onError: (error) => {         // 错误回调
    console.error(error);
  }
});
```

**示例:**

```javascript
async sendMessage(userInput) {
    this.addUserMessage(userInput);
    this.startAssistantMessage();

    PluginSDK.AI.streamChat({
        message: userInput,
        messages: this.conversationHistory,
        onChunk: (chunk) => this.appendToMessage(chunk),
        onComplete: () => this.finalizeMessage(),
        onError: (err) => this.showError(err)
    });
}
```

### PluginSDK.Settings

应用设置相关API。

#### get(callback)

获取应用设置。

```javascript
PluginSDK.Settings.get((settings) => {
    console.log('API端点:', settings.apiEndpoint);
    console.log('用户名:', settings.userName);
    console.log('模型:', settings.selectedModelName);
});
```

### PluginSDK.Python

执行Python脚本。

#### runScript(params)

运行Python脚本文件。

**参数:**

```javascript
PluginSDK.Python.runScript({
    script: 'process_image.py',     // 脚本文件名
    input: {                         // 输入数据(会序列化为JSON)
        image: 'base64data...',
        prompt: 'make it blue'
    },
    onOutput: (output) => {          // 接收输出
        const result = JSON.parse(output);
        console.log('结果:', result);
    },
    onError: (error) => {            // 错误处理
        console.error('错误:', error);
    }
});
```

**Python脚本示例:**

```python
import sys
import json

# 从stdin读取输入
input_data = json.load(sys.stdin)

# 处理数据
result = {
    'status': 'complete',
    'output': 'processed data...'
}

# 输出结果到stdout
print(json.dumps(result))
```

### PluginSDK.Command

执行系统命令。

#### execute(params)

执行系统命令(返回Promise)。

```javascript
PluginSDK.Command.execute({
    command: 'ls',
    args: ['-la', '/tmp']
}).then(result => {
    console.log('输出:', result.output);
}).catch(error => {
    console.error('错误:', error);
});
```

### PluginSDK.Log

日志输出API。

```javascript
PluginSDK.Log.info('信息日志');
PluginSDK.Log.warn('警告日志');
PluginSDK.Log.error('错误日志');
PluginSDK.Log.debug('调试日志');
```

### PluginSDK.Storage

本地存储API(每个插件独立的存储空间)。

```javascript
// 存储数据
PluginSDK.Storage.set('user_preference', {
    theme: 'dark',
    fontSize: 14
});

// 读取数据
const pref = PluginSDK.Storage.get('user_preference', {theme: 'light'});

// 删除数据
PluginSDK.Storage.remove('user_preference');

// 清空所有数据
PluginSDK.Storage.clear();
```

### PluginSDK.UI

UI工具API。

#### showLoading(message)

显示加载遮罩。

```javascript
PluginSDK.UI.showLoading('处理中...');
// 处理完成后
PluginSDK.UI.hideLoading();
```

#### showToast(message, type, duration)

显示Toast提示。

```javascript
PluginSDK.UI.showToast('保存成功!', 'success', 3000);
PluginSDK.UI.showToast('发生错误', 'error');
PluginSDK.UI.showToast('警告信息', 'warning');
PluginSDK.UI.showToast('提示信息', 'info');
```

### PluginSDK.Utils

工具函数。

```javascript
// HTML转义
const safe = PluginSDK.Utils.escapeHtml('<script>alert("xss")</script>');

// 防抖
const debouncedFn = PluginSDK.Utils.debounce(() => {
    console.log('执行');
}, 300);

// 节流
const throttledFn = PluginSDK.Utils.throttle(() => {
    console.log('执行');
}, 1000);

// 格式化文件大小
const size = PluginSDK.Utils.formatFileSize(1024000); // "1000.00 KB"
```

---

## 插件基类

### PluginBase

所有插件的基类,提供生命周期管理。

```javascript
class MyPlugin extends PluginBase {
    constructor() {
        super();
        this.name = 'MyPlugin';
        this.version = '1.0.0';
    }

    // 生命周期方法
    async onInit(context) {
        await super.onInit(context);
        // 初始化逻辑
    }

    async onRun(userInput) {
        // 运行逻辑(必须实现)
    }

    async onPause() {
        // 暂停逻辑
    }

    async onResume() {
        // 恢复逻辑
    }

    async onDestroy() {
        await super.onDestroy();
        // 清理逻辑
    }

    // 辅助方法
    getSettings() {
        return this.context?.settings || {};
    }

    setState(key, value) {
        this.state[key] = value;
    }

    getState(key, defaultValue) {
        return this.state[key] !== undefined ? this.state[key] : defaultValue;
    }

    log(message) {
        PluginSDK.Log.info(`[${this.name}] ${message}`);
    }

    error(message) {
        PluginSDK.Log.error(`[${this.name}] ${message}`);
    }
}
```

### ChatPlugin

聊天类插件基类,继承自PluginBase。

```javascript
class MyChatPlugin extends ChatPlugin {
    constructor() {
        super();
        this.name = 'MyChatPlugin';
    }

    async onInit(context) {
        await super.onInit(context);
        this.setupUI(); // 设置UI
    }

    setupUI() {
        // 自定义UI设置
        this.addStyles('/* CSS */');
        this.setHTML('<div id="chat"></div>');
    }

    // 重写消息渲染方法
    renderMessage(message, index) {
        // 自定义消息渲染
    }

    updateMessageUI(index) {
        // 自定义UI更新
    }

    // 发送消息(已实现)
    async sendMessage(userInput) {
        // 由基类实现,自动处理流式响应
    }

    // 清空对话
    clearMessages() {
        super.clearMessages();
    }
}
```

**ChatPlugin提供的属性:**

- `messages`: 消息数组
- `currentStreamingMessage`: 当前流式消息

**ChatPlugin提供的方法:**

- `addUserMessage(content)`: 添加用户消息
- `startAssistantMessage()`: 开始助手消息
- `sendMessage(userInput)`: 发送消息到AI
- `renderMessage(message, index)`: 渲染消息(需重写)
- `updateMessageUI(index)`: 更新消息UI(需重写)
- `clearMessages()`: 清空对话

### UIPlugin

UI类插件基类,提供UI构建辅助。

```javascript
class MyUIPlugin extends UIPlugin {
    async onInit(context) {
        await super.onInit(context);
        this.buildUI();
    }

    buildUI() {
        // 添加样式
        this.addStyles(`
            .my-button {
                padding: 10px 20px;
                background: #007aff;
                color: white;
                border: none;
                border-radius: 6px;
            }
        `);

        // 设置HTML
        this.setHTML(`
            <div>
                <h1>我的UI插件</h1>
                <button class="my-button">点击</button>
            </div>
        `);
    }

    async onRun(userInput) {
        // 处理用户输入
    }
}
```

---

## 完整示例

### 示例1: 简单计数器插件

**plugin.json:**

```json
{
  "id": "com.example.counter",
  "name": "计数器",
  "version": "1.0.0",
  "author": "Example",
  "description": "一个简单的计数器插件",
  "mode": "Chat",
  "entry": "main.js",
  "api": {
    "apiVersion": "1.0",
    "permissions": ["settings_read"]
  }
}
```

**main.js:**

```javascript
class CounterPlugin extends UIPlugin {
    constructor() {
        super();
        this.name = 'CounterPlugin';
        this.count = PluginSDK.Storage.get('count', 0);
    }

    async onInit(context) {
        await super.onInit(context);
        this.buildUI();
    }

    buildUI() {
        this.addStyles(`
            .counter {
                text-align: center;
                padding: 40px;
                font-family: -apple-system, BlinkMacSystemFont, sans-serif;
            }
            .counter h1 {
                font-size: 72px;
                margin: 20px 0;
            }
            .counter button {
                padding: 12px 24px;
                margin: 0 10px;
                font-size: 16px;
                border: none;
                border-radius: 8px;
                cursor: pointer;
                background: #007aff;
                color: white;
            }
            .counter button:hover {
                background: #0051d5;
            }
        `);

        this.renderCounter();
    }

    renderCounter() {
        this.setHTML(`
            <div class="counter">
                <h2>计数器</h2>
                <h1 id="count">${this.count}</h1>
                <div>
                    <button onclick="window.pluginInstance.increment()">+</button>
                    <button onclick="window.pluginInstance.decrement()">-</button>
                    <button onclick="window.pluginInstance.reset()">重置</button>
                </div>
            </div>
        `);
    }

    increment() {
        this.count++;
        this.save();
        this.update();
    }

    decrement() {
        this.count--;
        this.save();
        this.update();
    }

    reset() {
        this.count = 0;
        this.save();
        this.update();
    }

    save() {
        PluginSDK.Storage.set('count', this.count);
    }

    update() {
        document.getElementById('count').textContent = this.count;
    }

    async onRun(userInput) {
        // 不需要处理用户输入
    }
}

// 入口函数 - 必须挂载到 window 对象
window.runPlugin = async function(userInput) {
    if (!window.pluginInstance) {
        window.pluginInstance = new CounterPlugin();
    }
    if (!window.pluginInstance.isInitialized) {
        await window.pluginInstance.onInit(PluginSDK.getContext());
    }
    await window.pluginInstance.onRun(userInput);
};
```

### 示例2: Markdown预览插件

```javascript
class MarkdownPlugin extends UIPlugin {
    async onInit(context) {
        await super.onInit(context);
        this.buildUI();
    }

    buildUI() {
        this.addStyles(`
            .markdown-preview {
                padding: 20px;
                font-family: -apple-system, BlinkMacSystemFont, sans-serif;
            }
            .markdown-output {
                background: #f5f5f7;
                padding: 20px;
                border-radius: 8px;
                margin-top: 20px;
            }
        `);

        this.setHTML(`
            <div class="markdown-preview">
                <h2>Markdown预览</h2>
                <textarea id="markdown-input"
                          style="width:100%;height:200px;padding:10px;font-family:monospace;"
                          placeholder="输入Markdown文本..."></textarea>
                <div id="markdown-output" class="markdown-output"></div>
            </div>
        `);

        document.getElementById('markdown-input').addEventListener('input',
            PluginSDK.Utils.debounce((e) => this.preview(e.target.value), 300)
        );
    }

    preview(markdown) {
        PluginSDK.AI.streamChat({
            message: `请将以下Markdown文本转换为HTML:\n\n${markdown}`,
            onChunk: (chunk) => {
                const output = document.getElementById('markdown-output');
                output.innerHTML += chunk;
            },
            onError: (err) => {
                PluginSDK.UI.showToast('预览失败: ' + err, 'error');
            }
        });
    }

    async onRun(userInput) {
        document.getElementById('markdown-input').value = userInput;
        this.preview(userInput);
    }
}

// 入口函数 - 必须挂载到 window 对象
window.runPlugin = async function(input) {
    if (!window.pluginInstance) {
        window.pluginInstance = new MarkdownPlugin();
    }
    if (!window.pluginInstance.isInitialized) {
        await window.pluginInstance.onInit(PluginSDK.getContext());
    }
    await window.pluginInstance.onRun(input);
};
```

---

## 最佳实践

### 1. 错误处理

始终使用try-catch包裹异步操作:

```javascript
async onRun(userInput) {
    try {
        await this.processInput(userInput);
    } catch (error) {
        this.error(`处理失败: ${error.message}`);
        PluginSDK.UI.showToast('操作失败', 'error');
    }
}
```

### 2. 资源清理

在onDestroy中清理资源:

```javascript
async onDestroy() {
    // 清理定时器
    if (this.timer) {
        clearInterval(this.timer);
    }

    // 移除事件监听
    window.removeEventListener('resize', this.handleResize);

    await super.onDestroy();
}
```

### 3. 状态管理

使用setState/getState管理插件状态:

```javascript
// 设置状态
this.setState('currentPage', 1);
this.setState('filters', {category: 'all'});

// 读取状态
const page = this.getState('currentPage', 1);
const filters = this.getState('filters', {});
```

### 4. 性能优化

使用防抖和节流优化频繁操作:

```javascript
// 防抖: 输入结束后才执行
const debouncedSearch = PluginSDK.Utils.debounce((query) => {
    this.search(query);
}, 500);

// 节流: 限制执行频率
const throttledScroll = PluginSDK.Utils.throttle(() => {
    this.handleScroll();
}, 100);
```

### 5. 用户体验

提供及时的用户反馈:

```javascript
async saveData() {
    PluginSDK.UI.showLoading('保存中...');

    try {
        await this.performSave();
        PluginSDK.UI.hideLoading();
        PluginSDK.UI.showToast('保存成功!', 'success');
    } catch (error) {
        PluginSDK.UI.hideLoading();
        PluginSDK.UI.showToast('保存失败', 'error');
    }
}
```

### 6. 日志记录

使用统一的日志系统:

```javascript
this.log('开始处理数据');
this.log(`处理了${count}条记录`);
this.error('处理失败: ' + error.message);
```

---

## 常见问题

### Q: 插件没有出现在列表中?

**A:** 检查以下几点:
1. plugin.json格式是否正确
2. 插件目录位置是否正确
3. id字段是否唯一
4. 重启应用

### Q: 如何调试插件?

**A:**
1. 在Safari中启用开发者菜单
2. 右键WebView选择"检查元素"
3. 使用console.log输出调试信息

### Q: 如何访问外部库?

**A:** 可以在setupUI中动态加载:

```javascript
setupUI() {
    // 加载外部库
    const script = document.createElement('script');
    script.src = 'https://cdn.jsdelivr.net/npm/marked/marked.min.js';
    script.onload = () => {
        console.log('Marked.js loaded');
    };
    document.head.appendChild(script);
}
```

### Q: 如何保存大量数据?

**A:** 使用Storage API或调用Python脚本保存到文件:

```javascript
// 方式1: Storage API(适合小数据)
PluginSDK.Storage.set('myData', largeObject);

// 方式2: Python脚本(适合大数据)
PluginSDK.Python.runScript({
    script: 'save_data.py',
    input: {data: largeObject, path: '/tmp/data.json'}
});
```

### Q: 如何实现插件间通信?

**A:** 使用Storage API作为共享存储:

```javascript
// 插件A写入
PluginSDK.Storage.set('shared_data', {value: 123});

// 插件B读取
const data = PluginSDK.Storage.get('shared_data');
```

### Q: 如何更新插件?

**A:**
1. 修改插件文件
2. 更新plugin.json中的version字段
3. 重启应用或使用热重载

---

## 附录

### 插件模式说明

| 模式 | 说明 | 适用场景 |
|------|------|----------|
| Chat | 聊天模式 | 对话式交互,支持多轮对话 |
| BOT | 机器人模式 | 自动化任务,无需用户输入 |
| Agent | 代理模式 | 复杂的多步骤任务 |
| Role | 角色模式 | 特定角色扮演 |

### 权限说明

| 权限 | 说明 | 风险等级 |
|------|------|----------|
| ai_stream | 调用AI API | 低 |
| settings_read | 读取应用设置 | 低 |
| python_exec | 执行Python脚本 | 中 |
| command_exec | 执行系统命令 | 高 |
| file_system | 文件系统访问 | 高 |

### 更新日志

#### v1.0.0 (2025-01-14)
- ✅ 初始版本
- ✅ PluginSDK API
- ✅ 插件基类系统
- ✅ 动态加载机制
- ✅ 权限管理系统

---

**祝您开发愉快! 🎉**

如有问题,请在GitHub提交Issue: https://github.com/yourusername/ai_plugins/issues
