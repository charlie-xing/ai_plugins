/**
 * @name Code Helper
 * @description Interactive code execution with Python, JavaScript and HTML preview
 * @author AI Assistant
 * @version 1.0.0
 * @entryFunction runPlugin
 * @mode Chat
 */

class ChatApp {
    constructor() {
        // Restore saved messages if available
        this.messages = window.SAVED_MESSAGES || [];
        if (window.SAVED_MESSAGES) {
            console.log('Restored messages from saved session:', this.messages.length);
        }
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
            .edit-checkbox-wrapper {
                position: absolute;
                top: 8px;
                right: 88px;
                background: white;
                border: 1.5px solid #6b7280;
                border-radius: 50%;
                padding: 0;
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
                .edit-checkbox-wrapper {
                    background: #1f2937;
                    border-color: #9ca3af;
                }
            }
            .edit-checkbox {
                display: none;
            }
            .checkbox-icon {
                width: 16px;
                height: 16px;
                display: flex;
                align-items: center;
                justify-content: center;
            }
            .checkbox-icon svg {
                width: 16px;
                height: 16px;
                fill: #4b5563;
            }
            @media (prefers-color-scheme: dark) {
                .checkbox-icon svg {
                    fill: #d1d5db;
                }
            }
            .checkbox-icon .check-icon {
                display: none;
            }
            .edit-checkbox:checked ~ .checkbox-icon .edit-icon {
                display: none;
            }
            .edit-checkbox:checked ~ .checkbox-icon .check-icon {
                display: block;
            }
            .message-content pre:hover .edit-checkbox-wrapper {
                opacity: 1;
            }
            .edit-checkbox-wrapper:hover {
                background: #f3f4f6;
                border-color: #4b5563;
                transform: scale(1.1);
            }
            @media (prefers-color-scheme: dark) {
                .edit-checkbox-wrapper:hover {
                    background: #374151;
                    border-color: #d1d5db;
                }
            }
            .edit-checkbox-wrapper:hover .checkbox-icon svg {
                fill: #1f2937;
            }
            @media (prefers-color-scheme: dark) {
                .edit-checkbox-wrapper:hover .checkbox-icon svg {
                    fill: #f3f4f6;
                }
            }
            .edit-checkbox:checked ~ .checkbox-icon {
                background: #3b82f6;
                border-radius: 4px;
            }
            .edit-checkbox:checked ~ .checkbox-icon svg {
                fill: white;
            }
            .run-button {
                position: absolute;
                top: 8px;
                right: 48px;
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
                .run-button {
                    background: #1f2937;
                    border-color: #9ca3af;
                }
            }
            .run-button svg {
                width: 16px;
                height: 16px;
                fill: #4b5563;
            }
            @media (prefers-color-scheme: dark) {
                .run-button svg {
                    fill: #d1d5db;
                }
            }
            .message-content pre:hover .run-button {
                opacity: 1;
            }
            .run-button:hover {
                background: #f3f4f6;
                border-color: #4b5563;
                transform: scale(1.05);
            }
            @media (prefers-color-scheme: dark) {
                .run-button:hover {
                    background: #374151;
                    border-color: #d1d5db;
                }
            }
            .run-button:hover svg {
                fill: #1f2937;
            }
            @media (prefers-color-scheme: dark) {
                .run-button:hover svg {
                    fill: #f3f4f6;
                }
            }
            .run-button.running {
                background: #f3f4f6;
                border-color: #4b5563;
            }
            @media (prefers-color-scheme: dark) {
                .run-button.running {
                    background: #374151;
                    border-color: #d1d5db;
                }
            }
            .run-button.running svg {
                animation: spin 1s linear infinite;
            }
            @keyframes spin {
                from { transform: rotate(0deg); }
                to { transform: rotate(360deg); }
            }
            .code-output {
                background: rgba(135,131,120,0.08);
                border-radius: 8px;
                padding: 12px 16px;
                margin: 8px 0 12px 0;
                font-family: "SF Mono", Monaco, Consolas, monospace;
                font-size: 13px;
                white-space: pre-wrap;
                max-height: 300px;
                overflow-y: auto;
                border-left: 3px solid #6b7280;
            }
            @media (prefers-color-scheme: dark) {
                .code-output {
                    background: rgba(255,255,255,0.05);
                    border-left-color: #9ca3af;
                }
            }
            .code-output.error {
                border-left-color: #ef4444;
                color: #dc2626;
            }
            @media (prefers-color-scheme: dark) {
                .code-output.error {
                    color: #fca5a5;
                }
            }
            .code-output.success {
                border-left-color: #10b981;
            }
            .code-output iframe {
                width: 100%;
                min-height: 200px;
                border: none;
                border-radius: 4px;
                background: white;
            }
            .code-editor {
                display: none;
                width: 100%;
                min-height: 100px;
                padding: 12px;
                font-family: "SF Mono", Monaco, Consolas, monospace;
                font-size: 13px;
                background: rgba(135,131,120,0.08);
                border: 2px solid #3b82f6;
                border-radius: 8px;
                resize: vertical;
                outline: none;
                color: inherit;
            }
            @media (prefers-color-scheme: dark) {
                .code-editor {
                    background: rgba(255,255,255,0.05);
                }
            }
            .code-editor.active {
                display: block;
            }
            pre.editing code {
                display: none;
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
                    // Initialize code block editing after stream completes
                    setTimeout(() => this.initializeCodeBlockEditing(), 100);
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
        console.log('updateMessageContent called, index:', index, 'streaming:', msg.streaming, 'has element:', !!msg.element);
        if (!msg.element) return;

        const contentDiv = msg.element.querySelector('.message-content');
        const cursor = msg.streaming ? '<span class="streaming-cursor"></span>' : '';

        // Use marked to render Markdown
        let html = marked.parse(msg.content || '');
        contentDiv.innerHTML = html + cursor;

        // Use requestAnimationFrame to ensure DOM is updated before highlighting
        requestAnimationFrame(() => {
            // Apply syntax highlighting to code blocks
            const codeBlocks = contentDiv.querySelectorAll('pre code');
            console.log('Found code blocks:', codeBlocks.length);
            codeBlocks.forEach((codeBlock) => {
                // Check if this block has a language class (from marked renderer)
                const hasLanguage = Array.from(codeBlock.classList).some(cls => cls.startsWith('language-'));

                // Apply highlighting if block has language class OR streaming is complete
                if (window.hljs && (hasLanguage || !msg.streaming)) {
                    // Check if already highlighted (avoid re-highlighting)
                    if (!codeBlock.classList.contains('hljs')) {
                        hljs.highlightElement(codeBlock);
                    }
                }

                // Only add copy and run buttons when streaming is complete
                if (!msg.streaming) {
                    console.log('Adding buttons and handlers - streaming complete');
                    const pre = codeBlock.parentElement;

                    // Add copy button
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

                    // Add run button and click-to-edit for all code blocks
                    const language = this.getLanguageFromCodeBlock(codeBlock);
                    const isExecutable = this.isExecutableLanguage(language);
                    console.log('Code block language:', language, 'isExecutable:', isExecutable, 'classes:', Array.from(codeBlock.classList).join(', '));

                    // Always allow editing, but only show run button for executable languages
                    if (true) {  // Changed from isExecutableLanguage check
                        // Add edit checkbox (left of run button)
                        if (!pre.querySelector('.edit-checkbox')) {
                            const checkboxWrapper = document.createElement('label');
                            checkboxWrapper.className = 'edit-checkbox-wrapper';
                            checkboxWrapper.title = 'Toggle edit mode';

                            const checkbox = document.createElement('input');
                            checkbox.type = 'checkbox';
                            checkbox.className = 'edit-checkbox';

                            const checkboxIcon = document.createElement('span');
                            checkboxIcon.className = 'checkbox-icon';
                            // SF Font filled style icons - pencil for unchecked, checkmark for checked
                            checkboxIcon.innerHTML = `
                                <svg class="edit-icon" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg" fill="currentColor">
                                    <path d="M20.71 7.04c.39-.39.39-1.04 0-1.41l-2.34-2.34c-.37-.39-1.02-.39-1.41 0l-1.84 1.83 3.75 3.75M3 17.25V21h3.75L17.81 9.93l-3.75-3.75L3 17.25z"/>
                                </svg>
                                <svg class="check-icon" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg" fill="currentColor">
                                    <path d="M9 16.17L4.83 12l-1.42 1.41L9 19 21 7l-1.41-1.41L9 16.17z"/>
                                </svg>
                            `;

                            checkboxWrapper.appendChild(checkbox);
                            checkboxWrapper.appendChild(checkboxIcon);

                            checkbox.onchange = (e) => {
                                // Stop propagation to prevent affecting other checkboxes
                                e.stopPropagation();

                                if (checkbox.checked) {
                                    this.enterEditMode(codeBlock, pre);
                                } else {
                                    this.exitEditMode(codeBlock, pre);
                                }
                            };

                            pre.appendChild(checkboxWrapper);
                        }

                        // Add run button
                        if (!pre.querySelector('.run-button')) {
                            const runButton = document.createElement('button');
                            runButton.className = 'run-button';
                            runButton.title = 'Run code';
                            // SF Symbols style play icon (triangle)
                            runButton.innerHTML = `
                                <svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
                                    <path d="M8 5v14l11-7z"/>
                                </svg>
                            `;
                            runButton.onclick = () => this.executeCode(codeBlock, language);
                            pre.appendChild(runButton);
                        }

                        // Add textarea for editing (hidden by default)
                        if (!pre.querySelector('.code-editor')) {
                            const textarea = document.createElement('textarea');
                            textarea.className = 'code-editor';
                            textarea.value = codeBlock.textContent;
                            pre.appendChild(textarea);

                            // Click outside textarea to exit edit mode
                            textarea.onblur = () => {
                                setTimeout(() => {
                                    const checkbox = pre.querySelector('.edit-checkbox');
                                    if (checkbox && !pre.contains(document.activeElement)) {
                                        checkbox.checked = false;
                                        this.exitEditMode(codeBlock, pre);
                                    }
                                }, 100);
                            };

                            // Esc to exit edit mode
                            textarea.onkeydown = (e) => {
                                if (e.key === 'Escape') {
                                    const checkbox = pre.querySelector('.edit-checkbox');
                                    if (checkbox) {
                                        checkbox.checked = false;
                                    }
                                    this.exitEditMode(codeBlock, pre);
                                    e.preventDefault();
                                }
                            };
                        }

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

    getLanguageFromCodeBlock(codeBlock) {
        // Extract language from class names (e.g., language-python, language-javascript)
        const classes = Array.from(codeBlock.classList);
        for (const cls of classes) {
            if (cls.startsWith('language-')) {
                return cls.substring(9); // Remove 'language-' prefix
            }
        }
        return null;
    }

    isExecutableLanguage(language) {
        const executableLanguages = ['python', 'javascript', 'js', 'html'];
        return language && executableLanguages.includes(language.toLowerCase());
    }

    enterEditMode(codeBlock, pre) {
        // Only affect this specific pre element
        const textarea = pre.querySelector('.code-editor');
        if (!textarea || pre.classList.contains('editing')) return;

        // Enter edit mode for this specific code block only
        textarea.value = codeBlock.textContent;
        textarea.classList.add('active');
        pre.classList.add('editing');

        // Auto-resize textarea to fit content
        textarea.style.height = 'auto';
        textarea.style.height = textarea.scrollHeight + 'px';

        // Focus textarea
        textarea.focus();

        // Auto-resize on input
        textarea.oninput = () => {
            textarea.style.height = 'auto';
            textarea.style.height = textarea.scrollHeight + 'px';
        };

        console.log('Entered edit mode for code block:', codeBlock.className);
    }

    exitEditMode(codeBlock, pre) {
        // Only affect this specific pre element
        const textarea = pre.querySelector('.code-editor');
        if (!textarea || !pre.classList.contains('editing')) return;

        // Exit edit mode - save changes for this specific code block
        const newCode = textarea.value;
        codeBlock.textContent = newCode;

        // Re-apply syntax highlighting to this specific code block
        console.log('Attempting to restore syntax highlighting...');
        console.log('hljs available:', !!window.hljs);
        console.log('Code block classes:', codeBlock.className);

        if (window.hljs) {
            // Remove old highlighting classes first
            codeBlock.removeAttribute('data-highlighted');

            // Re-apply highlighting
            try {
                window.hljs.highlightElement(codeBlock);
                console.log('Syntax highlighting applied successfully');
            } catch (e) {
                console.error('Error applying syntax highlighting:', e);
            }
        } else {
            console.warn('hljs not available, cannot restore syntax highlighting');
        }

        pre.classList.remove('editing');
        textarea.classList.remove('active');

        console.log('Exited edit mode, saved changes for:', codeBlock.className);
    }

    async executeCode(codeBlock, language) {
        const pre = codeBlock.parentElement;
        const textarea = pre.querySelector('.code-editor');

        // Re-check language in case it wasn't set initially
        if (!language) {
            language = this.getLanguageFromCodeBlock(codeBlock);
        }

        // Check if language is executable
        if (!this.isExecutableLanguage(language)) {
            alert(`Cannot execute code: language "${language || 'unknown'}" is not supported.\nSupported languages: Python, JavaScript, HTML`);
            return;
        }

        // Get code from textarea if in edit mode, otherwise from code block
        const code = pre.classList.contains('editing') && textarea
            ? textarea.value
            : codeBlock.textContent;

        const runButton = pre.querySelector('.run-button');

        // Get or create output div
        let outputDiv = pre.nextElementSibling;
        if (!outputDiv || !outputDiv.classList.contains('code-output')) {
            outputDiv = document.createElement('div');
            outputDiv.className = 'code-output';
            pre.parentNode.insertBefore(outputDiv, pre.nextSibling);
        }

        // Show loading state
        runButton.classList.add('running');
        outputDiv.className = 'code-output';
        outputDiv.textContent = 'Executing...';

        try {
            console.log('Executing code with language:', language);
            console.log('Code:', code);

            // Determine execution method based on language
            let result;
            const normalizedLang = language.toLowerCase();

            if (normalizedLang === 'html') {
                // For HTML, show preview in iframe
                outputDiv.innerHTML = '<iframe srcdoc="' + this.escapeHtml(code) + '"></iframe>';
                outputDiv.classList.add('success');
            } else if (normalizedLang === 'python') {
                // For Python, we'll need to call Swift bridge (for now, just log)
                result = await this.callSwiftExecute('python3', ['-c', code]);
                outputDiv.textContent = result || '(No output)';
                outputDiv.classList.add('success');
            } else if (normalizedLang === 'javascript' || normalizedLang === 'js') {
                // For JavaScript, we'll need to call Swift bridge (for now, just log)
                result = await this.callSwiftExecute('node', ['-e', code]);
                outputDiv.textContent = result || '(No output)';
                outputDiv.classList.add('success');
            } else {
                outputDiv.textContent = `Execution not supported for ${language}`;
                outputDiv.classList.add('error');
            }

        } catch (error) {
            console.error('Execution error:', error);
            outputDiv.textContent = `Error: ${error.message}`;
            outputDiv.classList.add('error');
        } finally {
            // Remove loading state
            runButton.classList.remove('running');
        }
    }

    escapeHtml(html) {
        return html
            .replace(/&/g, '&amp;')
            .replace(/</g, '&lt;')
            .replace(/>/g, '&gt;')
            .replace(/"/g, '&quot;')
            .replace(/'/g, '&#039;');
    }

    async callSwiftExecute(command, args) {
        return new Promise((resolve, reject) => {
            const callbackId = `exec_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;

            // Store callback in global registry
            if (!window.executeCallbacks) {
                window.executeCallbacks = {};
            }

            window.executeCallbacks[callbackId] = (success, output) => {
                if (success) {
                    resolve(output);
                } else {
                    reject(new Error(output));
                }
            };

            // Call Swift bridge
            window.webkit.messageHandlers.callAI.postMessage({
                action: 'executeCode',
                command: command,
                args: args,
                callbackId: callbackId
            });

            // Timeout after 30 seconds
            setTimeout(() => {
                if (window.executeCallbacks[callbackId]) {
                    delete window.executeCallbacks[callbackId];
                    reject(new Error('Execution timeout'));
                }
            }, 30000);
        });
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

    // Initialize code block editing for all code blocks in the page
    initializeCodeBlockEditing() {
        console.log('Initializing code block editing...');
        const codeBlocks = document.querySelectorAll('pre code');
        console.log(`Found ${codeBlocks.length} code blocks to initialize`);

        codeBlocks.forEach(codeBlock => {
            const pre = codeBlock.parentElement;
            if (!pre) return;

            // Add textarea for editing (if not already added)
            if (!pre.querySelector('.code-editor')) {
                const textarea = document.createElement('textarea');
                textarea.className = 'code-editor';
                textarea.value = codeBlock.textContent;
                pre.appendChild(textarea);

                // Click outside textarea to save
                textarea.onblur = () => {
                    setTimeout(() => {
                        if (!pre.contains(document.activeElement)) {
                            this.exitEditMode(codeBlock, pre);
                        }
                    }, 100);
                };

                // Esc to save and exit
                textarea.onkeydown = (e) => {
                    if (e.key === 'Escape') {
                        this.exitEditMode(codeBlock, pre);
                        e.preventDefault();
                    }
                };
            }

            // Note: Edit mode is now only controlled via checkbox, not by clicking code blocks
        });

        console.log('Code block editing initialized');
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

    // Initialize code block editing for any existing code blocks (e.g., from loaded history)
    setTimeout(() => {
        if (window.chatApp) {
            window.chatApp.initializeCodeBlockEditing();
        }
    }, 500);
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
