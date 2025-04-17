// This script will run in the context of the webview
(function () {
  // Check if running in VS Code webview context
  if (typeof acquireVsCodeApi === "function") {
    const vscode = acquireVsCodeApi();

    // Get references to DOM elements
    const appElement = document.getElementById("app");
    const statusElement = document.getElementById("status"); // Use ID selector
    const terminalOutputElement = document.getElementById("terminal-output");

    // --- Message Handling ---

    // Handle messages received from the extension
    window.addEventListener("message", (event) => {
      const message = event.data; // The JSON data from the extension
      if (!message || !message.type) return;
      console.log(
        `[Webview] Received message: ${message.type}`,
        message.payload ? JSON.stringify(message.payload) : ""
      );

      switch (message.type) {
        case "initialized":
          if (statusElement)
            statusElement.textContent =
              "Backend Initialized. Waiting for UI...";
          break;

        case "ui_update":
          if (statusElement) statusElement.style.display = "none"; // Hide status once UI updates arrive
          if (terminalOutputElement) {
            if (
              message.payload &&
              message.payload.viewState &&
              Array.isArray(message.payload.viewState.cells)
              // TODO: Check for cursor position later message.payload.viewState.cursor
            ) {
              // Clear previous content
              terminalOutputElement.innerHTML = "";

              const cells = message.payload.viewState.cells;
              const cursor = message.payload.viewState.cursor || { x: 0, y: 0 }; // Default cursor if not provided

              // Create grid using divs
              cells.forEach((row, y) => {
                if (!Array.isArray(row)) {
                  console.warn("Invalid row data at index:", y);
                  return; // Skip invalid row
                }
                const rowElement = document.createElement("div");
                rowElement.className = "terminal-row";

                row.forEach((cell, x) => {
                  const cellElement = document.createElement("span"); // Use span for inline behavior within the row flex container
                  cellElement.className = "terminal-cell";

                  // Set character content (handle null/undefined cell or char)
                  cellElement.textContent = cell?.char ?? " ";

                  // --- Apply Styling (Basic Example) ---
                  // TODO: Expand this based on actual cell attributes from backend
                  let fgColorClass = "term-fg-default";
                  let bgColorClass = "term-bg-default";
                  // Example: if (cell?.fgColor) fgColorClass = `term-fg-${cell.fgColor}`;
                  // Example: if (cell?.bgColor) bgColorClass = `term-bg-${cell.bgColor}`;

                  cellElement.classList.add(fgColorClass, bgColorClass);

                  // Apply text attributes (bold, underline etc.) if present
                  // Example: if (cell?.attributes?.bold) cellElement.style.fontWeight = 'bold';

                  // --- Handle Cursor ---
                  if (cursor && x === cursor.x && y === cursor.y) {
                    cellElement.classList.add("cursor");
                    // Ensure cursor character is visible if it's a space
                    if (cellElement.textContent === " ") {
                      cellElement.innerHTML = "&nbsp;"; // Use non-breaking space for visibility
                    }
                  }

                  rowElement.appendChild(cellElement);
                });
                terminalOutputElement.appendChild(rowElement);
              });
            } else {
              // Keep old rendering as fallback for now, or show specific error
              terminalOutputElement.textContent =
                "Received ui_update with missing or invalid cells data.";
              console.warn(
                "Received ui_update with unexpected payload structure:",
                message.payload
              );
            }
          }
          break;

        case "log_message":
          if (message.payload) {
            console.log(
              `[BACKEND LOG ${message.payload.level || ""}]: ${
                message.payload.message || ""
              }`
            );
          }
          break;

        case "error":
          if (statusElement && message.payload) {
            statusElement.textContent = `Backend Error: ${
              message.payload.message || "Unknown error"
            }`;
            statusElement.className = "status error"; // Add error class
            statusElement.style.display = "block";
          }
          if (message.payload) {
            console.error("[BACKEND ERROR]", message.payload);
          }
          break;

        case "status_update":
          if (statusElement && message.payload) {
            statusElement.textContent = message.payload.text || "";
            statusElement.className = message.payload.isError
              ? "status error"
              : "status";
            statusElement.style.display = "block";
          }
          break;

        default:
          console.warn(
            "Webview received unhandled message type:",
            message.type
          );
      }
    });

    // --- Input Handling ---

    // Listen for keyboard events on the whole window
    window.addEventListener(
      "keydown",
      (event) => {
        // Build modifiers list
        const modifiers = [];
        if (event.ctrlKey) modifiers.push("ctrl");
        if (event.altKey) modifiers.push("alt");
        if (event.shiftKey) modifiers.push("shift");
        if (event.metaKey) modifiers.push("meta"); // Command key on Mac

        // Handle key mapping from browser keys to backend format
        let key = event.key;

        // More comprehensive special key mapping
        switch (key) {
          // Arrow keys
          case "ArrowUp":
            key = "up";
            break;
          case "ArrowDown":
            key = "down";
            break;
          case "ArrowLeft":
            key = "left";
            break;
          case "ArrowRight":
            key = "right";
            break;

          // Control keys
          case "Enter":
            key = "Enter";
            break;
          case "Tab":
            key = "Tab";
            break;
          case "Escape":
            key = "Escape";
            break;
          case " ":
            key = " ";
            break; // Space
          case "Backspace":
            key = "Backspace";
            break;
          case "Delete":
            key = "Delete";
            break;
          case "Home":
            key = "Home";
            break;
          case "End":
            key = "End";
            break;
          case "PageUp":
            key = "PageUp";
            break;
          case "PageDown":
            key = "PageDown";
            break;

          // Function keys
          case "F1":
          case "F2":
          case "F3":
          case "F4":
          case "F5":
          case "F6":
          case "F7":
          case "F8":
          case "F9":
          case "F10":
          case "F11":
          case "F12":
            // Keep function keys as-is
            break;

          // Default case - use key as-is if it's a single character
          default:
            // For single character keys, we leave them as-is
            break;
        }

        // Prevent default browser actions for terminal control keys
        if (
          (event.ctrlKey &&
            ["c", "x", "v", "a", "z"].includes(key.toLowerCase())) || // Ctrl+C, Ctrl+X, etc.
          [
            "Tab",
            "ArrowUp",
            "ArrowDown",
            "ArrowLeft",
            "ArrowRight",
            "F1",
            "F2",
            "F3",
            "F4",
            "F5",
            "F6",
            "F7",
            "F8",
            "F9",
            "F10",
            "F11",
            "F12",
          ].includes(key)
        ) {
          event.preventDefault();
        }

        // Format message according to protocol
        const message = {
          command: "userInput", // This matches RaxolPanelManager handleWebviewMessage
          payload: {
            inputType: "key",
            key: key,
            modifiers: modifiers,
          },
        };

        console.log(
          `[Webview] Sending key input: ${key}${
            modifiers.length ? " with modifiers: " + modifiers.join("+") : ""
          }`
        );
        vscode.postMessage(message);
      },
      true
    ); // Use capture phase to intercept keys earlier

    // --- Resize Handling ---

    let resizeTimeout;
    window.addEventListener("resize", () => {
      // Debounce resize event to avoid excessive calculations/messages
      clearTimeout(resizeTimeout);
      resizeTimeout = setTimeout(() => {
        calculateAndSendResize();
      }, 150); // Adjust debounce delay as needed (e.g., 150ms)
    });

    function calculateAndSendResize() {
      if (!terminalOutputElement) return;

      const styles = window.getComputedStyle(terminalOutputElement);
      const font = styles.fontFamily;
      const fontSize = parseFloat(styles.fontSize); // e.g., 14px -> 14
      const lineHeight = parseFloat(styles.lineHeight); // Use line height for row height

      // --- Character Width Estimation ---
      // This is a rough estimate. A more accurate method would involve
      // rendering a character (e.g., 'W' or 'M') to a hidden element
      // and measuring its actual width.
      // Common monospace fonts have a width ~0.6 * fontSize.
      const estimatedCharWidth = fontSize * 0.6;

      if (
        isNaN(estimatedCharWidth) ||
        estimatedCharWidth <= 0 ||
        isNaN(lineHeight) ||
        lineHeight <= 0
      ) {
        console.error("Could not determine character dimensions for resize.");
        // Send default/previous dimensions?
        return;
      }

      const containerWidth =
        terminalOutputElement.clientWidth -
        (parseFloat(styles.paddingLeft) + parseFloat(styles.paddingRight));
      const containerHeight =
        terminalOutputElement.clientHeight -
        (parseFloat(styles.paddingTop) + parseFloat(styles.paddingBottom));

      const cols = Math.max(1, Math.floor(containerWidth / estimatedCharWidth));
      const rows = Math.max(1, Math.floor(containerHeight / lineHeight));

      const resizePayload = { cols, rows };
      const resizeMessage = {
        command: "resize",
        payload: resizePayload,
      };

      console.log(
        `[Webview] Sending message: ${resizeMessage.command}`,
        JSON.stringify(resizeMessage.payload)
      );
      vscode.postMessage({
        command: resizeMessage.command,
        payload: resizeMessage.payload,
      });
    }

    // --- Initial State ---

    // Optional: Send a message to the extension when the webview is ready
    // vscode.postMessage({ command: 'webviewReady' });
    console.log("Raxol webview script loaded.");

    // Perform initial size calculation after a short delay
    // to allow layout to settle
    setTimeout(calculateAndSendResize, 100);
  } else {
    console.error("VS Code API not available in this context.");
    // Provide fallback behavior or error display if not in VS Code
    const statusElement = document.getElementById("status");
    if (statusElement) {
      statusElement.textContent = "Error: Cannot connect to VS Code extension.";
      statusElement.className = "status error";
    }
  }
})();
