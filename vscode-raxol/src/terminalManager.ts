import * as vscode from 'vscode';
import { spawn, ChildProcess } from 'child_process';
import * as treeKill from 'tree-kill';

export class RaxolTerminalManager {
    private terminals: Map<string, vscode.Terminal> = new Map();
    private processes: Map<string, ChildProcess> = new Map();

    constructor() {
        // Clean up terminals when they are disposed
        vscode.window.onDidCloseTerminal(terminal => {
            for (const [key, term] of this.terminals) {
                if (term === terminal) {
                    this.terminals.delete(key);
                    const process = this.processes.get(key);
                    if (process) {
                        treeKill(process.pid!);
                        this.processes.delete(key);
                    }
                    break;
                }
            }
        });
    }

    public startPlayground(): void {
        this.createOrShowTerminal('playground', 'Raxol Playground', 'mix raxol.playground');
    }

    public startTutorial(): void {
        this.createOrShowTerminal('tutorial', 'Raxol Tutorial', 'mix raxol.tutorial');
    }

    public runTests(): void {
        this.createOrShowTerminal('tests', 'Raxol Tests', 'mix test');
    }

    public openREPL(): void {
        this.createOrShowTerminal('repl', 'Raxol REPL', 'iex -S mix');
    }

    public async formatFile(filePath: string): Promise<void> {
        const workspaceFolder = vscode.workspace.workspaceFolders?.[0];
        if (!workspaceFolder) {
            vscode.window.showErrorMessage('No workspace folder found');
            return;
        }

        return new Promise((resolve, reject) => {
            const process = spawn('mix', ['format', filePath], {
                cwd: workspaceFolder.uri.fsPath,
                stdio: 'pipe'
            });

            let stderr = '';
            process.stderr?.on('data', (data) => {
                stderr += data.toString();
            });

            process.on('close', (code) => {
                if (code === 0) {
                    vscode.window.showInformationMessage('File formatted successfully');
                    resolve();
                } else {
                    vscode.window.showErrorMessage(`Format failed: ${stderr}`);
                    reject(new Error(stderr));
                }
            });

            process.on('error', (error) => {
                vscode.window.showErrorMessage(`Format error: ${error.message}`);
                reject(error);
            });
        });
    }

    public runCommand(command: string, name: string): vscode.Terminal {
        const terminal = this.createOrShowTerminal(name.toLowerCase(), name, command);
        return terminal;
    }

    public runMixTask(task: string, args: string[] = []): void {
        const command = `mix ${task} ${args.join(' ')}`;
        const terminalName = `Mix: ${task}`;
        this.createOrShowTerminal(task, terminalName, command);
    }

    private createOrShowTerminal(key: string, name: string, command?: string): vscode.Terminal {
        let terminal = this.terminals.get(key);
        
        if (!terminal || terminal.exitStatus !== undefined) {
            // Create new terminal
            const workspaceFolder = vscode.workspace.workspaceFolders?.[0];
            if (!workspaceFolder) {
                throw new Error('No workspace folder found');
            }

            terminal = vscode.window.createTerminal({
                name: name,
                cwd: workspaceFolder.uri.fsPath,
                env: {
                    ...process.env,
                    MIX_ENV: 'dev'
                }
            });

            this.terminals.set(key, terminal);
        }

        terminal.show();

        if (command) {
            terminal.sendText(command);
        }

        return terminal;
    }

    public dispose(): void {
        // Clean up all terminals and processes
        for (const terminal of this.terminals.values()) {
            terminal.dispose();
        }
        this.terminals.clear();

        for (const process of this.processes.values()) {
            if (process.pid) {
                treeKill(process.pid);
            }
        }
        this.processes.clear();
    }

    public async checkMixProject(): Promise<boolean> {
        const workspaceFolder = vscode.workspace.workspaceFolders?.[0];
        if (!workspaceFolder) {
            return false;
        }

        try {
            const mixFile = vscode.Uri.joinPath(workspaceFolder.uri, 'mix.exs');
            await vscode.workspace.fs.stat(mixFile);
            return true;
        } catch {
            return false;
        }
    }

    public async checkRaxolDependency(): Promise<boolean> {
        const workspaceFolder = vscode.workspace.workspaceFolders?.[0];
        if (!workspaceFolder) {
            return false;
        }

        try {
            const mixFile = vscode.Uri.joinPath(workspaceFolder.uri, 'mix.exs');
            const content = await vscode.workspace.fs.readFile(mixFile);
            const mixContent = Buffer.from(content).toString('utf8');
            return mixContent.includes(':raxol');
        } catch {
            return false;
        }
    }

    public async installRaxolDependency(): Promise<void> {
        const workspaceFolder = vscode.workspace.workspaceFolders?.[0];
        if (!workspaceFolder) {
            throw new Error('No workspace folder found');
        }

        return new Promise((resolve, reject) => {
            const process = spawn('mix', ['deps.get'], {
                cwd: workspaceFolder.uri.fsPath,
                stdio: 'inherit'
            });

            process.on('close', (code) => {
                if (code === 0) {
                    resolve();
                } else {
                    reject(new Error(`Dependencies installation failed with code ${code}`));
                }
            });

            process.on('error', (error) => {
                reject(error);
            });
        });
    }

    public async compileMixProject(): Promise<void> {
        const workspaceFolder = vscode.workspace.workspaceFolders?.[0];
        if (!workspaceFolder) {
            throw new Error('No workspace folder found');
        }

        return new Promise((resolve, reject) => {
            const process = spawn('mix', ['compile'], {
                cwd: workspaceFolder.uri.fsPath,
                stdio: 'pipe'
            });

            let stdout = '';
            let stderr = '';

            process.stdout?.on('data', (data) => {
                stdout += data.toString();
            });

            process.stderr?.on('data', (data) => {
                stderr += data.toString();
            });

            process.on('close', (code) => {
                if (code === 0) {
                    vscode.window.showInformationMessage('Mix project compiled successfully');
                    resolve();
                } else {
                    vscode.window.showErrorMessage(`Compilation failed: ${stderr}`);
                    reject(new Error(stderr));
                }
            });

            process.on('error', (error) => {
                reject(error);
            });
        });
    }
}