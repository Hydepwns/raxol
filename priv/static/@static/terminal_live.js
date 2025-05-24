export const TerminalScroll = {
  mounted() {
    this.cursorVisible = false;
    this.handleMouseMove = (e) => {
      // Calculate cursor position relative to the terminal div
      const rect = this.el.getBoundingClientRect();
      const x = Math.floor(e.clientX - rect.left);
      const y = Math.floor(e.clientY - rect.top);
      this.pushEvent("cursor_move", { x, y, visible: true });
      this.cursorVisible = true;
    };
    this.handleFocus = () => {
      this.cursorVisible = true;
      // Optionally, send current position if you want
      // this.pushEvent("cursor_move", { x: 0, y: 0, visible: true });
    };
    this.handleBlur = () => {
      this.cursorVisible = false;
      this.pushEvent("cursor_move", { x: 0, y: 0, visible: false });
    };
    this.el.addEventListener("mousemove", this.handleMouseMove);
    this.el.addEventListener("focus", this.handleFocus);
    this.el.addEventListener("blur", this.handleBlur);
  },
  destroyed() {
    this.el.removeEventListener("mousemove", this.handleMouseMove);
    this.el.removeEventListener("focus", this.handleFocus);
    this.el.removeEventListener("blur", this.handleBlur);
  },
};
