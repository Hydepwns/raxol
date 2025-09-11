import * as vscode from "vscode";
import * as cp from "child_process";
import { EventEmitter } from "events";

// Define the structure for messages based on ExtensionBackendProtocol.md
interface BackendMessage {
  type: string;
  payload: any;
}

// Output classification types
enum OutputType {
  JSON_MESSAGE = "json_message",
  LOG_OUTPUT = "log_output",
  MAKE_OUTPUT = "make_output",
  ERROR_OUTPUT = "error_output",
  UNKNOWN = "unknown",
}

// Output classification result
interface OutputClassification {
  type: OutputType;
  content: string;
  shouldProcess: boolean;
}

export class BackendManager extends EventEmitter {
  private process: cp.ChildProcess | null = null;
  private outputChannel: vscode.OutputChannel;
  private stdoutBuffer = "";
  private readonly JSON_START_MARKER = "RAXOL-JSON-BEGIN";
  private readonly JSON_END_MARKER = "RAXOL-JSON-END";
  private readonly MAX_BUFFER_SIZE = 1024 * 1024; // 1MB max buffer size

  constructor(context: vscode.ExtensionContext) {
    super();
    this.outputChannel = vscode.window.createOutputChannel("Raxol Backend");
    this.logInfo("BackendManager initialized.");

    // Ensure process is killed when the extension deactivates
    context.subscriptions.push({
      dispose: () => {
        this.stop();
      },
    });
  }

  private logInfo(message: string) {
    this.outputChannel.appendLine(
      `[INFO] ${new Date().toISOString()}: ${message}`
    );
    console.log(`[Raxol BackendManager INFO] ${message}`);
  }

  private logError(message: string, error?: any) {
    this.outputChannel.appendLine(
      `[ERROR] ${new Date().toISOString()}: ${message}`
    );
    if (error) {
      this.outputChannel.appendLine(error.toString());
      console.error(`[Raxol BackendManager ERROR] ${message}`, error);
    } else {
      console.error(`[Raxol BackendManager ERROR] ${message}`);
    }
  }

  private logDebug(message: string) {
    this.outputChannel.appendLine(
      `[DEBUG] ${new Date().toISOString()}: ${message}`
    );
    console.log(`[Raxol BackendManager DEBUG] ${message}`);
  }

  /**
   * Classifies output content to determine how it should be handled
   */
  private classifyOutput(content: string): OutputClassification {
    const trimmedContent = content.trim();

    // Check for make output patterns
    if (this.isMakeOutput(trimmedContent)) {
      return {
        type: OutputType.MAKE_OUTPUT,
        content: trimmedContent,
        shouldProcess: false, // Don't process make output as JSON
      };
    }

    // Check for JSON markers
    if (
      trimmedContent.includes(this.JSON_START_MARKER) &&
      trimmedContent.includes(this.JSON_END_MARKER)
    ) {
      return {
        type: OutputType.JSON_MESSAGE,
        content: trimmedContent,
        shouldProcess: true,
      };
    }

    // Check for error patterns
    if (this.isErrorOutput(trimmedContent)) {
      return {
        type: OutputType.ERROR_OUTPUT,
        content: trimmedContent,
        shouldProcess: false,
      };
    }

    // Default to log output
    return {
      type: OutputType.LOG_OUTPUT,
      content: trimmedContent,
      shouldProcess: false,
    };
  }

  /**
   * Detects make output patterns that should be filtered or handled specially
   */
  private isMakeOutput(content: string): boolean {
    const makePatterns = [
      /^make: Nothing to be done for ['"]all['"]\.\s*$/,
      /^make\[1\]: Entering directory/,
      /^make\[1\]: Leaving directory/,
      /^make: .* is up to date\./,
      /^make: .* has no work to do\./,
      /^make: .* is already up to date\./,
    ];

    return makePatterns.some((pattern) => pattern.test(content));
  }

  /**
   * Detects error output patterns
   */
  private isErrorOutput(content: string): boolean {
    const errorPatterns = [
      /^error:/i,
      /^fatal:/i,
      /^exception:/i,
      /^failed:/i,
      /^Error on parsing output/i,
    ];

    return errorPatterns.some((pattern) => pattern.test(content));
  }

  /**
   * Validates if content is valid JSON
   */
  private isValidJson(content: string): boolean {
    try {
      JSON.parse(content);
      return true;
    } catch {
      return false;
    }
  }

  /**
   * Processes JSON content between markers
   */
  private processJsonContent(jsonStr: string): void {
    try {
      // Validate JSON before parsing
      if (!this.isValidJson(jsonStr)) {
        this.logError(`Invalid JSON content: ${jsonStr.substring(0, 100)}...`);
        return;
      }

      const message: BackendMessage = JSON.parse(jsonStr);
      this.logInfo(
        `Received message: ${message.type}, Payload: ${JSON.stringify(
          message.payload
        )}`
      );

      // Handle log messages differently
      if (message.type === "log") {
        const level = message.payload.level || "info";
        const logMessage = message.payload.message || "";
        this.outputChannel.appendLine(
          `[BACKEND ${level.toUpperCase()}] ${logMessage}`
        );
      } else {
        // Forward other parsed messages
        this.emit("message", message);
      }
    } catch (e) {
      this.logError(
        `Failed to parse JSON from backend stdout: ${jsonStr.substring(
          0,
          100
        )}...`,
        e
      );
    }
  }

  /**
   * Processes plain text output
   */
  private processPlainTextOutput(content: string, type: OutputType): void {
    switch (type) {
      case OutputType.MAKE_OUTPUT:
        // Filter out or handle make output specially
        this.logDebug(`[MAKE] ${content}`);
        break;

      case OutputType.ERROR_OUTPUT:
        this.logError(`[BACKEND ERROR] ${content}`);
        break;

      case OutputType.LOG_OUTPUT:
      default:
        this.outputChannel.appendLine(`[BACKEND LOG] ${content}`);
        break;
    }
  }

  /**
   * Manages buffer size to prevent memory issues
   */
  private manageBufferSize(): void {
    if (this.stdoutBuffer.length > this.MAX_BUFFER_SIZE) {
      this.logError(
        `Buffer size exceeded ${this.MAX_BUFFER_SIZE} bytes, truncating...`
      );
      // Keep only the last portion of the buffer
      this.stdoutBuffer = this.stdoutBuffer.substring(
        this.stdoutBuffer.length - this.MAX_BUFFER_SIZE / 2
      );
    }
  }

  /**
   * Enhanced stdout processing with improved error handling
   */
  private processStdout(rawData: string): void {
    this.logDebug(`Received raw stdout data: ${rawData.trim()}`);
    this.emit("stdout_data", rawData);

    this.stdoutBuffer += rawData;
    this.manageBufferSize();

    // Process marked JSON content
    let startIdx = this.stdoutBuffer.indexOf(this.JSON_START_MARKER);
    let endIdx = this.stdoutBuffer.indexOf(this.JSON_END_MARKER);

    // Process all complete JSON messages in the buffer
    while (startIdx !== -1 && endIdx !== -1 && startIdx < endIdx) {
      // Extract JSON between markers
      const jsonStr = this.stdoutBuffer.substring(
        startIdx + this.JSON_START_MARKER.length,
        endIdx
      );

      // Remove processed content from buffer (including end marker)
      this.stdoutBuffer = this.stdoutBuffer.substring(
        endIdx + this.JSON_END_MARKER.length
      );

      // Process the JSON content
      this.processJsonContent(jsonStr);

      // Look for next set of markers
      startIdx = this.stdoutBuffer.indexOf(this.JSON_START_MARKER);
      endIdx = this.stdoutBuffer.indexOf(this.JSON_END_MARKER);
    }

    // Process any plain text output before the first JSON marker
    if (startIdx !== -1) {
      const logContent = this.stdoutBuffer.substring(0, startIdx);
      if (logContent.trim()) {
        const classification = this.classifyOutput(logContent);
        this.processPlainTextOutput(
          classification.content,
          classification.type
        );
        // Update buffer to remove processed log content
        this.stdoutBuffer = this.stdoutBuffer.substring(startIdx);
      }
    } else if (this.stdoutBuffer.trim()) {
      // If no JSON marker found but buffer has content, classify and process it
      const classification = this.classifyOutput(this.stdoutBuffer);
      this.processPlainTextOutput(classification.content, classification.type);
      this.stdoutBuffer = "";
    }
  }

  public start(): void {
    if (this.process) {
      this.logInfo("Backend process already running.");
      return;
    }

    this.logInfo("Starting Elixir backend process...");
    this.outputChannel.show(true); // Preserve focus on editor

    // Determine workspace root just before spawning
    const workspaceRoot = vscode.workspace.workspaceFolders?.[0]?.uri.fsPath;
    if (!workspaceRoot) {
      this.logError(
        "Could not determine workspace root. Backend process cannot start."
      );
      this.emit("status", "error");
      return;
    }

    const command = "mix";
    const args = ["run", "--no-halt"];
    // Ensure the CWD is the Elixir project root
    const options: cp.SpawnOptions = {
      cwd: workspaceRoot, // Use locally determined workspaceRoot
      stdio: ["pipe", "pipe", "pipe"], // stdin, stdout, stderr
      shell: true, // Use shell to find `mix` in PATH potentially modified by tools like asdf
      env: {
        ...process.env,
        RAXOL_MODE: "vscode_ext", // Tell the backend it's running in VS Code extension mode
        RAXOL_ENV: process.env.RAXOL_ENV || "dev",
      },
    };

    this.logInfo(`Attempting to spawn backend in CWD: ${workspaceRoot}`);

    try {
      this.process = cp.spawn(command, args, options);

      this.process.on("spawn", () => {
        this.logInfo(
          `Backend process spawned successfully (PID: ${this.process?.pid}).`
        );
        this.emit("status", "connecting");
      });

      // Handle stdout with improved processing
      this.process.stdout?.on("data", (data) => {
        this.processStdout(data.toString());
      });

      // Handle stderr - Log errors/debug info
      this.process.stderr?.on("data", (data) => {
        const message = data.toString();
        this.logError(`Backend stderr: ${message}`);
        this.emit("stderr_data", message);
      });

      this.process.on("error", (err) => {
        this.logError("Failed to start backend process.", err);
        this.emit("status", "error");
        this.process = null;
      });

      this.process.on("exit", (code, signal) => {
        if (signal === "SIGTERM" || code === 0) {
          this.logInfo(
            `Backend process exited gracefully (Code: ${code}, Signal: ${signal}).`
          );
          this.emit("status", "stopped");
        } else {
          this.logError(
            `Backend process exited unexpectedly (Code: ${code}, Signal: ${signal}).`
          );
          this.emit("status", "crashed");
        }
        this.process = null;
      });
    } catch (error) {
      this.logError("Exception caught while spawning backend process.", error);
      this.emit("status", "error");
      this.process = null;
    }
  }

  public stop(): void {
    if (!this.process) {
      this.logInfo("Backend process is not running.");
      return;
    }

    this.logInfo("Stopping backend process...");
    // Attempt graceful shutdown first (if protocol supports it)
    this.sendMessage({ type: "shutdown", payload: {} });

    // Force kill if it doesn't exit after a timeout (e.g., 2 seconds)
    const killTimeout = setTimeout(() => {
      if (this.process) {
        this.logInfo(
          "Backend process did not exit gracefully, force killing..."
        );
        this.process.kill("SIGKILL");
      }
    }, 2000);

    this.process.on("exit", () => {
      clearTimeout(killTimeout); // Cancel the force kill if it exits
    });
  }

  public sendMessage(message: BackendMessage): void {
    if (!this.process || !this.process.stdin) {
      this.logError(
        "Cannot send message: Backend process not running or stdin not available."
      );
      return;
    }

    try {
      const messageString = JSON.stringify(message) + "\n"; // Add newline delimiter
      this.process.stdin.write(messageString);
      this.logInfo(
        `Sent message: ${message.type}, Payload: ${JSON.stringify(
          message.payload
        )}`
      );
    } catch (error) {
      this.logError("Failed to stringify or send message to backend.", error);
    }
  }
}
