const Terminal = {
  mounted() {
    this.sessionId = this.el.dataset.sessionId;
    this.socket = null;
    this.connected = false;
    this.buffer = "";
    this.setupEventListeners();
    this.connect();
  },

  destroyed() {
    this.disconnect();
  },

  setupEventListeners() {
    // Keyboard events
    this.el.addEventListener("keydown", (e) => this.handleKeyDown(e));
    this.el.addEventListener("keypress", (e) => this.handleKeyPress(e));
    
    // Mouse events
    this.el.addEventListener("click", (e) => this.handleClick(e));
    this.el.addEventListener("wheel", (e) => this.handleWheel(e));
    
    // Resize events
    window.addEventListener("resize", () => this.handleResize());
    
    // Theme events
    this.handleEvent("terminal_theme", ({ theme }) => this.setTheme(theme));
  },

  connect() {
    this.socket = new WebSocket(`ws://${window.location.host}/socket`);
    
    this.socket.onopen = () => {
      this.connected = true;
      this.pushEvent("connect", {});
      this.joinChannel();
    };
    
    this.socket.onclose = () => {
      this.connected = false;
      this.pushEvent("disconnect", {});
    };
    
    this.socket.onmessage = (event) => {
      const data = JSON.parse(event.data);
      this.handleMessage(data);
    };
  },

  disconnect() {
    if (this.socket) {
      this.socket.close();
    }
  },

  joinChannel() {
    this.socket.send(JSON.stringify({
      topic: `terminal:${this.sessionId}`,
      event: "phx_join",
      payload: {},
      ref: "1"
    }));
  },

  handleMessage(data) {
    switch (data.event) {
      case "output":
        this.pushEvent("terminal_output", data.payload);
        break;
      case "error":
        console.error("Terminal error:", data.payload);
        break;
    }
  },

  handleKeyDown(e) {
    if (!this.connected) return;
    
    const key = e.key;
    let data = "";
    
    switch (key) {
      case "Enter":
        data = "\r";
        break;
      case "Backspace":
        data = "\b";
        break;
      case "Tab":
        data = "\t";
        e.preventDefault();
        break;
      case "ArrowUp":
      case "ArrowDown":
      case "ArrowLeft":
      case "ArrowRight":
      case "Home":
      case "End":
      case "PageUp":
      case "PageDown":
      case "Delete":
        data = this.getEscapeSequence(key);
        e.preventDefault();
        break;
      default:
        if (key.length === 1) {
          data = key;
        }
    }
    
    if (data) {
      this.sendInput(data);
    }
  },

  handleKeyPress(e) {
    if (!this.connected) return;
    
    const char = e.key;
    if (char.length === 1) {
      this.sendInput(char);
    }
  },

  handleClick(e) {
    if (!this.connected) return;
    
    const rect = this.el.getBoundingClientRect();
    const x = Math.floor((e.clientX - rect.left) / this.getCharWidth());
    const y = Math.floor((e.clientY - rect.top) / this.getCharHeight());
    
    this.sendInput(this.getMouseEvent("click", x, y));
  },

  handleWheel(e) {
    if (!this.connected) return;
    
    const delta = Math.sign(e.deltaY);
    this.pushEvent("scroll", { offset: delta });
  },

  handleResize() {
    if (!this.connected) return;
    
    const width = Math.floor(this.el.clientWidth / this.getCharWidth());
    const height = Math.floor(this.el.clientHeight / this.getCharHeight());
    
    this.pushEvent("resize", { width, height });
  },

  setTheme(theme) {
    Object.entries(theme).forEach(([key, value]) => {
      this.el.style.setProperty(`--terminal-${key}`, value);
    });
  },

  sendInput(data) {
    this.socket.send(JSON.stringify({
      topic: `terminal:${this.sessionId}`,
      event: "input",
      payload: { data },
      ref: "2"
    }));
  },

  getEscapeSequence(key) {
    const sequences = {
      ArrowUp: "\x1b[A",
      ArrowDown: "\x1b[B",
      ArrowRight: "\x1b[C",
      ArrowLeft: "\x1b[D",
      Home: "\x1b[H",
      End: "\x1b[F",
      PageUp: "\x1b[5~",
      PageDown: "\x1b[6~",
      Delete: "\x1b[3~"
    };
    return sequences[key] || "";
  },

  getMouseEvent(type, x, y) {
    return `\x1b[${y};${x}${type === "click" ? "M" : "m"}`;
  },

  getCharWidth() {
    return 8; // Approximate width of a monospace character
  },

  getCharHeight() {
    return 16; // Approximate height of a monospace character
  }
};

export default Terminal; 