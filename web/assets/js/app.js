// Raxol Playground JavaScript
import "phoenix_html"
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"

// Phoenix LiveView hooks
let Hooks = {}

// Copy to Clipboard Hook
Hooks.CopyToClipboard = {
  mounted() {
    this.el.addEventListener('click', () => {
      const text = this.el.dataset.copy
      if (!text) return

      navigator.clipboard.writeText(text).then(() => {
        const original = this.el.innerHTML
        this.el.innerHTML = '<span style="color: #58a1c6;">copied</span>'
        setTimeout(() => { this.el.innerHTML = original }, 1500)
      }).catch(() => {
        // Fallback for older browsers
        const textarea = document.createElement('textarea')
        textarea.value = text
        textarea.style.position = 'fixed'
        textarea.style.opacity = '0'
        document.body.appendChild(textarea)
        textarea.select()
        document.execCommand('copy')
        document.body.removeChild(textarea)

        const original = this.el.innerHTML
        this.el.innerHTML = '<span style="color: #58a1c6;">copied</span>'
        setTimeout(() => { this.el.innerHTML = original }, 1500)
      })
    })
  }
}

// Code Editor Hook
Hooks.CodeEditor = {
  mounted() {
    this.handleKeydown = (e) => {
      // Cmd+Enter or Ctrl+Enter to run
      if ((e.metaKey || e.ctrlKey) && e.key === 'Enter') {
        e.preventDefault()
        this.pushEvent("run_component", {})
      }

      // Tab key handling for indentation
      if (e.key === 'Tab') {
        e.preventDefault()
        const start = this.el.selectionStart
        const end = this.el.selectionEnd
        const value = this.el.value
        this.el.value = value.substring(0, start) + '  ' + value.substring(end)
        this.el.selectionStart = this.el.selectionEnd = start + 2

        // Trigger change event
        const event = new Event('input', { bubbles: true })
        this.el.dispatchEvent(event)
      }
    }

    this.el.addEventListener('keydown', this.handleKeydown)
  },

  updated() {},

  destroyed() {
    if (this.handleKeydown) {
      this.el.removeEventListener('keydown', this.handleKeydown)
    }
  }
}

// Terminal Output Hook
Hooks.TerminalOutput = {
  mounted() { this.scrollToBottom() },
  updated() { this.scrollToBottom() },
  scrollToBottom() { this.el.scrollTop = this.el.scrollHeight }
}

// Flash Hook - auto-dismiss flash messages
Hooks.Flash = {
  mounted() {
    this.timer = setTimeout(() => {
      this.pushEvent("lv:clear-flash", {})
    }, 5000)
  },
  destroyed() {
    if (this.timer) clearTimeout(this.timer)
  }
}

// Raxol Terminal Hook - renders demo output via direct innerHTML injection.
// Raw HTML from TerminalBridge changes structure every frame. LiveView's
// morphdom differ can't patch it reliably, so we bypass it: the server
// pushes terminal_html via push_event, and this hook sets innerHTML directly.
Hooks.RaxolTerminal = {
  mounted() {
    this.el.addEventListener('click', () => this.el.focus())

    this.el.addEventListener('focus', () => {
      this.el.style.outline = '2px solid rgba(88, 161, 198, 0.4)'
      this.el.style.outlineOffset = '-2px'
    })
    this.el.addEventListener('blur', () => {
      this.el.style.outline = 'none'
    })

    // Receive terminal HTML directly, bypassing LiveView differ
    this.handleEvent("terminal_html", ({html}) => {
      this.el.innerHTML = html
      this.scrollToBottom()
    })

    this.el.focus()
    this.scrollToBottom()
  },

  updated() {
    this.scrollToBottom()
  },

  scrollToBottom() {
    this.el.scrollTop = this.el.scrollHeight
  }
}

// Initialize LiveSocket
let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
let liveSocket = new LiveSocket("/live", Socket, {
  params: {_csrf_token: csrfToken},
  hooks: Hooks
})

// Global keyboard shortcuts
document.addEventListener('DOMContentLoaded', () => {
  document.addEventListener('keydown', (e) => {
    // Cmd+K or Ctrl+K for search
    if ((e.metaKey || e.ctrlKey) && e.key === 'k') {
      e.preventDefault()
      const searchInput = document.querySelector('input[placeholder="Search..."]') ||
        document.querySelector('input[placeholder="Search components..."]')
      if (searchInput) searchInput.focus()
    }
  })
})

// Connect if there are any LiveViews on the page
liveSocket.connect()

// Expose liveSocket on window for web console debug logs
window.liveSocket = liveSocket
