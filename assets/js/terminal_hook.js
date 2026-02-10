/**
 * Phoenix LiveView hook for xterm.js terminal demo.
 * Connects to the demo terminal channel and handles input/output.
 *
 * xterm.js is loaded via script tags in root.html.heex and available as globals:
 * - window.Terminal
 * - window.FitAddon
 */

const TerminalDemo = {
  mounted() {
    this.initTerminal()
  },

  destroyed() {
    if (this.channel) {
      this.channel.leave()
    }
    if (this.terminal) {
      this.terminal.dispose()
    }
    if (this.resizeObserver) {
      this.resizeObserver.disconnect()
    }
  },

  initTerminal() {
    // Get Terminal and FitAddon from global scope (loaded via script tags)
    const Terminal = window.Terminal
    const FitAddon = window.FitAddon

    if (!Terminal || !FitAddon) {
      console.error("xterm.js not loaded")
      return
    }

    // Create terminal instance with Tokyo Night theme
    this.terminal = new Terminal({
      cursorBlink: true,
      cursorStyle: "block",
      fontFamily: '"Fira Code", "JetBrains Mono", "SF Mono", Menlo, Monaco, monospace',
      fontSize: 14,
      lineHeight: 1.2,
      theme: {
        background: "#1a1b26",
        foreground: "#a9b1d6",
        cursor: "#c0caf5",
        cursorAccent: "#1a1b26",
        selectionBackground: "#33467c",
        black: "#32344a",
        red: "#f7768e",
        green: "#9ece6a",
        yellow: "#e0af68",
        blue: "#7aa2f7",
        magenta: "#bb9af7",
        cyan: "#7dcfff",
        white: "#a9b1d6",
        brightBlack: "#444b6a",
        brightRed: "#ff7a93",
        brightGreen: "#b9f27c",
        brightYellow: "#ff9e64",
        brightBlue: "#7da6ff",
        brightMagenta: "#c678dd",
        brightCyan: "#0db9d7",
        brightWhite: "#c0caf5"
      }
    })

    // Add fit addon
    this.fitAddon = new FitAddon.FitAddon()
    this.terminal.loadAddon(this.fitAddon)

    // Open terminal in DOM
    this.terminal.open(this.el)
    this.fitAddon.fit()

    // Handle window resize
    this.resizeObserver = new ResizeObserver(() => {
      this.fitAddon.fit()
    })
    this.resizeObserver.observe(this.el)

    // Connect to Phoenix channel
    this.connectChannel()

    // Handle terminal input
    this.terminal.onData(data => {
      if (this.channel) {
        this.channel.push("input", { data })
      }
    })

    // Focus terminal
    this.terminal.focus()
  },

  connectChannel() {
    const sessionId = this.el.dataset.sessionId
    const socket = window.liveSocket.socket

    this.channel = socket.channel(`demo:terminal:${sessionId}`, {})

    this.channel.on("output", ({ data }) => {
      this.terminal.write(data)
    })

    this.channel.join()
      .receive("ok", () => {
        console.log("Demo terminal connected")
      })
      .receive("error", ({ reason }) => {
        console.error("Failed to join demo terminal:", reason)
        this.terminal.write(`\r\n\x1b[31mConnection error: ${reason}\x1b[0m\r\n`)
        this.terminal.write("Please refresh the page to try again.\r\n")
      })
  }
}

export default TerminalDemo
