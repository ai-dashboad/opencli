import * as vscode from 'vscode';
import { OpenCliClient } from './client';
import { ChatViewProvider } from './chatView';

export function activate(context: vscode.ExtensionContext) {
    console.log('OpenCLI extension is now active');

    // Initialize OpenCLI client
    const client = new OpenCliClient();

    // Register chat view provider
    const chatProvider = new ChatViewProvider(context.extensionUri, client);
    context.subscriptions.push(
        vscode.window.registerWebviewViewProvider('opencli.chatView', chatProvider)
    );

    // Register commands
    context.subscriptions.push(
        vscode.commands.registerCommand('opencli.chat', async () => {
            await vscode.commands.executeCommand('opencli.chatView.focus');
        })
    );

    context.subscriptions.push(
        vscode.commands.registerCommand('opencli.flutterLaunch', async () => {
            const workspaceFolder = vscode.workspace.workspaceFolders?.[0];
            if (!workspaceFolder) {
                vscode.window.showErrorMessage('No workspace folder open');
                return;
            }

            try {
                const response = await client.execute('flutter.launch', [
                    `--project=${workspaceFolder.uri.fsPath}`
                ]);

                vscode.window.showInformationMessage(response.result);
            } catch (error) {
                vscode.window.showErrorMessage(`Failed to launch Flutter app: ${error}`);
            }
        })
    );

    context.subscriptions.push(
        vscode.commands.registerCommand('opencli.flutterHotReload', async () => {
            try {
                const response = await client.execute('flutter.hot_reload', []);
                vscode.window.showInformationMessage(response.result);
            } catch (error) {
                vscode.window.showErrorMessage(`Hot reload failed: ${error}`);
            }
        })
    );

    context.subscriptions.push(
        vscode.commands.registerCommand('opencli.flutterScreenshot', async () => {
            try {
                const response = await client.execute('flutter.screenshot', []);
                vscode.window.showInformationMessage(response.result);
            } catch (error) {
                vscode.window.showErrorMessage(`Screenshot failed: ${error}`);
            }
        })
    );

    // Auto-start daemon if configured
    const config = vscode.workspace.getConfiguration('opencli');
    if (config.get('autoStart')) {
        client.ensureDaemonRunning();
    }
}

export function deactivate() {
    console.log('OpenCLI extension is now deactivated');
}
