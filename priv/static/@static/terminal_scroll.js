import { Socket } from "phoenix";

let TerminalChannelHook = {
  mounted() {
    let sessionId = this.el.dataset.sessionId;
    // You may need to adjust userToken or remove if not used
    let socket = new Socket("/socket", {
      params: { userToken: window.userToken || "" },
    });
    socket.connect();

    this.channel = socket.channel("terminal:" + sessionId, {});
    const joinChannel = () => {
      this.channel
        .join()
        .receive("ok", (resp) => {
          console.log("Joined terminal channel", resp);
          this.setStatus("connected");
        })
        .receive("error", (resp) => {
          console.log("Unable to join", resp);
          this.setStatus("disconnected");
        });
    };
    joinChannel();

    // Listen for output events from the channel
    this.channel.on("output", (payload) => {
      this.el.innerHTML = payload.html;
      // Optionally update scrollback badge, etc.
      let badge = document.querySelector(".scrollback-badge");
      if (badge && payload.scrollback_size !== undefined) {
        badge.textContent = `${payload.scrollback_size} lines in scrollback`;
      }
    });

    // Scroll events via channel
    this.el.addEventListener("wheel", (e) => {
      let offset = e.deltaY < 0 ? -3 : 3;
      this.channel.push("scroll", { offset: offset });
      e.preventDefault();
    });
    this.el.addEventListener("keydown", (e) => {
      if (e.key === "PageUp") this.channel.push("scroll", { offset: -20 });
      if (e.key === "PageDown") this.channel.push("scroll", { offset: 20 });
    });

    // Channel disconnect/reconnect handling
    this.channel.onClose(() => {
      this.setStatus("reconnecting");
      setTimeout(() => {
        joinChannel();
      }, 2000);
    });
    this.channel.onError(() => {
      this.setStatus("reconnecting");
    });
  },
  setStatus(status) {
    let statusEl = document.querySelector(".terminal-status");
    if (statusEl) {
      if (status === "connected") {
        statusEl.innerHTML = '<span class="status-connected">Connected</span>';
      } else if (status === "reconnecting") {
        statusEl.innerHTML =
          '<span class="status-disconnected">Reconnecting...</span>';
      } else {
        statusEl.innerHTML =
          '<span class="status-disconnected">Disconnected</span>';
      }
    }
  },
};

window.Hooks = window.Hooks || {};
window.Hooks.TerminalChannelHook = TerminalChannelHook;

window.Hooks.ScrollbackLimit = {
  mounted() {
    this.el.addEventListener("change", (e) => {
      let limit = parseInt(e.target.value, 10);
      // Use pushEvent for LiveView or channel.push for channel
      if (this.pushEvent) {
        this.pushEvent("set_scrollback_limit", { limit: limit });
      } else if (
        window.Hooks.TerminalChannelHook &&
        window.Hooks.TerminalChannelHook.channel
      ) {
        window.Hooks.TerminalChannelHook.channel.push("set_scrollback_limit", {
          limit: limit,
        });
      }
    });
  },
};
