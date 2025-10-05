/**
 * @name Test Simple
 * @description Simple test plugin to verify JS execution
 * @author Test
 * @version 1.0
 * @entryFunction runPlugin
 * @mode chat
 */

function runPlugin(prompt) {
    console.log("runPlugin called with prompt: " + prompt);

    var result = {
        content: "<h1>Test Simple Plugin</h1><p>You said: " + prompt + "</p>",
        type: "html",
        replace: true
    };

    console.log("Returning result: " + JSON.stringify(result));

    return result;
}
