/**
 * @name Test Chat V5 (WKWebView)
 * @description Streaming chat with code highlighting and smooth rendering
 * @author AI Assistant
 * @version 5.3.0
 * @entryFunction runPlugin
 * @mode Chat
 */

class ChatApp {
    constructor() {
        this.messages = [];
        this.userSettings = null;
        this.isInitialized = false;
        this.currentTheme = null;
        this.themeStyleElement = null;
        this.autoScroll = true;  // Auto-scroll by default
        this.userScrolling = false;
        this.scrollTimeout = null;
    }

    async init() {
        if (this.isInitialized) return;

        console.log('ChatApp initializing...');
        this.loadUserSettings();
        await this.loadDependencies();
        this.setupStyles();
        this.setupMessageHandlers();
        this.render();
        this.isInitialized = true;
        console.log('ChatApp initialized');
    }

    async loadDependencies() {
        // Load marked.js for Markdown
        if (!window.marked) {
            console.log('Loading marked.js...');
            await this.loadScript('https://cdn.jsdelivr.net/npm/marked@11.1.1/marked.min.js');
            console.log('Marked.js loaded:', !!window.marked);
        }

        // Load highlight.js for code highlighting
        if (!window.hljs) {
            console.log('Loading highlight.js...');
            await this.loadScript('https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/highlight.min.js');
            console.log('Highlight.js loaded:', !!window.hljs);
        }

        // Load theme-appropriate CSS and setup theme listener
        this.loadHighlightTheme();
        this.setupThemeListener();

        // Configure marked with highlight.js (ensure hljs is loaded)
        if (window.marked && window.hljs) {
            console.log('Configuring marked with highlight.js');

            // Custom renderer to add language class to code blocks
            const renderer = new marked.Renderer();
            const originalCode = renderer.code.bind(renderer);
            renderer.code = function(code, language) {
                // Call original renderer
                const html = originalCode(code, language);
                // Add language class if specified
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
                    // Don't highlight during parsing - we'll do it after streaming
                    // Just return the plain code
                    return code;
                }
            });
        } else {
            console.error('Failed to load marked or hljs:', { marked: !!window.marked, hljs: !!window.hljs });
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

    loadCSS(href) {
        return new Promise((resolve) => {
            const link = document.createElement('link');
            link.rel = 'stylesheet';
            link.href = href;
            link.onload = resolve;
            document.head.appendChild(link);
            resolve(); // Don't wait for CSS
        });
    }

    isDarkMode() {
        return window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)').matches;
    }

    loadHighlightTheme() {
        const isDark = this.isDarkMode();
        const theme = isDark ? 'atom-one-dark' : 'atom-one-light';

        // Remove old theme if exists
        if (this.themeStyleElement) {
            this.themeStyleElement.remove();
        }

        // Load new theme
        const link = document.createElement('link');
        link.rel = 'stylesheet';
        link.id = 'hljs-theme';
        link.href = `https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/styles/${theme}.min.css`;
        document.head.appendChild(link);
        this.themeStyleElement = link;
        this.currentTheme = theme;

        console.log(`Loaded highlight.js theme: ${theme}`);
    }

    setupThemeListener() {
        // Listen for theme changes
        const mediaQuery = window.matchMedia('(prefers-color-scheme: dark)');
        mediaQuery.addEventListener('change', (e) => {
            console.log('Theme changed to:', e.matches ? 'dark' : 'light');
            this.loadHighlightTheme();
            // Re-highlight all existing code blocks
            this.rehighlightAllCode();
        });
    }

    rehighlightAllCode() {
        if (!window.hljs) return;

        // Find all code blocks and re-highlight them
        document.querySelectorAll('pre code').forEach((codeBlock) => {
            // Remove existing highlighting classes but keep language- classes
            codeBlock.className = codeBlock.className
                .split(' ')
                .filter(cls => !cls.startsWith('hljs') || cls.startsWith('language-'))
                .join(' ');

            // Re-highlight
            hljs.highlightElement(codeBlock);
        });

        console.log('Re-highlighted all code blocks');
    }

    loadUserSettings() {
        // Load from injected global variable
        if (window.INITIAL_SETTINGS) {
            this.userSettings = window.INITIAL_SETTINGS;
            console.log('Loaded settings from INITIAL_SETTINGS:', JSON.stringify(this.userSettings));
        } else {
            console.warn('No INITIAL_SETTINGS found, using defaults');
            this.userSettings = { userName: 'User', userAvatar: '👤', selectedModelName: 'Assistant' };
        }
    }

    setupStyles() {
        const style = document.createElement('style');
        style.textContent = `
            * { margin: 0; padding: 0; box-sizing: border-box; }
            body {
                font-family: -apple-system, BlinkMacSystemFont, sans-serif;
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
            .user .avatar { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); }
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
            @keyframes blink { 0%, 50% { opacity: 1; } 51%, 100% { opacity: 0; } }
        `;
        document.head.appendChild(style);
    }

    setupMessageHandlers() {
        window.onStreamChunk = (chunk) => {
            if (this.messages.length > 0) {
                const lastMsg = this.messages[this.messages.length - 1];
                if (lastMsg.role === 'assistant' && lastMsg.streaming) {
                    lastMsg.content += chunk;
                    this.updateLastMessage();
                }
            }
        };

        window.onStreamComplete = () => {
            if (this.messages.length > 0) {
                const lastMsg = this.messages[this.messages.length - 1];
                if (lastMsg.role === 'assistant') {
                    lastMsg.streaming = false;
                    this.updateLastMessage();
                }
            }
        };

        window.onStreamError = (error) => {
            if (this.messages.length > 0) {
                const lastMsg = this.messages[this.messages.length - 1];
                if (lastMsg.role === 'assistant') {
                    lastMsg.content = `Error: ${error}`;
                    lastMsg.streaming = false;
                    this.updateLastMessage();
                }
            }
        };

        // Setup scroll listener to detect user scrolling
        window.addEventListener('scroll', () => {
            // Clear any pending timeout
            if (this.scrollTimeout) {
                clearTimeout(this.scrollTimeout);
            }

            // Check if user is near bottom (within 100px)
            const isNearBottom = (window.innerHeight + window.scrollY) >= (document.body.scrollHeight - 100);

            if (isNearBottom) {
                // User scrolled to bottom, enable auto-scroll
                this.autoScroll = true;
            } else {
                // User scrolled up, disable auto-scroll
                this.autoScroll = false;
            }
        });
    }

    addUserMessage(content) {
        this.messages.push({
            role: 'user',
            content: content,
            streaming: false
        });
        this.appendMessage(this.messages.length - 1);
    }

    startAssistantMessage() {
        this.messages.push({
            role: 'assistant',
            content: '',
            streaming: true,
            element: null
        });
        this.appendMessage(this.messages.length - 1);
    }

    appendMessage(index) {
        const container = document.getElementById('chat-container') || this.createContainer();
        const msg = this.messages[index];
        const div = document.createElement('div');
        div.className = `message ${msg.role}`;
        div.dataset.index = index;

        let avatar, name;
        if (msg.role === 'user') {
            const userAvatar = this.userSettings?.userAvatar || '👤';
            name = this.userSettings?.userName || 'User';

            console.log('User avatar path:', userAvatar);

            // Handle file:// paths for local images
            if (userAvatar.startsWith('/')) {
                // Absolute path without file:// prefix - need to encode the path
                const encodedPath = encodeURI(userAvatar);
                avatar = `<img src="file://${encodedPath}" alt="${name}" onerror="console.error('Image load failed:', this.src); this.parentElement.innerHTML='👤';">`;
            } else if (userAvatar.startsWith('file://')) {
                // Already has file:// prefix - extract and re-encode the path
                const pathOnly = userAvatar.substring(7); // Remove 'file://'
                const encodedPath = encodeURI(pathOnly);
                avatar = `<img src="file://${encodedPath}" alt="${name}" onerror="console.error('Image load failed:', this.src); this.parentElement.innerHTML='👤';">`;
            } else if (userAvatar.startsWith('http') || userAvatar.startsWith('data:')) {
                // HTTP or data URL
                avatar = `<img src="${userAvatar}" alt="${name}" onerror="console.error('Image load failed:', this.src); this.parentElement.innerHTML='👤';">`;
            } else {
                // Emoji or other text
                avatar = userAvatar;
            }
        } else {
            const modelName = this.userSettings?.selectedModelName || 'Assistant';
            name = modelName;
            avatar = modelName.charAt(0).toUpperCase();
        }

        div.innerHTML = `
            <div class="message-header">
                <div class="avatar">${avatar}</div>
                <span>${name}</span>
            </div>
            <div class="message-content"></div>
        `;

        container.appendChild(div);
        msg.element = div;
        this.updateMessageContent(index);
        this.smoothScrollToBottom();
    }

    updateLastMessage() {
        if (this.messages.length > 0) {
            this.updateMessageContent(this.messages.length - 1);
            this.smoothScrollToBottom();
        }
    }

    updateMessageContent(index) {
        const msg = this.messages[index];
        if (!msg.element) return;

        const contentDiv = msg.element.querySelector('.message-content');
        const cursor = msg.streaming ? '<span class="streaming-cursor"></span>' : '';

        // Use marked to render Markdown
        let html = marked.parse(msg.content || '');
        contentDiv.innerHTML = html + cursor;

        // Use requestAnimationFrame to ensure DOM is updated before highlighting
        requestAnimationFrame(() => {
            // Apply syntax highlighting to code blocks
            contentDiv.querySelectorAll('pre code').forEach((codeBlock) => {
                // Check if this block has a language class (from marked renderer)
                const hasLanguage = Array.from(codeBlock.classList).some(cls => cls.startsWith('language-'));

                // Apply highlighting if block has language class OR streaming is complete
                if (window.hljs && (hasLanguage || !msg.streaming)) {
                    // Check if already highlighted (avoid re-highlighting)
                    if (!codeBlock.classList.contains('hljs')) {
                        hljs.highlightElement(codeBlock);
                    }
                }

                // Only add copy button when streaming is complete
                if (!msg.streaming) {
                    const pre = codeBlock.parentElement;
                    if (!pre.querySelector('.copy-button')) {
                        const button = document.createElement('button');
                        button.className = 'copy-button';
                        button.title = 'Copy code';
                        // SF Symbols style doc.on.clipboard icon
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
    }

    copyCode(button, codeBlock) {
        const code = codeBlock.textContent;

        // Try modern clipboard API first
        if (navigator.clipboard && navigator.clipboard.writeText) {
            navigator.clipboard.writeText(code).then(() => {
                this.showCopySuccess(button);
            }).catch(err => {
                console.error('Clipboard API failed:', err);
                this.fallbackCopy(code, button);
            });
        } else {
            // Fallback to old method
            this.fallbackCopy(code, button);
        }
    }

    fallbackCopy(text, button) {
        // Create temporary textarea
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
                console.error('Copy command failed');
            }
        } catch (err) {
            console.error('Fallback copy failed:', err);
        } finally {
            document.body.removeChild(textarea);
        }
    }

    showCopySuccess(button) {
        // SF Symbols style checkmark icon
        button.innerHTML = `
            <svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg" fill="none" stroke="currentColor" stroke-width="3" stroke-linecap="round" stroke-linejoin="round">
                <polyline points="20 6 9 17 4 12"></polyline>
            </svg>
        `;
        button.classList.add('copied');
        setTimeout(() => {
            // Back to clipboard icon
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
        // Only auto-scroll if enabled (user hasn't scrolled up)
        if (!this.autoScroll) {
            return;
        }

        // Use requestAnimationFrame for smooth scrolling
        requestAnimationFrame(() => {
            window.scrollTo({
                top: document.body.scrollHeight,
                behavior: 'smooth'
            });
        });
    }

    render() {
        const container = document.getElementById('chat-container') || this.createContainer();
        container.innerHTML = '';
        this.messages.forEach((msg, index) => {
            msg.element = null;
            this.appendMessage(index);
        });
    }

    createContainer() {
        const container = document.createElement('div');
        container.id = 'chat-container';
        document.body.appendChild(container);
        return container;
    }

    async sendMessage(userPrompt) {
        console.log('Sending message:', userPrompt);

        this.addUserMessage(userPrompt);
        this.startAssistantMessage();

        // Build conversation history for context
        const conversationHistory = this.messages
            .filter(msg => !msg.streaming) // Exclude the currently streaming message
            .map(msg => ({
                role: msg.role,
                content: msg.content
            }));

        console.log('Sending conversation history:', conversationHistory);

        window.webkit.messageHandlers.callAI.postMessage({
            action: 'callAIStream',
            message: userPrompt,
            messages: conversationHistory  // Send full conversation history
        });
    }
}

// Global chat app instance
if (!window.chatApp) {
    window.chatApp = new ChatApp();
}

// Auto-initialize on DOM ready
window.addEventListener('DOMContentLoaded', async function() {
    console.log('DOM loaded, auto-initializing ChatApp...');
    if (!window.chatApp.isInitialized) {
        await window.chatApp.init();
        console.log('ChatApp auto-initialization complete');
    }
});

// Entry point - just send message (init already done)
async function runPlugin(userPrompt) {
    console.log('runPlugin called with:', userPrompt);

    // Wait for initialization if not ready yet
    if (!window.chatApp.isInitialized) {
        console.log('ChatApp not initialized yet, waiting...');
        await window.chatApp.init();
    }

    await window.chatApp.sendMessage(userPrompt);
    return undefined;
}
