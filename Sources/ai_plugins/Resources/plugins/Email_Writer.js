/**
 * @name Email Writer
 * @description Compose professional emails
 * @author AI Assistant
 * @version 1.0
 * @entryFunction runPlugin
 * @mode Role
 */

function runPlugin(userPrompt) {
    log("Email Writer plugin running with prompt: " + userPrompt);

    return {
        content: "<div style='padding: 20px; font-family: system-ui;'>" +
                "<h2 style='color: #007AFF;'>Email Writer</h2>" +
                "<p style='color: #666;'><strong>Mode:</strong> Role</p>" +
                "<p style='color: #666;'><strong>Your Input:</strong> " + userPrompt + "</p>" +
                "<div style='margin-top: 20px; padding: 15px; background: #f5f5f5; border-radius: 8px;'>" +
                "<p>This is a demo plugin for <strong>Email Writer</strong>.</p>" +
                "<p>Compose professional emails</p>" +
                "<p style='margin-top: 10px; font-style: italic;'>In a real implementation, this would process your request using AI.</p>" +
                "</div>" +
                "</div>",
        type: "html",
        replace: true
    };
}
