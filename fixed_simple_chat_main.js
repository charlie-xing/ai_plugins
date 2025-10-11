/**
 * Simple Chat Plugin - 使用新插件架构的简单聊天示例（修复版本）
 * @version 1.0.1
 */

class SimpleChatPlugin extends ChatPlugin {
    constructor() {
        super();
        this.name = 'SimpleChatPlugin';
        this.version = '1.0.1';
    }

    async onInit(context) {
        await super.onInit(context);
        this.log('插件初始化完成');
        this.setupUI();
    }

    setupUI() {
        // 添加样式
        this.addStyles(`
            * {
                margin: 0;
                padding: 0;
                box-sizing: border-box;
            }

            body {
                font-family: -apple-system, BlinkMacSystemFont, 'SF Pro Display', sans-serif;
                background: #f5f5f7;
                color: #1d1d1f;
                padding: 20px;
                line-height: 1.6;
            }

            @media (prefers-color-scheme: dark) {
                body {
                    background: #000000;
                    color: #f5f5f7;
                }
            }

            #chat-container {
                max-width: 800px;
                margin: 0 auto;
            }

            .header {
                text-align: center;
                margin-bottom: 30px;
            }

            .header h1 {
                font-size: 32px;
                font-weight: 700;
                background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                -webkit-background-clip: text;
                -webkit-text-fill-color: transparent;
                background-clip: text;
            }

            .header p {
                font-size: 14px;
                color: #86868b;
                margin-top: 8px;
            }

            .message {
                margin-bottom: 24px;
                opacity: 0;
                animation: fadeIn 0.3s ease-in forwards;
            }

            @keyframes fadeIn {
                to { opacity: 1; }
            }

            .message-header {
                display: flex;
                align-items: center;
                margin-bottom: 8px;
                font-size: 13px;
                font-weight: 500;
            }

            .avatar {
                width: 32px;
                height: 32px;
                border-radius: 50%;
                margin-right: 10px;
                display: flex;
                align-items: center;
                justify-content: center;
                font-size: 18px;
                overflow: hidden;
                flex-shrink: 0;
            }

            .avatar img {
                width: 100%;
                height: 100%;
                object-fit: cover;
            }

            .user .avatar {
                background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            }

            .assistant .avatar {
                background: linear-gradient(135deg, #f093fb 0%, #f5576c 100%);
                font-family: -apple-system, BlinkMacSystemFont, 'SF Pro Display', sans-serif;
                font-weight: 600;
                font-size: 14px;
                color: white;
            }

            .message-content {
                padding-left: 42px;
                font-size: 15px;
                white-space: pre-wrap;
                word-wrap: break-word;
            }

            .message-content p {
                margin-bottom: 12px;
            }

            .streaming-cursor {
                display: inline-block;
                width: 2px;
                height: 1em;
                background-color: currentColor;
                margin-left: 2px;
                animation: blink 1s infinite;
                vertical-align: text-bottom;
            }

            @keyframes blink {
                0%, 50% { opacity: 1; }
                51%, 100% { opacity: 0; }
            }

            .empty-state {
                text-align: center;
                padding: 60px 20px;
                color: #86868b;
            }

            .empty-state-icon {
                font-size: 64px;
                margin-bottom: 20px;
            }

            .empty-state-text {
                font-size: 18px;
                font-weight: 500;
                margin-bottom: 8px;
            }

            .empty-state-hint {
                font-size: 14px;
            }
        `);

        // 设置HTML结构
        this.setHTML(`
            <div class="header">
                <h1>💬 简单聊天</h1>
                <p>基于新插件架构的聊天示例</p>
            </div>
            <div id="chat-container"></div>
        `);

        // 如果没有消息，显示空状态
        if (this.messages.length === 0) {
            this.showEmptyState();
        }
    }

    showEmptyState() {
        const container = document.getElementById('chat-container');
        if (container && this.messages.length === 0) {
            container.innerHTML = `
                <div class="empty-state">
                    <div class="empty-state-icon">👋</div>
                    <div class="empty-state-text">欢迎使用简单聊天插件</div>
                    <div class="empty-state-hint">在下方输入框输入消息开始对话</div>
                </div>
            `;
        }
    }

    renderMessage(message, index) {
        let container = document.getElementById('chat-container');
        if (!container) {
            container = document.createElement('div');
            container.id = 'chat-container';
            this.container.appendChild(container);
        }

        // 清除空状态
        if (index === 0) {
            container.innerHTML = '';
        }

        const messageDiv = document.createElement('div');
        messageDiv.className = `message ${message.role}`;
        messageDiv.dataset.index = index;

        const settings = this.getSettings();
        let avatar, name;

        if (message.role === 'user') {
            const userAvatar = settings.userAvatar || '👤';
            name = settings.userName || 'User';

            // 处理头像
            if (userAvatar.startsWith('data:') || userAvatar.startsWith('http')) {
                avatar = `<img src="${userAvatar}" alt="${name}">`;
            } else {
                avatar = userAvatar;
            }
        } else {
            name = settings.selectedModelName || 'Assistant';
            avatar = name.charAt(0).toUpperCase();
        }

        messageDiv.innerHTML = `
            <div class="message-header">
                <div class="avatar">${avatar}</div>
                <span>${name}</span>
            </div>
            <div class="message-content"></div>
        `;

        container.appendChild(messageDiv);
        this.updateMessageUI(index);

        // 滚动到底部
        window.scrollTo({
            top: document.body.scrollHeight,
            behavior: 'smooth'
        });
    }

    updateMessageUI(index) {
        const message = this.messages[index];
        const messageDiv = document.querySelector(`.message[data-index="${index}"]`);

        if (messageDiv) {
            const contentDiv = messageDiv.querySelector('.message-content');
            const cursor = message.streaming ? '<span class="streaming-cursor"></span>' : '';
            contentDiv.innerHTML = message.content + cursor;

            // 滚动到底部
            window.scrollTo({
                top: document.body.scrollHeight,
                behavior: 'smooth'
            });
        }
    }

    // 重写sendMessage方法以修复流式响应问题
    async sendMessage(userInput) {
        this.log(`发送消息: ${userInput}`);

        // 添加用户消息
        this.addUserMessage(userInput);

        // 开始助手响应
        this.startAssistantMessage();

        // 构建对话历史（排除当前流式消息）
        const conversationHistory = this.messages
            .filter(msg => !msg.streaming)
            .map(msg => ({
                role: msg.role,
                content: msg.content
            }));

        // 调用AI API - 直接传递回调函数而不依赖全局变量
        PluginSDK.AI.streamChat({
            message: userInput,
            messages: conversationHistory,
            onChunk: (chunk) => {
                this.log(`收到数据块: ${chunk}`);
                if (this.currentStreamingMessage) {
                    this.currentStreamingMessage.content += chunk;
                    this.updateMessageUI(this.messages.length - 1);
                }
            },
            onComplete: () => {
                this.log('流式响应完成');
                if (this.currentStreamingMessage) {
                    this.currentStreamingMessage.streaming = false;
                    this.currentStreamingMessage = null;
                    this.updateMessageUI(this.messages.length - 1);
                }
            },
            onError: (error) => {
                this.error(`流式响应错误: ${error}`);
                if (this.currentStreamingMessage) {
                    this.currentStreamingMessage.content = `错误: ${error}`;
                    this.currentStreamingMessage.streaming = false;
                    this.currentStreamingMessage = null;
                    this.updateMessageUI(this.messages.length - 1);
                }
            }
        });
    }

    // 重写setupMessageHandlers以避免覆盖全局回调
    setupMessageHandlers() {
        // 不设置全局回调，而是在sendMessage中直接处理
        this.log('跳过设置全局消息处理器，使用直接回调方式');
    }

    async onRun(userInput) {
        this.log(`收到用户输入: ${userInput}`);
        await this.sendMessage(userInput);
    }

    async onDestroy() {
        this.log('插件即将销毁');
        await super.onDestroy();
    }
}

// 插件入口函数
window.runPlugin = async function(userInput) {
    // 创建实例（如果不存在）
    if (!window.pluginInstance) {
        console.log('[SimpleChat] Creating plugin instance...');
        window.pluginInstance = new SimpleChatPlugin();
    }

    // 初始化（如果未初始化）
    if (!window.pluginInstance.isInitialized) {
        console.log('[SimpleChat] Initializing...');
        await window.pluginInstance.onInit(PluginSDK.getContext());
    }

    console.log('[SimpleChat] Running with input:', userInput);
    await window.pluginInstance.onRun(userInput);
    return undefined;
};
