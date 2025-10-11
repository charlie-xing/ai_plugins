# 插件加载调试指南

## 问题: Modern Chat 插件没有显示任何内容

### 排查步骤

#### 1. 检查Console日志

在Safari开发者工具中查看Console输出，应该看到以下日志：

```
[PluginLoader] Injected settings: {...}
[PluginSDK] v1.0.0 loaded
[PluginBase] Plugin base classes loaded
[ModernChat] 初始化现代聊天插件...
[ModernChat] 加载 marked.js...
[ModernChat] 加载 highlight.js...
[ModernChat] Marked 和 Highlight.js 配置完成
[ModernChat] 初始化完成
[PluginLoader] DOM loaded, plugin ready
```

#### 2. 检查错误

查看是否有以下错误：

- **PluginSDK not found** → SDK文件未正确打包
- **PluginBase not found** → Base文件未正确打包
- **marked is not defined** → CDN加载失败
- **hljs is not defined** → CDN加载失败
- **runPlugin is not a function** → 插件入口函数未定义

#### 3. 手动测试SDK

在Console中运行：

```javascript
// 测试全局对象
console.log('PLUGIN_ID:', window.PLUGIN_ID);
console.log('INITIAL_SETTINGS:', window.INITIAL_SETTINGS);

// 测试SDK
console.log('PluginSDK:', typeof window.PluginSDK);
console.log('PluginSDK.version:', window.PluginSDK?.version);

// 测试基类
console.log('ChatPlugin:', typeof window.ChatPlugin);
console.log('pluginInstance:', typeof window.pluginInstance);

// 测试入口函数
console.log('runPlugin:', typeof window.runPlugin);
```

#### 4. 测试插件实例

```javascript
// 查看插件实例状态
console.log('Plugin initialized:', window.pluginInstance?.isInitialized);
console.log('Plugin name:', window.pluginInstance?.name);
console.log('Messages:', window.pluginInstance?.messages);

// 手动初始化
if (!window.pluginInstance.isInitialized) {
    window.pluginInstance.onInit(PluginSDK.getContext())
        .then(() => console.log('Init complete'))
        .catch(err => console.error('Init failed:', err));
}
```

#### 5. 测试运行插件

```javascript
// 手动调用runPlugin
runPlugin('测试消息')
    .then(() => console.log('runPlugin complete'))
    .catch(err => console.error('runPlugin failed:', err));
```

### 常见问题及解决方案

#### 问题1: SDK未加载

**症状**: `PluginSDK is not defined`

**原因**: SDK文件未打包或路径错误

**解决**:
```bash
# 检查SDK文件
ls -la /Users/xcl/rime/ai_plugins/Sources/ai_plugins/Resources/sdk/

# 重新编译
cd /Users/xcl/rime/ai_plugins
swift build --clean
swift build

# 检查打包后的文件
ls -la .build/debug/ai_plugins_ai_plugins.bundle/Contents/Resources/sdk/
```

#### 问题2: CDN加载失败

**症状**: `marked is not defined` 或 `hljs is not defined`

**原因**: 网络问题或CDN不可用

**解决**:
1. 检查网络连接
2. 在Console中手动加载测试：
```javascript
// 测试marked.js
fetch('https://cdn.jsdelivr.net/npm/marked@11.1.1/marked.min.js')
    .then(r => r.text())
    .then(script => eval(script))
    .then(() => console.log('marked loaded'))
    .catch(err => console.error('marked failed:', err));
```

#### 问题3: 插件未初始化

**症状**: 插件加载但没有UI显示

**原因**: onInit未被调用或失败

**解决**:
```javascript
// 检查初始化状态
console.log('Is initialized:', window.pluginInstance?.isInitialized);

// 查看container
console.log('Container:', window.pluginInstance?.container);
document.getElementById('plugin-' + window.PLUGIN_ID);

// 手动初始化
window.pluginInstance.onInit(PluginSDK.getContext());
```

#### 问题4: 消息未显示

**症状**: 消息发送但UI无变化

**原因**: renderMessage或updateMessageUI未正确实现

**解决**:
```javascript
// 检查messages数组
console.log('Messages:', window.pluginInstance.messages);

// 手动触发渲染
if (window.pluginInstance.messages.length > 0) {
    window.pluginInstance.messages.forEach((msg, idx) => {
        window.pluginInstance.renderMessage(msg, idx);
    });
}
```

### 临时解决方案: 使用旧版插件

如果新插件仍有问题，可以暂时使用旧版test_chat_v5.js：

1. 在插件列表中选择 "Test Chat V5"
2. 该插件已经过充分测试，应该能正常工作

### 创建简化测试插件

创建一个最简单的测试插件来验证架构：

```bash
mkdir -p ~/Library/Application\ Support/ai_plugins/plugins/test_basic
```

**plugin.json:**
```json
{
  "id": "com.test.basic",
  "name": "基础测试",
  "version": "1.0.0",
  "author": "Test",
  "description": "最简单的测试插件",
  "mode": "Chat",
  "entry": "main.js",
  "api": {
    "apiVersion": "1.0",
    "permissions": []
  }
}
```

**main.js:**
```javascript
class TestPlugin extends PluginBase {
    async onInit(context) {
        await super.onInit(context);
        document.body.innerHTML = '<h1>测试插件已加载!</h1>';
        this.log('测试插件初始化完成');
    }

    async onRun(userInput) {
        document.body.innerHTML += `<p>收到输入: ${userInput}</p>`;
        this.log('收到输入: ' + userInput);
    }
}

window.pluginInstance = new TestPlugin();

async function runPlugin(input) {
    if (!window.pluginInstance.isInitialized) {
        await window.pluginInstance.onInit(PluginSDK.getContext());
    }
    await window.pluginInstance.onRun(input);
}
```

### 获取详细日志

在Xcode中运行应用以查看完整日志：

```bash
cd /Users/xcl/rime/ai_plugins
swift run
```

查找以下日志：
- `PluginViewModel: Running plugin`
- `PluginViewModel: Loaded plugin script`
- `PluginViewModel: Successfully called runPlugin`
- `DynamicPluginManager: Found X plugins`

### 联系支持

如果问题仍未解决，提供以下信息：

1. Console中的完整错误日志
2. Xcode/Terminal中的日志输出
3. 使用的macOS版本
4. 应用编译方式(swift build/Xcode)

---

## 快速检查清单

运行测试前检查：

- [ ] SDK文件存在: `ls ~/rime/ai_plugins/Sources/ai_plugins/Resources/sdk/`
- [ ] 插件文件存在: `ls ~/Library/Application\ Support/ai_plugins/plugins/modern_chat/`
- [ ] 应用已重新编译: `swift build`
- [ ] 应用已重启
- [ ] Safari开发者工具已打开
- [ ] 可以访问CDN (jsdelivr.net, cdnjs.com)
- [ ] AI API已配置并可用

---

**调试愉快! 🔧**
