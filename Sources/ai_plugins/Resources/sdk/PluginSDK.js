/**
 * PluginSDK - JavaScript与Swift通信的标准SDK
 * @version 1.0.0
 * @description 为插件开发提供统一的API接口
 */

(function(window) {
    'use strict';

    /**
     * 插件SDK主对象
     */
    const PluginSDK = {
        version: '1.0.0',

        /**
         * 获取插件上下文信息
         * @returns {Object} 包含settings、pluginId、tabId的上下文对象
         */
        getContext() {
            return {
                settings: window.INITIAL_SETTINGS || {},
                pluginId: window.PLUGIN_ID || 'unknown',
                tabId: window.TAB_ID || 'unknown',
                apiVersion: window.PLUGIN_API_VERSION || '1.0.0'
            };
        },

        /**
         * AI相关API
         */
        AI: {
            /**
             * 调用AI流式聊天API
             * @param {Object} params - 参数对象
             * @param {string} params.message - 当前用户消息
             * @param {Array<{role: string, content: string}>} [params.messages] - 历史消息数组
             * @param {Function} params.onChunk - 接收数据块的回调函数
             * @param {Function} params.onComplete - 完成时的回调函数
             * @param {Function} params.onError - 错误时的回调函数
             * @example
             * PluginSDK.AI.streamChat({
             *   message: '你好',
             *   messages: [{role: 'user', content: '之前的消息'}],
             *   onChunk: (chunk) => console.log(chunk),
             *   onComplete: () => console.log('完成'),
             *   onError: (error) => console.error(error)
             * });
             */
            streamChat(params) {
                if (!params.message && (!params.messages || params.messages.length === 0)) {
                    console.error('[PluginSDK] streamChat: message or messages is required');
                    return;
                }

                // 设置全局回调
                window.onStreamChunk = params.onChunk || function() {};
                window.onStreamComplete = params.onComplete || function() {};
                window.onStreamError = params.onError || function() {};

                // 调用Swift Bridge
                try {
                    window.webkit.messageHandlers.callAI.postMessage({
                        action: 'callAIStream',
                        message: params.message || '',
                        messages: params.messages || []
                    });
                } catch (error) {
                    console.error('[PluginSDK] streamChat failed:', error);
                    if (params.onError) {
                        params.onError(error.message || 'Failed to call AI');
                    }
                }
            }
        },

        /**
         * 设置相关API
         */
        Settings: {
            /**
             * 获取应用设置
             * @param {Function} callback - 接收设置对象的回调函数
             * @example
             * PluginSDK.Settings.get((settings) => {
             *   console.log('API端点:', settings.apiEndpoint);
             *   console.log('用户名:', settings.userName);
             * });
             */
            get(callback) {
                if (typeof callback !== 'function') {
                    console.error('[PluginSDK] Settings.get: callback must be a function');
                    return;
                }

                window.onSettings = callback;

                try {
                    window.webkit.messageHandlers.getSettings.postMessage({
                        action: 'getSettings'
                    });
                } catch (error) {
                    console.error('[PluginSDK] Settings.get failed:', error);
                    callback({});
                }
            }
        },

        /**
         * Python脚本执行API
         */
        Python: {
            /**
             * 运行Python脚本
             * @param {Object} params - 参数对象
             * @param {string} params.script - Python脚本文件名
             * @param {Object} params.input - 传递给脚本的输入数据
             * @param {Function} params.onOutput - 接收输出的回调函数
             * @param {Function} params.onError - 错误时的回调函数
             * @example
             * PluginSDK.Python.runScript({
             *   script: 'process_image.py',
             *   input: { image: 'base64data...', prompt: 'make it blue' },
             *   onOutput: (output) => console.log('Python输出:', output),
             *   onError: (error) => console.error('Python错误:', error)
             * });
             */
            runScript(params) {
                if (!params.script) {
                    console.error('[PluginSDK] Python.runScript: script name is required');
                    return;
                }

                window.onPythonScriptOutput = params.onOutput || function() {};
                window.onPythonScriptError = params.onError || function() {};

                try {
                    window.webkit.messageHandlers.runPythonScript.postMessage({
                        action: 'runPythonScript',
                        script: params.script,
                        input: JSON.stringify(params.input || {})
                    });
                } catch (error) {
                    console.error('[PluginSDK] Python.runScript failed:', error);
                    if (params.onError) {
                        params.onError(error.message || 'Failed to run Python script');
                    }
                }
            }
        },

        /**
         * 命令执行API
         */
        Command: {
            /**
             * 执行系统命令
             * @param {Object} params - 参数对象
             * @param {string} params.command - 要执行的命令
             * @param {Array<string>} params.args - 命令参数数组
             * @returns {Promise<{output: string}>} 返回命令输出的Promise
             * @example
             * PluginSDK.Command.execute({
             *   command: 'ls',
             *   args: ['-la']
             * }).then(result => {
             *   console.log('命令输出:', result.output);
             * }).catch(error => {
             *   console.error('命令失败:', error);
             * });
             */
            execute(params) {
                return new Promise((resolve, reject) => {
                    if (!params.command) {
                        reject(new Error('Command is required'));
                        return;
                    }

                    const callbackId = `cmd_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;

                    // 初始化回调存储
                    window.executeCallbacks = window.executeCallbacks || {};
                    window.executeCallbacks[callbackId] = (success, output) => {
                        if (success) {
                            resolve({ output });
                        } else {
                            reject(new Error(output));
                        }
                    };

                    try {
                        window.webkit.messageHandlers.callAI.postMessage({
                            action: 'executeCode',
                            command: params.command,
                            args: params.args || [],
                            callbackId: callbackId
                        });
                    } catch (error) {
                        delete window.executeCallbacks[callbackId];
                        reject(error);
                    }
                });
            }
        },

        /**
         * 日志API
         */
        Log: {
            /**
             * 输出信息日志
             * @param {string} message - 日志消息
             */
            info(message) {
                console.log(`[Plugin] ${message}`);
                this._sendLog(message);
            },

            /**
             * 输出警告日志
             * @param {string} message - 警告消息
             */
            warn(message) {
                console.warn(`[Plugin] ${message}`);
                this._sendLog(`WARN: ${message}`);
            },

            /**
             * 输出错误日志
             * @param {string} message - 错误消息
             */
            error(message) {
                console.error(`[Plugin] ${message}`);
                this._sendLog(`ERROR: ${message}`);
            },

            /**
             * 输出调试日志
             * @param {string} message - 调试消息
             */
            debug(message) {
                console.debug(`[Plugin] ${message}`);
                this._sendLog(`DEBUG: ${message}`);
            },

            _sendLog(message) {
                try {
                    window.webkit.messageHandlers.log.postMessage({
                        action: 'log',
                        message: message
                    });
                } catch (error) {
                    // Silently fail if Swift bridge is not available
                }
            }
        },

        /**
         * 本地存储API
         */
        Storage: {
            /**
             * 存储数据
             * @param {string} key - 键名
             * @param {any} value - 要存储的值（会自动序列化为JSON）
             * @example
             * PluginSDK.Storage.set('user_preference', { theme: 'dark' });
             */
            set(key, value) {
                try {
                    const pluginId = window.PLUGIN_ID || 'unknown';
                    const storageKey = `plugin_${pluginId}_${key}`;
                    localStorage.setItem(storageKey, JSON.stringify(value));
                } catch (error) {
                    console.error('[PluginSDK] Storage.set failed:', error);
                }
            },

            /**
             * 获取存储的数据
             * @param {string} key - 键名
             * @param {any} [defaultValue=null] - 默认值
             * @returns {any} 存储的值（自动反序列化）
             * @example
             * const preference = PluginSDK.Storage.get('user_preference', { theme: 'light' });
             */
            get(key, defaultValue = null) {
                try {
                    const pluginId = window.PLUGIN_ID || 'unknown';
                    const storageKey = `plugin_${pluginId}_${key}`;
                    const value = localStorage.getItem(storageKey);
                    return value ? JSON.parse(value) : defaultValue;
                } catch (error) {
                    console.error('[PluginSDK] Storage.get failed:', error);
                    return defaultValue;
                }
            },

            /**
             * 删除存储的数据
             * @param {string} key - 键名
             */
            remove(key) {
                try {
                    const pluginId = window.PLUGIN_ID || 'unknown';
                    const storageKey = `plugin_${pluginId}_${key}`;
                    localStorage.removeItem(storageKey);
                } catch (error) {
                    console.error('[PluginSDK] Storage.remove failed:', error);
                }
            },

            /**
             * 清空所有存储的数据
             */
            clear() {
                try {
                    const pluginId = window.PLUGIN_ID || 'unknown';
                    const prefix = `plugin_${pluginId}_`;
                    const keysToRemove = [];

                    for (let i = 0; i < localStorage.length; i++) {
                        const key = localStorage.key(i);
                        if (key && key.startsWith(prefix)) {
                            keysToRemove.push(key);
                        }
                    }

                    keysToRemove.forEach(key => localStorage.removeItem(key));
                } catch (error) {
                    console.error('[PluginSDK] Storage.clear failed:', error);
                }
            }
        },

        /**
         * UI工具API
         */
        UI: {
            /**
             * 显示加载遮罩
             * @param {string} [message='加载中...'] - 加载提示消息
             */
            showLoading(message = '加载中...') {
                const existing = document.getElementById('plugin-sdk-loading');
                if (existing) return;

                const overlay = document.createElement('div');
                overlay.id = 'plugin-sdk-loading';
                overlay.style.cssText = `
                    position: fixed;
                    top: 0;
                    left: 0;
                    right: 0;
                    bottom: 0;
                    background: rgba(0,0,0,0.5);
                    display: flex;
                    align-items: center;
                    justify-content: center;
                    z-index: 9999;
                `;

                overlay.innerHTML = `
                    <div style="background: white; padding: 30px; border-radius: 12px; text-align: center; box-shadow: 0 4px 20px rgba(0,0,0,0.2);">
                        <div style="border: 3px solid #f3f3f3; border-top: 3px solid #667eea; border-radius: 50%; width: 40px; height: 40px; animation: spin 1s linear infinite; margin: 0 auto 15px;"></div>
                        <div style="color: #333; font-size: 14px;">${message}</div>
                    </div>
                    <style>
                        @keyframes spin { 0% { transform: rotate(0deg); } 100% { transform: rotate(360deg); } }
                        @media (prefers-color-scheme: dark) {
                            #plugin-sdk-loading > div { background: #1c1c1e; }
                            #plugin-sdk-loading > div > div:last-child { color: #f5f5f7; }
                        }
                    </style>
                `;

                document.body.appendChild(overlay);
            },

            /**
             * 隐藏加载遮罩
             */
            hideLoading() {
                const overlay = document.getElementById('plugin-sdk-loading');
                if (overlay) {
                    overlay.remove();
                }
            },

            /**
             * 显示Toast提示
             * @param {string} message - 提示消息
             * @param {string} [type='info'] - 类型: 'info', 'success', 'error', 'warning'
             * @param {number} [duration=3000] - 显示时长（毫秒）
             */
            showToast(message, type = 'info', duration = 3000) {
                const colors = {
                    info: '#007aff',
                    success: '#34c759',
                    error: '#ff3b30',
                    warning: '#ff9500'
                };

                const toast = document.createElement('div');
                toast.style.cssText = `
                    position: fixed;
                    top: 20px;
                    left: 50%;
                    transform: translateX(-50%);
                    background: ${colors[type] || colors.info};
                    color: white;
                    padding: 12px 24px;
                    border-radius: 8px;
                    font-size: 14px;
                    z-index: 10000;
                    box-shadow: 0 4px 12px rgba(0,0,0,0.15);
                    animation: slideDown 0.3s ease-out;
                `;

                toast.textContent = message;

                const style = document.createElement('style');
                style.textContent = `
                    @keyframes slideDown {
                        from { opacity: 0; transform: translateX(-50%) translateY(-20px); }
                        to { opacity: 1; transform: translateX(-50%) translateY(0); }
                    }
                `;
                document.head.appendChild(style);

                document.body.appendChild(toast);

                setTimeout(() => {
                    toast.style.animation = 'slideDown 0.3s ease-out reverse';
                    setTimeout(() => {
                        toast.remove();
                        style.remove();
                    }, 300);
                }, duration);
            }
        },

        /**
         * 工具函数
         */
        Utils: {
            /**
             * 转义HTML特殊字符
             * @param {string} str - 要转义的字符串
             * @returns {string} 转义后的字符串
             */
            escapeHtml(str) {
                const div = document.createElement('div');
                div.textContent = str;
                return div.innerHTML;
            },

            /**
             * 防抖函数
             * @param {Function} func - 要防抖的函数
             * @param {number} wait - 等待时间（毫秒）
             * @returns {Function} 防抖后的函数
             */
            debounce(func, wait) {
                let timeout;
                return function(...args) {
                    clearTimeout(timeout);
                    timeout = setTimeout(() => func.apply(this, args), wait);
                };
            },

            /**
             * 节流函数
             * @param {Function} func - 要节流的函数
             * @param {number} limit - 时间限制（毫秒）
             * @returns {Function} 节流后的函数
             */
            throttle(func, limit) {
                let inThrottle;
                return function(...args) {
                    if (!inThrottle) {
                        func.apply(this, args);
                        inThrottle = true;
                        setTimeout(() => inThrottle = false, limit);
                    }
                };
            },

            /**
             * 格式化文件大小
             * @param {number} bytes - 字节数
             * @returns {string} 格式化后的大小
             */
            formatFileSize(bytes) {
                if (bytes === 0) return '0 B';
                const k = 1024;
                const sizes = ['B', 'KB', 'MB', 'GB'];
                const i = Math.floor(Math.log(bytes) / Math.log(k));
                return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i];
            }
        }
    };

    // 将PluginSDK暴露到全局
    window.PluginSDK = PluginSDK;

    // 初始化日志
    console.log(`[PluginSDK] v${PluginSDK.version} loaded`);

})(window);
