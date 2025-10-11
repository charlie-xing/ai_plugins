/**
 * @name Image to Image Editor (Qwen)
 * @description Edit images using Qwen-Image-Edit-2509 model
 * @author AI Assistant
 * @version 1.0.0
 * @entryFunction runPlugin
 * @mode Chat
 */

class ImageEditor {
    constructor() {
        this.uploadedImages = [];
        this.currentPrompt = '';
        this.generatedImages = [];
        this.settings = {
            num_inference_steps: 40,
            true_cfg_scale: 4.0,
            guidance_scale: 1.0,
            seed: -1  // -1 means random
        };
        this.isInitialized = false;
        this.isGenerating = false;
    }

    init() {
        if (this.isInitialized) return;

        console.log('ImageEditor initializing...');
        this.setupStyles();
        this.render();
        this.setupEventListeners();
        this.setupMessageHandlers();
        this.isInitialized = true;
        console.log('ImageEditor initialized');
    }

    setupStyles() {
        const style = document.createElement('style');
        style.textContent = `
            * { margin: 0; padding: 0; box-sizing: border-box; }

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

            .container {
                max-width: 1000px;
                margin: 0 auto;
            }

            .header {
                text-align: center;
                margin-bottom: 40px;
            }

            .header h1 {
                font-size: 36px;
                font-weight: 700;
                margin-bottom: 10px;
                background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                -webkit-background-clip: text;
                -webkit-text-fill-color: transparent;
                background-clip: text;
            }

            .header p {
                font-size: 16px;
                color: #86868b;
            }

            .section {
                background: white;
                border-radius: 16px;
                padding: 30px;
                margin-bottom: 20px;
                box-shadow: 0 4px 20px rgba(0,0,0,0.08);
            }

            @media (prefers-color-scheme: dark) {
                .section {
                    background: #1c1c1e;
                    box-shadow: 0 4px 20px rgba(0,0,0,0.3);
                }
            }

            .section-title {
                font-size: 20px;
                font-weight: 600;
                margin-bottom: 20px;
                display: flex;
                align-items: center;
                gap: 10px;
            }

            /* Upload Area */
            .upload-area {
                border: 2px dashed #d2d2d7;
                border-radius: 12px;
                padding: 40px;
                text-align: center;
                cursor: pointer;
                transition: all 0.3s ease;
                background: #f5f5f7;
            }

            @media (prefers-color-scheme: dark) {
                .upload-area {
                    border-color: #3a3a3c;
                    background: #2c2c2e;
                }
            }

            .upload-area:hover {
                border-color: #667eea;
                background: #fafafa;
            }

            @media (prefers-color-scheme: dark) {
                .upload-area:hover {
                    background: #3a3a3c;
                }
            }

            .upload-area.drag-over {
                border-color: #667eea;
                background: #f0f0ff;
            }

            @media (prefers-color-scheme: dark) {
                .upload-area.drag-over {
                    background: #2a2a4a;
                }
            }

            .upload-icon {
                font-size: 48px;
                margin-bottom: 10px;
            }

            .upload-text {
                font-size: 16px;
                color: #86868b;
                margin-bottom: 5px;
            }

            .upload-hint {
                font-size: 13px;
                color: #a1a1a6;
            }

            #file-input {
                display: none;
            }

            /* Image Preview Grid */
            .image-preview-grid {
                display: grid;
                grid-template-columns: repeat(auto-fill, minmax(200px, 1fr));
                gap: 15px;
                margin-top: 20px;
            }

            .image-preview-item {
                position: relative;
                border-radius: 12px;
                overflow: hidden;
                aspect-ratio: 1;
                box-shadow: 0 2px 10px rgba(0,0,0,0.1);
            }

            .image-preview-item img {
                width: 100%;
                height: 100%;
                object-fit: cover;
            }

            .remove-image-btn {
                position: absolute;
                top: 8px;
                right: 8px;
                background: rgba(0,0,0,0.6);
                color: white;
                border: none;
                border-radius: 50%;
                width: 28px;
                height: 28px;
                cursor: pointer;
                display: flex;
                align-items: center;
                justify-content: center;
                font-size: 16px;
                transition: background 0.2s;
            }

            .remove-image-btn:hover {
                background: rgba(255,0,0,0.8);
            }

            /* Prompt Area */
            .prompt-input {
                width: 100%;
                min-height: 120px;
                padding: 16px;
                border: 2px solid #d2d2d7;
                border-radius: 12px;
                font-size: 15px;
                font-family: inherit;
                resize: vertical;
                transition: border-color 0.3s;
                background: white;
            }

            @media (prefers-color-scheme: dark) {
                .prompt-input {
                    background: #2c2c2e;
                    border-color: #3a3a3c;
                    color: #f5f5f7;
                }
            }

            .prompt-input:focus {
                outline: none;
                border-color: #667eea;
            }

            /* Settings */
            .setting-item {
                margin-bottom: 20px;
            }

            .setting-label {
                display: flex;
                justify-content: space-between;
                margin-bottom: 8px;
                font-size: 14px;
                font-weight: 500;
            }

            .setting-value {
                color: #667eea;
                font-weight: 600;
            }

            .slider {
                width: 100%;
                height: 6px;
                border-radius: 3px;
                background: #d2d2d7;
                outline: none;
                -webkit-appearance: none;
            }

            @media (prefers-color-scheme: dark) {
                .slider {
                    background: #3a3a3c;
                }
            }

            .slider::-webkit-slider-thumb {
                -webkit-appearance: none;
                appearance: none;
                width: 20px;
                height: 20px;
                border-radius: 50%;
                background: #667eea;
                cursor: pointer;
                box-shadow: 0 2px 8px rgba(102,126,234,0.4);
            }

            .slider::-moz-range-thumb {
                width: 20px;
                height: 20px;
                border-radius: 50%;
                background: #667eea;
                cursor: pointer;
                border: none;
                box-shadow: 0 2px 8px rgba(102,126,234,0.4);
            }

            /* Buttons */
            .btn {
                padding: 14px 32px;
                border: none;
                border-radius: 12px;
                font-size: 16px;
                font-weight: 600;
                cursor: pointer;
                transition: all 0.3s ease;
                display: inline-flex;
                align-items: center;
                gap: 8px;
            }

            .btn-primary {
                background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                color: white;
                width: 100%;
                justify-content: center;
            }

            .btn-primary:hover:not(:disabled) {
                transform: translateY(-2px);
                box-shadow: 0 8px 20px rgba(102,126,234,0.3);
            }

            .btn-primary:disabled {
                opacity: 0.5;
                cursor: not-allowed;
            }

            .btn-secondary {
                background: #f5f5f7;
                color: #1d1d1f;
            }

            @media (prefers-color-scheme: dark) {
                .btn-secondary {
                    background: #2c2c2e;
                    color: #f5f5f7;
                }
            }

            .btn-secondary:hover {
                background: #e8e8ed;
            }

            @media (prefers-color-scheme: dark) {
                .btn-secondary:hover {
                    background: #3a3a3c;
                }
            }

            /* Loading */
            .loading-overlay {
                display: none;
                position: fixed;
                top: 0;
                left: 0;
                right: 0;
                bottom: 0;
                background: rgba(0,0,0,0.5);
                z-index: 1000;
                align-items: center;
                justify-content: center;
            }

            .loading-overlay.show {
                display: flex;
            }

            .loading-content {
                background: white;
                padding: 40px;
                border-radius: 20px;
                text-align: center;
                box-shadow: 0 10px 40px rgba(0,0,0,0.2);
            }

            @media (prefers-color-scheme: dark) {
                .loading-content {
                    background: #1c1c1e;
                }
            }

            .spinner {
                border: 4px solid #f3f3f3;
                border-top: 4px solid #667eea;
                border-radius: 50%;
                width: 50px;
                height: 50px;
                animation: spin 1s linear infinite;
                margin: 0 auto 20px;
            }

            @keyframes spin {
                0% { transform: rotate(0deg); }
                100% { transform: rotate(360deg); }
            }

            .loading-text {
                font-size: 16px;
                color: #86868b;
            }

            /* Results */
            .result-image {
                width: 100%;
                border-radius: 12px;
                box-shadow: 0 4px 20px rgba(0,0,0,0.15);
                margin-bottom: 20px;
            }

            .result-actions {
                display: flex;
                gap: 10px;
                justify-content: center;
                margin-top: 20px;
            }

            .comparison-view {
                display: grid;
                grid-template-columns: 1fr 1fr;
                gap: 20px;
                margin-bottom: 20px;
            }

            .comparison-item {
                text-align: center;
            }

            .comparison-label {
                font-size: 14px;
                font-weight: 600;
                margin-bottom: 10px;
                color: #86868b;
            }

            .comparison-item img {
                width: 100%;
                border-radius: 12px;
                box-shadow: 0 2px 10px rgba(0,0,0,0.1);
            }

            /* Messages */
            .message {
                padding: 16px;
                border-radius: 12px;
                margin-bottom: 15px;
                display: flex;
                align-items: start;
                gap: 10px;
            }

            .message-error {
                background: #fff5f5;
                border-left: 4px solid #ff3b30;
                color: #c62828;
            }

            @media (prefers-color-scheme: dark) {
                .message-error {
                    background: #2a1a1a;
                    color: #ff5252;
                }
            }

            .message-success {
                background: #f0f9ff;
                border-left: 4px solid #34c759;
                color: #2e7d32;
            }

            @media (prefers-color-scheme: dark) {
                .message-success {
                    background: #1a2a1a;
                    color: #4caf50;
                }
            }

            .message-info {
                background: #f8f9fa;
                border-left: 4px solid #007aff;
                color: #1976d2;
            }

            @media (prefers-color-scheme: dark) {
                .message-info {
                    background: #1a1a2a;
                    color: #64b5f6;
                }
            }

            /* Advanced Settings Toggle */
            .settings-toggle {
                margin-bottom: 15px;
            }

            .settings-content {
                margin-top: 15px;
            }

            .settings-content.collapsed {
                display: none;
            }
        `;
        document.head.appendChild(style);
    }

    render() {
        const container = document.createElement('div');
        container.className = 'container';
        container.innerHTML = `
            <div class="header">
                <h1>🎨 Qwen Image Editor</h1>
                <p>Transform your images with AI-powered editing</p>
            </div>

            <div class="section">
                <div class="section-title">📸 Upload Images</div>
                <div class="upload-area" id="upload-area">
                    <div class="upload-icon">📁</div>
                    <div class="upload-text">Click to upload or drag and drop</div>
                    <div class="upload-hint">Support 1-3 images (PNG, JPG, JPEG)</div>
                </div>
                <input type="file" id="file-input" accept="image/png,image/jpeg,image/jpg" multiple>
                <div class="image-preview-grid" id="preview-grid"></div>
            </div>

            <div class="section">
                <div class="section-title">✏️ Edit Instructions</div>
                <textarea
                    class="prompt-input"
                    id="prompt-input"
                    placeholder="Describe how you want to edit the image(s)...&#10;&#10;Examples:&#10;- Make the person smile and add sunglasses&#10;- Change the background to a beach sunset&#10;- Transform into watercolor painting style&#10;- Add text 'Hello World' in golden color"
                ></textarea>

                <div style="margin-top: 15px;">
                    <textarea
                        class="prompt-input"
                        id="negative-prompt-input"
                        placeholder="Negative prompt (optional): what you don't want to see..."
                        style="min-height: 60px;"
                    ></textarea>
                </div>
            </div>

            <div class="section">
                <div class="settings-toggle">
                    <div class="section-title" style="cursor: pointer;" id="settings-toggle">
                        ⚙️ Advanced Settings
                        <span style="margin-left: auto; font-size: 14px;">▼</span>
                    </div>
                </div>
                <div class="settings-content" id="settings-content">
                    <div class="setting-item">
                        <div class="setting-label">
                            <span>Inference Steps</span>
                            <span class="setting-value" id="steps-value">40</span>
                        </div>
                        <input type="range" class="slider" id="steps-slider" min="20" max="50" value="40" step="1">
                    </div>

                    <div class="setting-item">
                        <div class="setting-label">
                            <span>True CFG Scale</span>
                            <span class="setting-value" id="cfg-value">4.0</span>
                        </div>
                        <input type="range" class="slider" id="cfg-slider" min="2" max="8" value="4" step="0.1">
                    </div>

                    <div class="setting-item">
                        <div class="setting-label">
                            <span>Guidance Scale</span>
                            <span class="setting-value" id="guidance-value">1.0</span>
                        </div>
                        <input type="range" class="slider" id="guidance-slider" min="0.5" max="2" value="1" step="0.1">
                    </div>

                    <div class="setting-item">
                        <div class="setting-label">
                            <span>Random Seed (-1 for random)</span>
                            <span class="setting-value" id="seed-value">-1</span>
                        </div>
                        <input type="number" class="prompt-input" id="seed-input" value="-1" style="min-height: 40px; padding: 8px 12px;">
                    </div>
                </div>
            </div>

            <div class="section">
                <button class="btn btn-primary" id="generate-btn" disabled>
                    ✨ Generate Edited Image
                </button>
            </div>

            <div id="messages"></div>

            <div class="section" id="results-section" style="display: none;">
                <div class="section-title">🎉 Generated Result</div>
                <div id="results-content"></div>
            </div>

            <div class="loading-overlay" id="loading-overlay">
                <div class="loading-content">
                    <div class="spinner"></div>
                    <div class="loading-text">Generating your image...</div>
                    <div class="loading-text" style="font-size: 13px; margin-top: 5px;">This may take 30-60 seconds</div>
                </div>
            </div>
        `;

        document.body.appendChild(container);
    }

    setupEventListeners() {
        // Upload area events
        const uploadArea = document.getElementById('upload-area');
        const fileInput = document.getElementById('file-input');

        uploadArea.addEventListener('click', () => fileInput.click());

        uploadArea.addEventListener('dragover', (e) => {
            e.preventDefault();
            uploadArea.classList.add('drag-over');
        });

        uploadArea.addEventListener('dragleave', () => {
            uploadArea.classList.remove('drag-over');
        });

        uploadArea.addEventListener('drop', (e) => {
            e.preventDefault();
            uploadArea.classList.remove('drag-over');
            this.handleFiles(e.dataTransfer.files);
        });

        fileInput.addEventListener('change', (e) => {
            this.handleFiles(e.target.files);
        });

        // Settings sliders
        document.getElementById('steps-slider').addEventListener('input', (e) => {
            this.settings.num_inference_steps = parseInt(e.target.value);
            document.getElementById('steps-value').textContent = e.target.value;
        });

        document.getElementById('cfg-slider').addEventListener('input', (e) => {
            this.settings.true_cfg_scale = parseFloat(e.target.value);
            document.getElementById('cfg-value').textContent = parseFloat(e.target.value).toFixed(1);
        });

        document.getElementById('guidance-slider').addEventListener('input', (e) => {
            this.settings.guidance_scale = parseFloat(e.target.value);
            document.getElementById('guidance-value').textContent = parseFloat(e.target.value).toFixed(1);
        });

        document.getElementById('seed-input').addEventListener('input', (e) => {
            this.settings.seed = parseInt(e.target.value);
            document.getElementById('seed-value').textContent = e.target.value;
        });

        // Settings toggle
        document.getElementById('settings-toggle').addEventListener('click', () => {
            const content = document.getElementById('settings-content');
            content.classList.toggle('collapsed');
        });

        // Generate button
        document.getElementById('generate-btn').addEventListener('click', () => {
            this.generateImage();
        });

        // Enable/disable generate button based on inputs
        document.getElementById('prompt-input').addEventListener('input', () => {
            this.updateGenerateButton();
        });
    }

    setupMessageHandlers() {
        // Handle responses from Python script via Swift
        window.onPythonScriptOutput = (output) => {
            try {
                const result = JSON.parse(output);
                console.log('Python script output:', result);

                if (result.status === 'complete') {
                    this.hideLoading();
                    this.displayResult(result);
                    this.showMessage('success', '✅ Image generated successfully!');
                } else if (result.status === 'error') {
                    this.hideLoading();
                    this.showMessage('error', `❌ Error: ${result.error}`);
                } else {
                    // Progress updates
                    console.log('Progress:', result.status);
                    this.updateLoadingText(result.status);
                }
            } catch (e) {
                console.error('Failed to parse Python output:', e);
                this.hideLoading();
                this.showMessage('error', '❌ Failed to process result');
            }
        };

        window.onPythonScriptError = (error) => {
            console.error('Python script error:', error);
            this.hideLoading();
            this.showMessage('error', `❌ Error: ${error}`);
        };
    }

    updateLoadingText(status) {
        const loadingText = document.querySelector('.loading-text');
        if (!loadingText) return;

        const statusMessages = {
            'loading_model': 'Loading Qwen model...',
            'model_loaded': 'Model loaded, processing images...',
            'processing_images': 'Processing input images...',
            'generating': 'Generating edited image...',
            'encoding_result': 'Encoding result...'
        };

        const message = statusMessages[status] || 'Processing...';
        loadingText.textContent = message;
    }

    async handleFiles(files) {
        const maxFiles = 3;
        const maxSize = 10 * 1024 * 1024; // 10MB

        if (this.uploadedImages.length >= maxFiles) {
            this.showMessage('error', `❌ Maximum ${maxFiles} images allowed`);
            return;
        }

        const fileArray = Array.from(files).slice(0, maxFiles - this.uploadedImages.length);

        for (const file of fileArray) {
            if (!file.type.match('image/(png|jpeg|jpg)')) {
                this.showMessage('error', `❌ Invalid file type: ${file.name}`);
                continue;
            }

            if (file.size > maxSize) {
                this.showMessage('error', `❌ File too large: ${file.name} (max 10MB)`);
                continue;
            }

            try {
                const base64 = await this.fileToBase64(file);
                this.uploadedImages.push({
                    name: file.name,
                    data: base64,
                    preview: base64
                });
            } catch (error) {
                console.error('Error reading file:', error);
                this.showMessage('error', `❌ Error reading file: ${file.name}`);
            }
        }

        this.updatePreviewGrid();
        this.updateGenerateButton();
    }

    fileToBase64(file) {
        return new Promise((resolve, reject) => {
            const reader = new FileReader();
            reader.onload = () => {
                // Remove data URL prefix to get pure base64
                const base64 = reader.result.split(',')[1];
                resolve(base64);
            };
            reader.onerror = reject;
            reader.readAsDataURL(file);
        });
    }

    updatePreviewGrid() {
        const grid = document.getElementById('preview-grid');
        grid.innerHTML = '';

        this.uploadedImages.forEach((image, index) => {
            const item = document.createElement('div');
            item.className = 'image-preview-item';
            item.innerHTML = `
                <img src="data:image/jpeg;base64,${image.data}" alt="${image.name}">
                <button class="remove-image-btn" onclick="window.imageEditor.removeImage(${index})">×</button>
            `;
            grid.appendChild(item);
        });
    }

    removeImage(index) {
        this.uploadedImages.splice(index, 1);
        this.updatePreviewGrid();
        this.updateGenerateButton();
    }

    updateGenerateButton() {
        const btn = document.getElementById('generate-btn');
        const prompt = document.getElementById('prompt-input').value.trim();
        const hasImages = this.uploadedImages.length > 0;

        btn.disabled = !hasImages || !prompt || this.isGenerating;
    }

    showLoading() {
        document.getElementById('loading-overlay').classList.add('show');
        this.isGenerating = true;
        this.updateGenerateButton();
    }

    hideLoading() {
        document.getElementById('loading-overlay').classList.remove('show');
        this.isGenerating = false;
        this.updateGenerateButton();
    }

    showMessage(type, message) {
        const messagesDiv = document.getElementById('messages');
        const msgDiv = document.createElement('div');
        msgDiv.className = `message message-${type}`;
        msgDiv.innerHTML = `<div>${message}</div>`;
        messagesDiv.appendChild(msgDiv);

        setTimeout(() => {
            msgDiv.remove();
        }, 5000);
    }

    generateImage() {
        const prompt = document.getElementById('prompt-input').value.trim();
        const negativePrompt = document.getElementById('negative-prompt-input').value.trim();

        if (!prompt || this.uploadedImages.length === 0) {
            this.showMessage('error', '❌ Please upload images and enter a prompt');
            return;
        }

        this.showLoading();

        const requestData = {
            images: this.uploadedImages.map(img => img.data),
            prompt: prompt,
            negative_prompt: negativePrompt || ' ',
            num_inference_steps: this.settings.num_inference_steps,
            true_cfg_scale: this.settings.true_cfg_scale,
            guidance_scale: this.settings.guidance_scale,
            seed: this.settings.seed
        };

        console.log('Sending edit request:', requestData);

        // Call Python script via command line through Swift
        if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.runPythonScript) {
            window.webkit.messageHandlers.runPythonScript.postMessage({
                action: 'runPythonScript',
                script: 'img2img_edit.py',
                input: JSON.stringify(requestData)
            });
        } else {
            // Fallback for testing
            console.warn('Swift message handler not available');
            setTimeout(() => {
                this.hideLoading();
                this.showMessage('error', '❌ Backend not available. Please run in app.');
            }, 1000);
        }
    }

    displayResult(result) {
        const section = document.getElementById('results-section');
        const content = document.getElementById('results-content');

        section.style.display = 'block';

        // Create comparison view with first uploaded image
        const comparisonHTML = this.uploadedImages.length > 0 ? `
            <div class="comparison-view">
                <div class="comparison-item">
                    <div class="comparison-label">Original</div>
                    <img src="data:image/jpeg;base64,${this.uploadedImages[0].data}" alt="Original">
                </div>
                <div class="comparison-item">
                    <div class="comparison-label">Generated</div>
                    <img src="data:image/png;base64,${result.image}" alt="Generated">
                </div>
            </div>
        ` : `
            <img src="data:image/png;base64,${result.image}" alt="Generated" class="result-image">
        `;

        content.innerHTML = `
            ${comparisonHTML}
            <div class="result-actions">
                <button class="btn btn-secondary" onclick="window.imageEditor.downloadImage('${result.image}')">
                    💾 Download Image
                </button>
                <button class="btn btn-secondary" onclick="window.imageEditor.useAsInput('${result.image}')">
                    🔄 Use as Input
                </button>
            </div>
        `;

        // Scroll to results
        section.scrollIntoView({ behavior: 'smooth', block: 'nearest' });

        // Save to history
        this.generatedImages.push({
            image: result.image,
            prompt: document.getElementById('prompt-input').value,
            timestamp: new Date().toISOString()
        });
    }

    downloadImage(base64Data) {
        const link = document.createElement('a');
        link.href = `data:image/png;base64,${base64Data}`;
        link.download = `qwen-edited-${Date.now()}.png`;
        document.body.appendChild(link);
        link.click();
        document.body.removeChild(link);
        this.showMessage('success', '✅ Image downloaded!');
    }

    useAsInput(base64Data) {
        // Clear current images and use generated as new input
        this.uploadedImages = [{
            name: 'generated.png',
            data: base64Data,
            preview: base64Data
        }];
        this.updatePreviewGrid();
        this.updateGenerateButton();
        this.showMessage('info', 'ℹ️ Generated image set as input. You can now edit it further!');

        // Scroll to top
        window.scrollTo({ top: 0, behavior: 'smooth' });
    }
}

// Global instance
if (!window.imageEditor) {
    window.imageEditor = new ImageEditor();
}

// Entry point
function runPlugin() {
    console.log('Starting Image Editor plugin...');

    // Clear any existing content
    document.body.innerHTML = '';

    // Create and initialize the editor
    window.imageEditor = new ImageEditor();
    window.imageEditor.init();

    console.log('Image Editor plugin loaded successfully');
    return undefined;
}
