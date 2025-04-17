import * as vscode from 'vscode';
import * as cp from 'child_process';
import { EventEmitter } from 'events';

// Define the structure for messages based on ExtensionBackendProtocol.md
interface BackendMessage {
    type: string;
    payload: any;
}

export class BackendManager extends EventEmitter {
    private process: cp.ChildProcess | null = null;
    private outputChannel: vscode.OutputChannel;

    constructor(context: vscode.ExtensionContext) {
        super();
        this.outputChannel = vscode.window.createOutputChannel('Raxol Backend');
        this.logInfo('BackendManager initialized.');

        // Ensure process is killed when the extension deactivates
        context.subscriptions.push({
            dispose: () => {
                this.stop();
            }
        });
    }

    private logInfo(message: string) {
        this.outputChannel.appendLine(`[INFO] ${new Date().toISOString()}: ${message}`);
        console.log(`[Raxol BackendManager INFO] ${message}`);
    }

    private logError(message: string, error?: any) {
        this.outputChannel.appendLine(`[ERROR] ${new Date().toISOString()}: ${message}`);
        if (error) {
            this.outputChannel.appendLine(error.toString());
            console.error(`[Raxol BackendManager ERROR] ${message}`, error);
        } else {
            console.error(`[Raxol BackendManager ERROR] ${message}`);
        }
        // Optionally show error message to user
        // vscode.window.showErrorMessage(`Raxol Backend Error: ${message}`);
    }

    private logDebug(message: string) {
        this.outputChannel.appendLine(`[DEBUG] ${new Date().toISOString()}: ${message}`);
        console.log(`[Raxol BackendManager DEBUG] ${message}`);
    }

    public start(): void {
        if (this.process) {
            this.logInfo('Backend process already running.');
            return;
        }

        this.logInfo('Starting Elixir backend process...');
        this.outputChannel.show(true); // Preserve focus on editor

        // Determine workspace root just before spawning
        const workspaceRoot = vscode.workspace.workspaceFolders?.[0]?.uri.fsPath;
        if (!workspaceRoot) {
            this.logError('Could not determine workspace root. Backend process cannot start.');
            this.emit('status', 'error');
            return;
        }

        const command = 'mix';
        const args = ['run', '--no-halt'];
        // Ensure the CWD is the Elixir project root
        const options: cp.SpawnOptions = {
            cwd: workspaceRoot, // Use locally determined workspaceRoot
            stdio: ['pipe', 'pipe', 'pipe'], // stdin, stdout, stderr
            shell: true // Use shell to find `mix` in PATH potentially modified by tools like asdf
        };

        this.logInfo(`Attempting to spawn backend in CWD: ${workspaceRoot}`); // Log the determined CWD

        try {
            this.process = cp.spawn(command, args, options);

            this.process.on('spawn', () => {
                this.logInfo(`Backend process spawned successfully (PID: ${this.process?.pid}).`);
                this.emit('status', 'connecting');
            });

            // Handle stdout - Expected JSON messages wrapped in markers or plain logs
            let stdoutBuffer = '';
            const JSON_START_MARKER = 'RAXOL-JSON-BEGIN';
            const JSON_END_MARKER = 'RAXOL-JSON-END';

            this.process.stdout?.on('data', (data) => {
                const rawData = data.toString();
                this.logDebug(`Received raw stdout data: ${rawData.trim()}`); // Log raw data before parsing

                stdoutBuffer += rawData;

                // Process marked JSON content
                let startIdx = stdoutBuffer.indexOf(JSON_START_MARKER);
                let endIdx = stdoutBuffer.indexOf(JSON_END_MARKER);

                // Process all complete JSON messages in the buffer
                while (startIdx !== -1 && endIdx !== -1 && startIdx < endIdx) {
                    // Extract JSON between markers
                    const jsonStr = stdoutBuffer.substring(
                        startIdx + JSON_START_MARKER.length,
                        endIdx
                    );

                    // Remove processed content from buffer (including end marker)
                    stdoutBuffer = stdoutBuffer.substring(endIdx + JSON_END_MARKER.length);

                    try {
                        const message: BackendMessage = JSON.parse(jsonStr);
                        this.logInfo(`Received message: ${message.type}, Payload: ${JSON.stringify(message.payload)}`);

                        // Handle log messages differently
                        if (message.type === 'log') {
                            const level = message.payload.level || 'info';
                            const logMessage = message.payload.message || '';
                            this.outputChannel.appendLine(`[BACKEND ${level.toUpperCase()}] ${logMessage}`);
                        } else {
                            // Forward other parsed messages
                            this.emit('message', message);
                        }
                    } catch (e) {
                        this.logError(`Failed to parse JSON from backend stdout: ${jsonStr}`, e);
                    }

                    // Look for next set of markers
                    startIdx = stdoutBuffer.indexOf(JSON_START_MARKER);
                    endIdx = stdoutBuffer.indexOf(JSON_END_MARKER);
                }

                // Process any plain log output before the first JSON marker
                if (startIdx !== -1) {
                    const logContent = stdoutBuffer.substring(0, startIdx);
                    if (logContent.trim()) {
                        // Treat as regular log output
                        this.outputChannel.appendLine(`[BACKEND LOG] ${logContent.trim()}`);
                        // Update buffer to remove processed log content
                        stdoutBuffer = stdoutBuffer.substring(startIdx);
                    }
                } else if (stdoutBuffer.trim()) {
                    // If no JSON marker found but buffer has content, treat it all as log
                    this.outputChannel.appendLine(`[BACKEND LOG] ${stdoutBuffer.trim()}`);
                    stdoutBuffer = '';
                }
            });

            // Handle stderr - Log errors/debug info
            this.process.stderr?.on('data', (data) => {
                const message = data.toString();
                this.logError(`Backend stderr: ${message}`);
                 this.emit('stderr_data', message);
            });

            this.process.on('error', (err) => {
                this.logError('Failed to start backend process.', err);
                this.emit('status', 'error');
                this.process = null;
            });

            this.process.on('exit', (code, signal) => {
                if (signal === 'SIGTERM' || code === 0) {
                    this.logInfo(`Backend process exited gracefully (Code: ${code}, Signal: ${signal}).`);
                    this.emit('status', 'stopped');
                } else {
                    this.logError(`Backend process exited unexpectedly (Code: ${code}, Signal: ${signal}).`);
                    this.emit('status', 'crashed');
                }
                this.process = null;
            });

        } catch (error) {
            this.logError('Exception caught while spawning backend process.', error);
             this.emit('status', 'error');
            this.process = null;
        }
    }

    public stop(): void {
        if (!this.process) {
            this.logInfo('Backend process is not running.');
            return;
        }

        this.logInfo('Stopping backend process...');
        // Attempt graceful shutdown first (if protocol supports it)
        this.sendMessage({ type: 'shutdown', payload: {} });

        // Force kill if it doesn't exit after a timeout (e.g., 2 seconds)
        const killTimeout = setTimeout(() => {
            if (this.process) {
                this.logInfo('Backend process did not exit gracefully, force killing...');
                this.process.kill('SIGKILL');
            }
        }, 2000);

        this.process.on('exit', () => {
            clearTimeout(killTimeout); // Cancel the force kill if it exits
        });

        // For non-graceful shutdown or immediate stop:
        // this.process.kill('SIGTERM'); // or 'SIGKILL' for forceful termination
    }

    public sendMessage(message: BackendMessage): void {
        if (!this.process || !this.process.stdin) {
            this.logError('Cannot send message: Backend process not running or stdin not available.');
            return;
        }

        try {
            const messageString = JSON.stringify(message) + '\n'; // Add newline delimiter
            this.process.stdin.write(messageString);
            this.logInfo(`Sent message: ${message.type}, Payload: ${JSON.stringify(message.payload)}`); // Log payload too
        } catch (error) {
            this.logError('Failed to stringify or send message to backend.', error);
        }
    }
}
