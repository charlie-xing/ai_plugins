/**
 * @name Test Simple HTML
 * @description Test if HTML rendering works
 * @author Test
 * @version 1.0
 * @entryFunction runPlugin
 * @mode Chat
 */

function runPlugin(userPrompt) {
    log('Test Simple HTML: runPlugin called with prompt: ' + userPrompt);

    const html = `
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, sans-serif;
            padding: 20px;
            background: white;
            color: black;
        }
        h1 { color: blue; }
        p { color: green; }
    </style>
</head>
<body>
    <h1>Test HTML Rendering</h1>
    <p>Your prompt was: <strong>${userPrompt}</strong></p>
    <p>If you can see this, HTML rendering is working!</p>
    <ul>
        <li>Item 1</li>
        <li>Item 2</li>
        <li>Item 3</li>
    </ul>
</body>
</html>
    `;

    log('Test Simple HTML: Returning HTML with length: ' + html.length);

    return {
        content: html,
        type: 'html',
        replace: true
    };
}
