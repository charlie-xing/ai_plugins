/**
 * @name Hello World
 * @description A simple plugin that greets the user.
 * @author Gemini
 * @version 1.0
 * @entryFunction runPlugin
 * @mode Role
 */

function runPlugin(prompt) {
    const result = {
        content: `<h1>Hello!</h1><p>You said: ${prompt}</p>`,
        type: "html",
        replace: true 
    };
    return result;
}
