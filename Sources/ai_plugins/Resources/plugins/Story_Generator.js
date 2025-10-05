/**
 * @name Story Generator
 * @description Create creative stories
 * @author AI Assistant
 * @version 1.0
 * @entryFunction runPlugin
 * @mode Chat
 */

function runPlugin(userPrompt) {
    log("Story Generator plugin running with prompt: " + userPrompt);

    return {
        content: "<div style='padding: 20px; font-family: system-ui;'>" +
                "<h2 style='color: #007AFF;'>Story Generator</h2>" +
                "<p style='color: #666;'><strong>Mode:</strong> Chat</p>" +
                "<p style='color: #666;'><strong>Your Input:</strong> " + userPrompt + "</p>" +
                "<div style='margin-top: 20px; padding: 15px; background: #f5f5f5; border-radius: 8px;'>" +
                "<p>This is a demo plugin for <strong>Story Generator</strong>.</p>" +
                "<p>Create creative stories</p>" +
                "<p style='margin-top: 10px; font-style: italic;'>In a real implementation, this would process your request using AI.</p>" +
                "</div>" +
                "</div>",
        type: "html",
        replace: true
    };
}
