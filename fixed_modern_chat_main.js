/**
 * Modern Chat Plugin v6.0.1
 * 基于新插件架构的现代化聊天插件（修复版本）
 * - 使用 ChatPlugin 基类
 * - Markdown 渲染
 * - 代码高亮
 * - 流式响应（已修复）
 * - 会话保存
 */

class ModernChatPlugin extends ChatPlugin {
    constructor() {
        super();
        this.name = 'ModernChat';
        this.version = '6.0.1';
        this.currentTheme = null;
        this.themeStyleElement = null;
        this.autoScroll = true;
        this.userScrolling = false;
        this.scrollTimeout = null;
    }

    async onInit(context) {
        await super.onInit(context);
        this.log('初始化现代聊天插件...');

        // 加载依赖库
        await this.loadDependencies();

        // 设置UI
        this.setupUI();

        // 设置滚动监听
        this.setupScrollListener();

        this.log('初始化完成');
    }

    async loadDependencies() {
        // 加载 marked.js
        if (!window.marked) {
            this.log('加载 marked.js...');
            await this.loadScript('https://cdn.jsdelivr.net/npm/marked@11.1.1/marked.min.js');
        }

        // 加载 highlight.js
        if (!window.hljs) {
            this.log('加载 highlight.js...');
            await this.loadScript('https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/highlight.min.js');
        }

        // 加载主题并设置监听
        this.loadHighlightTheme();
        this.setupThemeListener();

        // 配置 marked
        if (window.marked && window.hljs) {
            const renderer = new marked.Renderer();
            const originalCode = renderer.code.bind(renderer);

            renderer.code = function(code, language) {
                const html = originalCode(code, language);
                if (language) {
                    return html.replace('<code>', `<code class="language-${language}">`);
                }
                return html;
            };

            marked.setOptions({
                breaks: true,
                gfm: true,
                renderer: renderer,
                highlight: function(code, lang) {
                    return code; // 不在解析时高亮，流式完成后再高亮
                }
            });

            this.log('Marked 和 Highlight.js 配置完成');
        }
    }

    loadScript(src) {
        return new Promise((resolve, reject) => {
            const script = document.createElement('script');
            script.src = src;
            script.onload = resolve;
            script.onerror = reject;
            document.head.appendChild(script);
        });
    }

    isDarkMode() {
        return window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)').matches;
    }

    loadHighlightTheme() {
        const isDark = this.isDarkMode();
        const theme = isDark ? 'atom-one-dark' : 'atom-one-light';

        if (this.themeStyleElement) {
            this.themeStyleElement.remove();
        }

        const link = document.createElement('link');
        link.rel = 'stylesheet';
        link.id = 'hljs-theme';
        link.href = `https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/styles/${theme}.min.css`;
        document.head.appendChild(link);
        this.themeStyleElement = link;
        this.currentTheme = theme;

        this.log(`加载主题: ${theme}`);
    }

    setupThemeListener() {
        const mediaQuery = window.matchMedia('(prefers-color-scheme: dark)');
        mediaQuery.addEventListener('change', (e) => {
            this.log(`主题切换: ${e.matches ? 'dark' : 'light'}`);
            this.loadHighlightTheme();
            this.rehighlightAllCode();
        });
    }

    rehighlightAllCode() {
        if (!window.hljs) return;

        document.querySelectorAll('pre code').forEach((codeBlock) => {
            codeBlock.className = codeBlock.className
                .split(' ')
                .filter(cls => !cls.startsWith('hljs') || cls.startsWith('language-'))
                .join(' ');

            hljs.highlightElement(codeBlock);
        });

        this.log('重新高亮所有代码块');
    }

    setupScrollListener() {
        window.addEventListener('scroll', () => {
            if (this.scrollTimeout) {
                clearTimeout(this.scrollTimeout);
            }

            const isNearBottom = (window.innerHeight + window.scrollY) >= (document.body.scrollHeight - 100);

            if (isNearBottom) {
                this.autoScroll = true;
            } else {
                this.autoScroll = false;
            }
        });
    }

    setupUI() {
        // 添加样式
        this.addStyles(`
            * { margin: 0; padding: 0; box-sizing: border-box; }

            body {
                font-family: -apple-system, BlinkMacSystemFont, 'SF Pro Display', sans-serif;
                background: transparent;
                color: #1a1a1a;
                padding: 20px;
                line-height: 1.6;
            }

            @media (prefers-color-scheme: dark) {
                body { color: #e8e8e8; }
            }

            #chat-container {
                max-width: 800px;
                margin: 0 auto;
            }

            .message {
                margin-bottom: 24px;
                opacity: 0;
                animation: fadeIn 0.3s ease-in forwards;
            }

            @keyframes fadeIn { to { opacity: 1; } }

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
            }

            .message-content p {
                margin-bottom: 12px;
                white-space: pre-wrap;
            }

            .message-content pre {
                background: rgba(135,131,120,0.08);
                border-radius: 8px;
                padding: 16px;
                margin: 12px 0;
                position: relative;
                overflow-x: auto;
            }

            @media (prefers-color-scheme: dark) {
                .message-content pre {
                    background: rgba(255,255,255,0.05);
                }
            }

            .message-content code {
                font-family: "SF Mono", Monaco, Consolas, monospace;
                font-size: 13px;
            }

            .message-content pre code {
                background: none;
                padding: 0;
            }

            .message-content :not(pre) > code {
                background: rgba(135,131,120,0.15);
                color: #eb5757;
                padding: 2px 6px;
                border-radius: 3px;
            }

            .copy-button {
                position: absolute;
                top: 8px;
                right: 8px;
                background: white;
                border: 1.5px solid #6b7280;
                padding: 0;
                border-radius: 50%;
                cursor: pointer;
                opacity: 0;
                transition: opacity 0.2s, background 0.2s, border-color 0.2s, transform 0.1s;
                display: flex;
                align-items: center;
                justify-content: center;
                width: 32px;
                height: 32px;
            }

            @media (prefers-color-scheme: dark) {
                .copy-button {
                    background: #1f2937;
                    border-color: #9ca3af;
                }
            }

            .copy-button svg {
                width: 16px;
                height: 16px;
                stroke: #4b5563;
            }

            @media (prefers-color-scheme: dark) {
                .copy-button svg {
                    stroke: #d1d5db;
                }
            }

            .message-content pre:hover .copy-button {
                opacity: 1;
            }

            .copy-button:hover {
                background: #f3f4f6;
                border-color: #4b5563;
                transform: scale(1.05);
            }

            @media (prefers-color-scheme: dark) {
                .copy-button:hover {
                    background: #374151;
                    border-color: #d1d5db;
                }
            }

            .copy-button:hover svg {
                stroke: #1f2937;
            }

            @media (prefers-color-scheme: dark) {
                .copy-button:hover svg {
                    stroke: #f3f4f6;
                }
            }

            .copy-button.copied {
                background: #f3f4f6;
                border-color: #4b5563;
            }

            @media (prefers-color-scheme: dark) {
                .copy-button.copied {
                    background: #374151;
                    border-color: #d1d5db;
                }
            }

            .copy-button.copied svg {
                stroke: #1f2937;
            }

            @media (prefers-color-scheme: dark) {
                .copy-button.copied svg {
                    stroke: #f3f4f6;
                }
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
        `);

        // 设置HTML结构
        this.setHTML('<div id="chat-container"></div>');
    }

    renderMessage(message, index) {
        let container = document.getElementById('chat-container');
        if (!container) {
            container = document.createElement('div');
            container.id = 'chat-container';
            this.container.appendChild(container);
        }

        const messageDiv = document.createElement('div');
        messageDiv.className = `message ${message.role}`;
        messageDiv.dataset.index = index;

        const settings = this.getSettings();
        let avatar, name;

        if (message.role === 'user') {
            const userAvatar = settings.userAvatar || '👤';
            name = settings.userName || 'User';

            if (userAvatar.startsWith('/')) {
                const encodedPath = encodeURI(userAvatar);
                avatar = `<img src="file://${encodedPath}" alt="${name}" onerror="this.parentElement.innerHTML='👤';">`;
            } else if (userAvatar.startsWith('file://')) {
                const pathOnly = userAvatar.substring(7);
                const encodedPath = encodeURI(pathOnly);
                avatar = `<img src="file://${encodedPath}" alt="${name}" onerror="this.parentElement.innerHTML='👤';">`;
            } else if (userAvatar.startsWith('http') || userAvatar.startsWith('data:')) {
                avatar = `<img src="${userAvatar}" alt="${name}" onerror="this.parentElement.innerHTML='👤';">`;
            } else {
                avatar = userAvatar;
            }
        } else {
            const modelName = settings.selectedModelName || 'Assistant';
            name = modelName;
            avatar = modelName.charAt(0).toUpperCase();
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
        this.smoothScrollToBottom();
    }

    updateMessageUI(index) {
        const message = this.messages[index];
        const messageDiv = document.querySelector(`.message[data-index="${index}"]`);

        if (!messageDiv) return;

        const contentDiv = messageDiv.querySelector('.message-content');
        const cursor = message.streaming ? '<span class="streaming-cursor"></span>' : '';

        // 使用 marked 渲染 Markdown
        let html = marked.parse(message.content || '');
        contentDiv.innerHTML = html + cursor;

        // 使用 requestAnimationFrame 确保 DOM 更新后再高亮
        requestAnimationFrame(() => {
            contentDiv.querySelectorAll('pre code').forEach((codeBlock) => {
                const hasLanguage = Array.from(codeBlock.classList).some(cls => cls.startsWith('language-'));

                if (window.hljs && (hasLanguage || !message.streaming)) {
                    if (!codeBlock.classList.contains('hljs')) {
                        hljs.highlightElement(codeBlock);
                    }
                }

                // 只在流式完成后添加复制按钮
                if (!message.streaming) {
                    const pre = codeBlock.parentElement;
                    if (!pre.querySelector('.copy-button')) {
                        const button = document.createElement('button');
                        button.className = 'copy-button';
                        button.title = '复制代码';
                        button.innerHTML = `
                            <svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                                <rect x="8" y="2" width="8" height="4" rx="1" ry="1"></rect>
                                <path d="M16 4h2a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2V6a2 2 0 0 1 2-2h2"></path>
                                <path d="M9 12h6"></path>
                                <path d="M9 16h6"></path>
                            </svg>
                        `;
                        button.onclick = () => this.copyCode(button, codeBlock);
                        pre.appendChild(button);
                    }
                }
            });
        });

        this.smoothScrollToBottom();
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

    copyCode(button, codeBlock) {
        const code = codeBlock.textContent;

        if (navigator.clipboard && navigator.clipboard.writeText) {
            navigator.clipboard.writeText(code).then(() => {
                this.showCopySuccess(button);
            }).catch(err => {
                this.error('复制失败: ' + err);
                this.fallbackCopy(code, button);
            });
        } else {
            this.fallbackCopy(code, button);
        }
    }

    fallbackCopy(text, button) {
        const textarea = document.createElement('textarea');
        textarea.value = text;
        textarea.style.position = 'fixed';
        textarea.style.opacity = '0';
        document.body.appendChild(textarea);

        try {
            textarea.select();
            const successful = document.execCommand('copy');
            if (successful) {
                this.showCopySuccess(button);
            } else {
                this.error('复制命令失败');
            }
        } catch (err) {
            this.error('回退复制失败: ' + err);
        } finally {
            document.body.removeChild(textarea);
        }
    }

    showCopySuccess(button) {
        button.innerHTML = `
            <svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg" fill="none" stroke="currentColor" stroke-width="3" stroke-linecap="round" stroke-linejoin="round">
                <polyline points="20 6 9 17 4 12"></polyline>
            </svg>
        `;
        button.classList.add('copied');

        setTimeout(() => {
            button.innerHTML = `
                <svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                    <rect x="8" y="2" width="8" height="4" rx="1" ry="1"></rect>
                    <path d="M16 4h2a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2V6a2 2 0 0 1 2-2h2"></path>
                    <path d="M9 12h6"></path>
                    <path d="M9 16h6"></path>
                </svg>
            `;
            button.classList.remove('copied');
        }, 2000);
    }

    smoothScrollToBottom() {
        if (!this.autoScroll) return;

        requestAnimationFrame(() => {
            window.scrollTo({
                top: document.body.scrollHeight,
                behavior: 'smooth'
            });
        });
    }

    async onRun(userInput) {
        this.log(`收到用户输入: ${userInput}`);
        await this.sendMessage(userInput);
    }

    async onDestroy() {
        this.log('插件即将销毁');

        // 清理主题监听
        if (this.themeStyleElement) {
            this.themeStyleElement.remove();
        }

        await super.onDestroy();
    }
}

// 插件入口函数
window.runPlugin = async function(userInput) {
    // 创建实例（如果不存在）
    if (!window.pluginInstance) {
        console.log('[ModernChat] Creating plugin instance...');
        window.pluginInstance = new ModernChatPlugin();
    }

    // 初始化（如果未初始化）
    if (!window.pluginInstance.isInitialized) {
        console.log('[ModernChat] Initializing...');
        await window.pluginInstance.onInit(PluginSDK.getContext());
    }

    console.log('[ModernChat] Running with input:', userInput);
    await window.pluginInstance.onRun(userInput);
    return undefined;
};
