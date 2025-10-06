/**
 * @name Test Chat (Streaming)
 * @description Claude-style chat with real streaming and typewriter effect
 * @author AI Assistant
 * @version 4.5.0
 * @entryFunction runPlugin
 * @mode Chat
 */

var ChatApp = {
    messages: [],
    settings: {},
    htmlLoaded: false,

    init: function() {
        this.settings = getSettings();
        log('Chat initialized');
    },

    loadInitialHTML: function() {
        if (this.htmlLoaded) return;

        var html = '<!DOCTYPE html>' +
'<html>' +
'<head>' +
'    <meta charset="UTF-8">' +
'    <script src="https://cdn.jsdelivr.net/npm/marked@11.1.1/marked.min.js"></script>' +
'    <script src="https://cdn.jsdelivr.net/npm/highlight.js@11.9.0/lib/index.min.js"></script>' +
'    <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/highlight.js@11.9.0/styles/atom-one-dark.min.css">' +
'    <style>' +
'        * { margin: 0; padding: 0; box-sizing: border-box; }' +
'        body {' +
'            font-family: -apple-system, BlinkMacSystemFont, sans-serif;' +
'            background: transparent;' +
'            color: #1a1a1a;' +
'            padding: 20px;' +
'            line-height: 1.6;' +
'        }' +
'        @media (prefers-color-scheme: dark) { body { color: #e8e8e8; } }' +
'        .message { margin-bottom: 24px; opacity: 0; animation: fadeIn 0.3s ease-in forwards; }' +
'        @keyframes fadeIn { to { opacity: 1; } }' +
'        .message-header { display: flex; align-items: center; margin-bottom: 8px; font-size: 13px; font-weight: 500; }' +
'        .avatar { width: 28px; height: 28px; border-radius: 50%; margin-right: 10px; display: flex; align-items: center; justify-content: center; font-size: 16px; }' +
'        .user .avatar { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); }' +
'        .assistant .avatar { background: linear-gradient(135deg, #f093fb 0%, #f5576c 100%); }' +
'        .message-content { padding-left: 38px; font-size: 15px; }' +
'        .message-content p { margin-bottom: 12px; }' +
'        .message-content pre { background: #282c34; border-radius: 8px; padding: 16px; margin: 12px 0; }' +
'        .message-content code { font-family: "SF Mono", Monaco, Consolas, monospace; font-size: 13px; }' +
'        .message-content pre code { background: none; padding: 0; }' +
'        .message-content :not(pre) > code { background: rgba(135,131,120,0.15); color: #eb5757; padding: 2px 6px; border-radius: 3px; }' +
'        .streaming-cursor { display: inline-block; width: 2px; height: 1em; background-color: currentColor; margin-left: 2px; animation: blink 1s infinite; vertical-align: text-bottom; }' +
'        @keyframes blink { 0%, 50% { opacity: 1; } 51%, 100% { opacity: 0; } }' +
'    </style>' +
'</head>' +
'<body>' +
'    <div id="chat-container"></div>' +
'    <script>' +
'        var messages = [];' +
'        marked.setOptions({ breaks: true, gfm: true });' +
'        function renderMessages() {' +
'            var container = document.getElementById("chat-container");' +
'            container.innerHTML = "";' +
'            messages.forEach(function(msg) {' +
'                var div = document.createElement("div");' +
'                div.className = "message " + msg.role;' +
'                var avatar = msg.role === "user" ? "👤" : "🤖";' +
'                var name = msg.role === "user" ? "User" : "Assistant";' +
'                var content = marked.parse(msg.content || "");' +
'                var cursor = msg.streaming ? "<span class=\\"streaming-cursor\\"></span>" : "";' +
'                div.innerHTML = "<div class=\\"message-header\\">" +' +
'                    "<div class=\\"avatar\\">" + avatar + "</div>" +' +
'                    "<span>" + name + "</span>" +' +
'                    "</div>" +' +
'                    "<div class=\\"message-content\\">" + content + cursor + "</div>";' +
'                container.appendChild(div);' +
'            });' +
'            window.scrollTo(0, document.body.scrollHeight);' +
'        }' +
'        window.updateMessages = function(newMessages) {' +
'            messages = newMessages;' +
'            renderMessages();' +
'        };' +
'    </script>' +
'</body>' +
'</html>';

        updateUI(html);
        this.htmlLoaded = true;
        log('Initial HTML loaded');
    },

    updateWebView: function() {
        var messagesJSON = JSON.stringify(this.messages);
        var jsCode = 'window.updateMessages(' + messagesJSON + ');';
        var scriptTag = '<script>' + jsCode + '</script>';

        updateUI(scriptTag);
    },

    addUserMessage: function(content) {
        this.messages.push({
            role: 'user',
            content: content,
            streaming: false
        });
        this.updateWebView();
    },

    startAssistantMessage: function() {
        this.messages.push({
            role: 'assistant',
            content: '',
            streaming: true
        });
        this.updateWebView();
    },

    appendToLastMessage: function(chunk) {
        if (this.messages.length > 0) {
            this.messages[this.messages.length - 1].content += chunk;
        }
    },

    finishLastMessage: function() {
        if (this.messages.length > 0) {
            this.messages[this.messages.length - 1].streaming = false;
        }
    },

    sendMessage: function(userPrompt) {
        log('Sending: ' + userPrompt);

        this.addUserMessage(userPrompt);
        this.startAssistantMessage();

        var chunkCount = 0;
        var self = this;

        log('Calling callAIStream...');
        callAIStream(
            userPrompt,
            function(chunk) {
                chunkCount++;
                log('Received chunk #' + chunkCount + ': ' + chunk);
                self.appendToLastMessage(chunk);

                // Update every 2 chunks
                if (chunkCount % 2 === 0) {
                    log('Updating WebView (every 2 chunks)');
                    self.updateWebView();
                }
            },
            function(error) {
                log('Stream completed callback, error: ' + (error || 'none'));
                self.finishLastMessage();

                if (error) {
                    log('Error: ' + error);
                    self.messages[self.messages.length - 1].content = 'Error: ' + error;
                }

                log('Final WebView update');
                self.updateWebView();
                log('Done - Total chunks: ' + chunkCount);
            }
        );
    }
};

function runPlugin(userPrompt) {
    log('runPlugin called');

    ChatApp.init();
    ChatApp.loadInitialHTML();
    ChatApp.sendMessage(userPrompt);

    return undefined;
}
