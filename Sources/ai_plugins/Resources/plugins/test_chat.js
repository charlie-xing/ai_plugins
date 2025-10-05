/**
 * @name Test Chat
 * @description Test chat interface for AI conversation
 * @author AI Plugins Team
 * @version 2.2.0
 * @entryFunction runPlugin
 * @mode chat
 */

const plugin = {
    name: "Test Chat",
    version: "2.2.0",
    description: "Test chat interface for AI conversation - Claude Style",
    author: "AI Plugins Team",
    mode: "chat",

    // Conversation history
    messages: [],

    /**
     * Initialize the plugin
     */
    init: function() {
        console.log("Test Chat plugin initialized");
        this.messages = [];
    },

    /**
     * Get app settings
     */
    getSettings: function() {
        if (typeof getSettings !== 'undefined') {
            return getSettings();
        }
        return {
            userName: "User",
            selectedModel: "AI Assistant"
        };
    },

    /**
     * Generate HTML for the chat interface (Claude-inspired)
     */
    generateHTML: function() {
        const settings = this.getSettings();
        const userName = settings.userName || "User";
        const modelName = settings.selectedModel || "AI Assistant";

        // Serialize messages as JSON for client-side rendering
        const messagesJSON = JSON.stringify(this.messages)
            .replace(/</g, '\\u003c')
            .replace(/>/g, '\\u003e');

        const html = `
            <!DOCTYPE html>
            <html>
            <head>
                <meta charset="UTF-8">
                <meta name="viewport" content="width=device-width, initial-scale=1.0">
                <!-- Marked.js for Markdown parsing -->
                <script src="https://cdn.jsdelivr.net/npm/marked@11.1.1/marked.min.js"></script>
                <!-- Highlight.js for code syntax highlighting -->
                <link rel="stylesheet" href="https://cdn.jsdelivr.net/gh/highlightjs/cdn-release@11.9.0/build/styles/github-dark.min.css">
                <script src="https://cdn.jsdelivr.net/gh/highlightjs/cdn-release@11.9.0/build/highlight.min.js"></script>
                <style>
                    * {
                        margin: 0;
                        padding: 0;
                        box-sizing: border-box;
                    }

                    body {
                        font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
                        background: transparent;
                        color: #1a1a1a;
                        line-height: 1.6;
                        -webkit-font-smoothing: antialiased;
                    }

                    #chat-container {
                        max-width: 900px;
                        margin: 0 auto;
                        padding: 24px 16px;
                    }

                    .message {
                        margin-bottom: 32px;
                        animation: fadeIn 0.3s ease-out;
                    }

                    @keyframes fadeIn {
                        from {
                            opacity: 0;
                            transform: translateY(8px);
                        }
                        to {
                            opacity: 1;
                            transform: translateY(0);
                        }
                    }

                    .message-header {
                        display: flex;
                        align-items: center;
                        gap: 10px;
                        margin-bottom: 12px;
                    }

                    .message-avatar {
                        width: 32px;
                        height: 32px;
                        border-radius: 6px;
                        display: flex;
                        align-items: center;
                        justify-content: center;
                        font-size: 18px;
                        flex-shrink: 0;
                        background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                        color: white;
                        font-weight: 600;
                    }

                    .ai-message .message-avatar {
                        background: linear-gradient(135deg, #f093fb 0%, #f5576c 100%);
                    }

                    .message-sender {
                        font-weight: 600;
                        font-size: 14px;
                        color: #1a1a1a;
                    }

                    .message-time {
                        font-size: 12px;
                        color: #666;
                        margin-left: auto;
                    }

                    .message-content {
                        font-size: 15px;
                        line-height: 1.7;
                        color: #1a1a1a;
                        padding-left: 42px;
                    }

                    /* Markdown Styles */
                    .message-content h1,
                    .message-content h2,
                    .message-content h3,
                    .message-content h4 {
                        margin-top: 24px;
                        margin-bottom: 12px;
                        font-weight: 600;
                        line-height: 1.3;
                    }

                    .message-content h1 { font-size: 1.8em; }
                    .message-content h2 { font-size: 1.5em; }
                    .message-content h3 { font-size: 1.25em; }
                    .message-content h4 { font-size: 1.1em; }

                    .message-content p {
                        margin-bottom: 16px;
                    }

                    .message-content p:last-child {
                        margin-bottom: 0;
                    }

                    .message-content ul,
                    .message-content ol {
                        margin: 16px 0;
                        padding-left: 24px;
                    }

                    .message-content li {
                        margin: 6px 0;
                    }

                    .message-content code {
                        background: rgba(110, 118, 129, 0.1);
                        padding: 3px 6px;
                        border-radius: 4px;
                        font-family: "SF Mono", Monaco, "Cascadia Code", "Roboto Mono", Consolas, "Courier New", monospace;
                        font-size: 0.9em;
                        color: #e74c3c;
                    }

                    /* Code block container */
                    .code-block-wrapper {
                        position: relative;
                        margin: 16px 0;
                    }

                    .code-block-header {
                        background: #2d333b;
                        color: #adbac7;
                        padding: 8px 12px;
                        border-radius: 8px 8px 0 0;
                        display: flex;
                        align-items: center;
                        justify-content: space-between;
                        font-size: 12px;
                        font-family: "SF Mono", Monaco, monospace;
                    }

                    .code-block-lang {
                        font-weight: 600;
                        text-transform: lowercase;
                    }

                    .copy-button {
                        background: rgba(255, 255, 255, 0.1);
                        border: 1px solid rgba(255, 255, 255, 0.2);
                        color: #adbac7;
                        padding: 4px 12px;
                        border-radius: 4px;
                        font-size: 12px;
                        cursor: pointer;
                        transition: all 0.2s;
                        display: flex;
                        align-items: center;
                        gap: 6px;
                        font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
                    }

                    .copy-button:hover {
                        background: rgba(255, 255, 255, 0.2);
                        border-color: rgba(255, 255, 255, 0.3);
                    }

                    .copy-button.copied {
                        background: rgba(46, 160, 67, 0.2);
                        border-color: rgba(46, 160, 67, 0.4);
                        color: #3fb950;
                    }

                    .copy-icon {
                        width: 14px;
                        height: 14px;
                    }

                    .message-content pre {
                        background: #22272e;
                        border-radius: 0 0 8px 8px;
                        padding: 16px;
                        margin: 0;
                        overflow-x: auto;
                    }

                    .message-content .code-block-wrapper + * {
                        margin-top: 16px;
                    }

                    .message-content pre code {
                        background: transparent;
                        padding: 0;
                        font-size: 13px;
                        line-height: 1.6;
                        color: #adbac7;
                        font-family: "SF Mono", Monaco, "Cascadia Code", "Roboto Mono", Consolas, "Courier New", monospace;
                    }

                    /* Syntax highlighting overrides for dark theme */
                    .hljs {
                        background: transparent;
                        color: #adbac7;
                    }

                    .message-content blockquote {
                        border-left: 4px solid #ddd;
                        padding-left: 16px;
                        margin: 16px 0;
                        color: #666;
                        font-style: italic;
                    }

                    .message-content a {
                        color: #667eea;
                        text-decoration: none;
                    }

                    .message-content a:hover {
                        text-decoration: underline;
                    }

                    .message-content table {
                        border-collapse: collapse;
                        width: 100%;
                        margin: 16px 0;
                        font-size: 14px;
                    }

                    .message-content th,
                    .message-content td {
                        border: 1px solid #ddd;
                        padding: 8px 12px;
                        text-align: left;
                    }

                    .message-content th {
                        background: #f6f8fa;
                        font-weight: 600;
                    }

                    .message-content hr {
                        border: none;
                        border-top: 1px solid #e1e4e8;
                        margin: 24px 0;
                    }

                    /* Typing indicator */
                    .typing-indicator {
                        display: inline-flex;
                        gap: 4px;
                        padding: 8px 0;
                    }

                    .typing-indicator span {
                        width: 8px;
                        height: 8px;
                        border-radius: 50%;
                        background: #999;
                        animation: typing 1.4s infinite ease-in-out;
                    }

                    .typing-indicator span:nth-child(2) {
                        animation-delay: 0.2s;
                    }

                    .typing-indicator span:nth-child(3) {
                        animation-delay: 0.4s;
                    }

                    @keyframes typing {
                        0%, 60%, 100% {
                            transform: translateY(0);
                            opacity: 0.5;
                        }
                        30% {
                            transform: translateY(-10px);
                            opacity: 1;
                        }
                    }

                    /* Empty state */
                    .empty-state {
                        text-align: center;
                        padding: 80px 20px;
                        color: #666;
                    }

                    .empty-icon {
                        font-size: 64px;
                        margin-bottom: 16px;
                        opacity: 0.5;
                    }

                    .empty-title {
                        font-size: 20px;
                        font-weight: 600;
                        margin-bottom: 8px;
                        color: #1a1a1a;
                    }

                    .empty-subtitle {
                        font-size: 15px;
                        color: #666;
                    }

                    /* System message */
                    .system-message {
                        background: #fef3cd;
                        border: 1px solid #ffeaa7;
                        border-radius: 8px;
                        padding: 12px 16px;
                        margin-bottom: 24px;
                        font-size: 14px;
                        color: #856404;
                        text-align: center;
                    }

                    /* Scrollbar */
                    ::-webkit-scrollbar {
                        width: 10px;
                        height: 10px;
                    }

                    ::-webkit-scrollbar-track {
                        background: transparent;
                    }

                    ::-webkit-scrollbar-thumb {
                        background: rgba(0, 0, 0, 0.2);
                        border-radius: 5px;
                    }

                    ::-webkit-scrollbar-thumb:hover {
                        background: rgba(0, 0, 0, 0.3);
                    }
                </style>
            </head>
            <body>
                <div id="chat-container"></div>

                <script>
                    // Data from server
                    const messages = ${messagesJSON};
                    const userName = "${userName}";
                    const modelName = "${modelName}";

                    console.log('Chat loaded with', messages.length, 'messages');
                    console.log('userName:', userName);
                    console.log('modelName:', modelName);

                    // Configure marked with custom renderer
                    function configureMarked() {
                        if (typeof marked === 'undefined' || !marked.Renderer) {
                            console.error('marked.js not loaded!');
                            return false;
                        }

                        console.log('Configuring marked.js...');
                        const renderer = new marked.Renderer();

                        // Custom code block renderer
                        renderer.code = function(code, language) {
                            const lang = language || 'text';
                            const escapedCode = code
                                .replace(/&/g, '&amp;')
                                .replace(/</g, '&lt;')
                                .replace(/>/g, '&gt;')
                                .replace(/"/g, '&quot;')
                                .replace(/'/g, '&#39;');

                            // Store code in data attribute
                            const codeData = btoa(unescape(encodeURIComponent(code)));

                            return \`
                                <div class="code-block-wrapper">
                                    <div class="code-block-header">
                                        <span class="code-block-lang">\${lang}</span>
                                        <button class="copy-button" data-code="\${codeData}" onclick="copyCode(this)">
                                            <svg class="copy-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                                                <rect x="9" y="9" width="13" height="13" rx="2" ry="2"></rect>
                                                <path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1"></path>
                                            </svg>
                                            Copy
                                        </button>
                                    </div>
                                    <pre><code class="language-\${lang}">\${escapedCode}</code></pre>
                                </div>
                            \`;
                        };

                        marked.setOptions({
                            renderer: renderer,
                            breaks: true,
                            gfm: true,
                            headerIds: false,
                            mangle: false
                        });

                        console.log('marked.js configured successfully');
                        return true;
                    }

                    // Render markdown
                    function renderMarkdown(text) {
                        if (!text) return '';

                        if (typeof marked !== 'undefined' && marked.parse) {
                            try {
                                return marked.parse(text);
                            } catch (e) {
                                console.error('Markdown parsing error:', e);
                                return escapeHtml(text).replace(/\\n/g, '<br>');
                            }
                        }

                        return escapeHtml(text).replace(/\\n/g, '<br>');
                    }

                    // Escape HTML
                    function escapeHtml(text) {
                        if (!text) return '';
                        return String(text)
                            .replace(/&/g, '&amp;')
                            .replace(/</g, '&lt;')
                            .replace(/>/g, '&gt;')
                            .replace(/"/g, '&quot;')
                            .replace(/'/g, '&#39;');
                    }

                    // Format time
                    function formatTime(timestamp) {
                        const date = new Date(timestamp);
                        const hours = date.getHours().toString().padStart(2, '0');
                        const minutes = date.getMinutes().toString().padStart(2, '0');
                        return \`\${hours}:\${minutes}\`;
                    }

                    // Render messages
                    function renderMessages() {
                        const container = document.getElementById('chat-container');

                        if (messages.length === 0) {
                            container.innerHTML = \`
                                <div class="empty-state">
                                    <div class="empty-icon">💬</div>
                                    <div class="empty-title">Start a Conversation</div>
                                    <div class="empty-subtitle">Send a message to begin chatting</div>
                                </div>
                            \`;
                            return;
                        }

                        const html = messages.map(msg => {
                            if (msg.role === "system") {
                                return \`<div class="system-message">\${escapeHtml(msg.content)}</div>\`;
                            }

                            const isUser = msg.role === "user";
                            const messageClass = isUser ? "user-message" : "ai-message";
                            const time = formatTime(msg.timestamp);

                            const senderName = isUser ? userName : modelName;
                            const avatarLetter = senderName.charAt(0).toUpperCase();

                            let contentHtml = '';
                            if (msg.isStreaming && !msg.content) {
                                contentHtml = \`
                                    <div class="typing-indicator">
                                        <span></span><span></span><span></span>
                                    </div>
                                \`;
                            } else {
                                contentHtml = renderMarkdown(msg.content || '');
                            }

                            return \`
                                <div class="message \${messageClass}">
                                    <div class="message-header">
                                        <div class="message-avatar">\${avatarLetter}</div>
                                        <span class="message-sender">\${escapeHtml(senderName)}</span>
                                        <span class="message-time">\${time}</span>
                                    </div>
                                    <div class="message-content">
                                        \${contentHtml}
                                    </div>
                                </div>
                            \`;
                        }).join('');

                        container.innerHTML = html;

                        // Highlight code blocks
                        if (typeof hljs !== 'undefined') {
                            console.log('Highlighting code blocks...');
                            document.querySelectorAll('pre code').forEach((block) => {
                                hljs.highlightElement(block);
                            });
                        }

                        // Auto-scroll to bottom
                        window.scrollTo(0, document.body.scrollHeight);
                    }

                    // Copy code function
                    function copyCode(button) {
                        const codeData = button.getAttribute('data-code');
                        const code = decodeURIComponent(escape(atob(codeData)));

                        console.log('Copying code, length:', code.length);

                        const textarea = document.createElement('textarea');
                        textarea.value = code;
                        textarea.style.position = 'fixed';
                        textarea.style.opacity = '0';
                        document.body.appendChild(textarea);
                        textarea.select();

                        try {
                            document.execCommand('copy');
                            console.log('Code copied successfully');

                            const originalHTML = button.innerHTML;
                            button.classList.add('copied');
                            button.innerHTML = \`
                                <svg class="copy-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                                    <polyline points="20 6 9 17 4 12"></polyline>
                                </svg>
                                Copied!
                            \`;

                            setTimeout(() => {
                                button.classList.remove('copied');
                                button.innerHTML = originalHTML;
                            }, 2000);
                        } catch (err) {
                            console.error('Failed to copy:', err);
                        }

                        document.body.removeChild(textarea);
                    }

                    // Initialize on load
                    window.addEventListener('DOMContentLoaded', function() {
                        console.log('DOM loaded, initializing chat...');
                        configureMarked();
                        renderMessages();
                    });
                </script>
            </body>
            </html>
        `;

        return html;
    }
};

/**
 * Entry function called by the app
 * @param {string} prompt - User input
 * @returns {object} Result object with content, type, and replace properties
 */
function runPlugin(prompt) {
    console.log("runPlugin called with prompt: '" + prompt + "'");

    // Add user message to history
    if (prompt && prompt.trim() !== "") {
        console.log("Adding user message to history");
        plugin.messages.push({
            role: "user",
            content: prompt,
            timestamp: new Date().toISOString()
        });

        // Check if streaming is available
        if (typeof callAIStream !== 'undefined') {
            console.log("callAIStream is available, using streaming API");
            plugin.isStreaming = true;

            // Add placeholder for AI response
            plugin.messages.push({
                role: "assistant",
                content: "",
                timestamp: new Date().toISOString(),
                isStreaming: true
            });
            console.log("Added placeholder AI message, total messages: " + plugin.messages.length);

            // Start streaming
            callAIStream(
                prompt,
                function onChunk(chunk) {
                    // Append chunk to the last message
                    var lastMessage = plugin.messages[plugin.messages.length - 1];
                    lastMessage.content += chunk;

                    // Trigger UI update with generated HTML
                    if (typeof updateUI !== 'undefined') {
                        var html = plugin.generateHTML();
                        updateUI(html);
                    }
                },
                function onComplete(error) {
                    console.log("Stream complete, error: " + error);
                    plugin.isStreaming = false;
                    var lastMessage = plugin.messages[plugin.messages.length - 1];
                    lastMessage.isStreaming = false;

                    if (error) {
                        console.log("Setting error message: " + error);
                        lastMessage.content = "Error: " + error;
                    }

                    // Final UI update with generated HTML
                    if (typeof updateUI !== 'undefined') {
                        var html = plugin.generateHTML();
                        updateUI(html);
                    }
                }
            );
            console.log("callAIStream initiated");

        } else if (typeof callAISync !== 'undefined') {
            // Fallback to synchronous API
            var aiResponse = "";
            try {
                aiResponse = callAISync(prompt);
            } catch (error) {
                aiResponse = "Error calling AI: " + error.toString();
            }

            plugin.messages.push({
                role: "assistant",
                content: aiResponse,
                timestamp: new Date().toISOString()
            });
        } else {
            // No AI integration available
            plugin.messages.push({
                role: "assistant",
                content: "AI integration is not available. Please ensure your AI provider is configured in Settings.",
                timestamp: new Date().toISOString()
            });
        }
    }

    // Return the rendered HTML
    var html = plugin.generateHTML();

    return {
        content: html,
        type: "html",
        replace: true
    };
}

// Export plugin
if (typeof module !== 'undefined' && module.exports) {
    module.exports = plugin;
}
