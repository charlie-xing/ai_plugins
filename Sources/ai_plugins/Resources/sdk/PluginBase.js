/**
 * PluginBase - 所有插件的基类
 * @version 1.0.0
 * @description 提供插件生命周期管理和通用功能
 */

(function(window) {
    'use strict';

    /**
     * 插件基类
     * 所有插件都应该继承此类并实现相应的生命周期方法
     */
    class PluginBase {
        constructor() {
            this.name = 'BasePlugin';
            this.version = '1.0.0';
            this.isInitialized = false;
            this.context = null;
            this.state = {};
        }

        // ============= 生命周期方法 =============

        /**
         * 插件初始化
         * @param {Object} context - 插件上下文
         * @param {Object} context.settings - 应用设置
         * @param {string} context.pluginId - 插件ID
         * @param {string} context.tabId - 标签页ID
         * @returns {Promise<void>}
         */
        async onInit(context) {
            console.log(`[${this.name}] Initializing...`);
            this.context = context;
            this.isInitialized = true;
        }

        /**
         * 插件运行（必须实现）
         * @param {string} userInput - 用户输入
         * @returns {Promise<void>}
         */
        async onRun(userInput) {
            throw new Error(`[${this.name}] onRun() must be implemented by subclass`);
        }

        /**
         * 插件暂停
         * @returns {Promise<void>}
         */
        async onPause() {
            console.log(`[${this.name}] Paused`);
        }

        /**
         * 插件恢复
         * @returns {Promise<void>}
         */
        async onResume() {
            console.log(`[${this.name}] Resumed`);
        }

        /**
         * 插件销毁
         * @returns {Promise<void>}
         */
        async onDestroy() {
            console.log(`[${this.name}] Destroying...`);
            this.cleanup();
        }

        // ============= 通用方法 =============

        /**
         * 获取插件设置
         * @returns {Object} 应用设置对象
         */
        getSettings() {
            return this.context?.settings || {};
        }

        /**
         * 设置插件状态
         * @param {string} key - 状态键
         * @param {any} value - 状态值
         */
        setState(key, value) {
            this.state[key] = value;
        }

        /**
         * 获取插件状态
         * @param {string} key - 状态键
         * @param {any} defaultValue - 默认值
         * @returns {any} 状态值
         */
        getState(key, defaultValue = null) {
            return this.state[key] !== undefined ? this.state[key] : defaultValue;
        }

        /**
         * 清理资源（在销毁前调用）
         */
        cleanup() {
            // 子类可以重写此方法以清理资源
            this.state = {};
        }

        /**
         * 日志输出
         * @param {string} message - 日志消息
         */
        log(message) {
            PluginSDK.Log.info(`[${this.name}] ${message}`);
        }

        /**
         * 错误日志
         * @param {string} message - 错误消息
         */
        error(message) {
            PluginSDK.Log.error(`[${this.name}] ${message}`);
        }
    }

    /**
     * UIPlugin - UI类插件基类
     * 提供UI构建的辅助方法
     */
    class UIPlugin extends PluginBase {
        constructor() {
            super();
            this.container = null;
        }

        async onInit(context) {
            await super.onInit(context);
            this.createContainer();
        }

        /**
         * 创建插件容器
         */
        createContainer() {
            if (!this.container) {
                this.container = document.createElement('div');
                this.container.className = 'plugin-container';
                this.container.id = `plugin-${this.context.pluginId}`;
                document.body.appendChild(this.container);
            }
            return this.container;
        }

        /**
         * 清空容器
         */
        clearContainer() {
            if (this.container) {
                this.container.innerHTML = '';
            }
        }

        /**
         * 设置容器HTML
         * @param {string} html - HTML内容
         */
        setHTML(html) {
            if (this.container) {
                this.container.innerHTML = html;
            }
        }

        /**
         * 添加样式
         * @param {string} css - CSS样式
         */
        addStyles(css) {
            const style = document.createElement('style');
            style.textContent = css;
            document.head.appendChild(style);
        }

        cleanup() {
            super.cleanup();
            if (this.container) {
                this.container.remove();
                this.container = null;
            }
        }
    }

    /**
     * ChatPlugin - 聊天类插件基类
     * 提供消息管理、流式响应等聊天相关功能
     */
    class ChatPlugin extends UIPlugin {
        constructor() {
            super();
            this.messages = window.SAVED_MESSAGES || [];
            this.currentStreamingMessage = null;
        }

        async onInit(context) {
            await super.onInit(context);
            this.setupMessageHandlers();
            this.setupUI();

            // 如果有保存的消息，渲染它们
            if (this.messages.length > 0) {
                this.log(`Restored ${this.messages.length} messages from saved session`);
                this.renderMessages();
            }
        }

        /**
         * 设置消息处理器
         */
        setupMessageHandlers() {
            window.onStreamChunk = (chunk) => {
                if (this.currentStreamingMessage) {
                    this.currentStreamingMessage.content += chunk;
                    this.updateMessageUI(this.messages.length - 1);
                }
            };

            window.onStreamComplete = () => {
                if (this.currentStreamingMessage) {
                    this.currentStreamingMessage.streaming = false;
                    this.currentStreamingMessage = null;
                    this.updateMessageUI(this.messages.length - 1);
                }
            };

            window.onStreamError = (error) => {
                if (this.currentStreamingMessage) {
                    this.currentStreamingMessage.content = `错误: ${error}`;
                    this.currentStreamingMessage.streaming = false;
                    this.currentStreamingMessage = null;
                    this.updateMessageUI(this.messages.length - 1);
                }
            };
        }

        /**
         * 设置UI（由子类实现）
         */
        setupUI() {
            // 子类实现具体的UI设置
        }

        /**
         * 添加用户消息
         * @param {string} content - 消息内容
         */
        addUserMessage(content) {
            const message = {
                role: 'user',
                content: content,
                timestamp: Date.now(),
                streaming: false
            };
            this.messages.push(message);
            this.renderMessage(message, this.messages.length - 1);
        }

        /**
         * 开始助手消息流
         */
        startAssistantMessage() {
            const message = {
                role: 'assistant',
                content: '',
                timestamp: Date.now(),
                streaming: true
            };
            this.messages.push(message);
            this.currentStreamingMessage = message;
            this.renderMessage(message, this.messages.length - 1);
        }

        /**
         * 发送消息到AI
         * @param {string} userInput - 用户输入
         */
        async sendMessage(userInput) {
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

            // 调用AI API
            PluginSDK.AI.streamChat({
                message: userInput,
                messages: conversationHistory,
                onChunk: (chunk) => window.onStreamChunk(chunk),
                onComplete: () => window.onStreamComplete(),
                onError: (error) => window.onStreamError(error)
            });
        }

        /**
         * 渲染单条消息（由子类实现）
         * @param {Object} message - 消息对象
         * @param {number} index - 消息索引
         */
        renderMessage(message, index) {
            // 子类实现具体的消息渲染逻辑
            console.warn(`[${this.name}] renderMessage() should be implemented by subclass`);
        }

        /**
         * 更新消息UI（由子类实现）
         * @param {number} index - 消息索引
         */
        updateMessageUI(index) {
            // 子类实现具体的UI更新逻辑
            console.warn(`[${this.name}] updateMessageUI() should be implemented by subclass`);
        }

        /**
         * 渲染所有消息
         */
        renderMessages() {
            this.messages.forEach((msg, index) => {
                this.renderMessage(msg, index);
            });
        }

        /**
         * 清空对话
         */
        clearMessages() {
            this.messages = [];
            this.currentStreamingMessage = null;
            const container = document.getElementById('chat-container');
            if (container) {
                container.innerHTML = '';
            }
        }

        async onRun(userInput) {
            await this.sendMessage(userInput);
        }
    }

    // 暴露到全局
    window.PluginBase = PluginBase;
    window.ChatPlugin = ChatPlugin;
    window.UIPlugin = UIPlugin;

    console.log('[PluginBase] Plugin base classes loaded');

})(window);
