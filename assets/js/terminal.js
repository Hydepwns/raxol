const TerminalInput = {
  mounted() {
    this.el.addEventListener('keydown', (e) => {
      // Prevent default behavior for special keys
      if (['ArrowUp', 'ArrowDown', 'ArrowLeft', 'ArrowRight', 'Enter', 
           'Backspace', 'Delete', 'Home', 'End', 'PageUp', 'PageDown',
           'F1', 'F2', 'F3', 'F4'].includes(e.key)) {
        e.preventDefault();
      }
    });

    this.el.addEventListener('focus', () => {
      this.el.value = '';
    });

    this.el.addEventListener('blur', () => {
      this.el.value = '';
    });
  }
};

const TerminalOutput = {
  mounted() {
    this.scrollToBottom();
  },

  updated() {
    this.scrollToBottom();
  },

  scrollToBottom() {
    this.el.scrollTop = this.el.scrollHeight;
  }
};

export { TerminalInput, TerminalOutput }; 