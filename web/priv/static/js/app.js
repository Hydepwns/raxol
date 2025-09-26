// Raxol Dev Playground JavaScript
import "phoenix_html"
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import topbar from "../vendor/topbar"

// Import code editor
import { EditorView, basicSetup } from "codemirror"
import { elixir } from "@codemirror/lang-elixir" 
import { oneDark } from "@codemirror/theme-one-dark"

// Phoenix LiveView hooks
let Hooks = {}

// Code Editor Hook
Hooks.CodeEditor = {
  mounted() {
    const editor = new EditorView({
      doc: this.el.value,
      extensions: [
        basicSetup,
        elixir(),
        oneDark,
        EditorView.updateListener.of((update) => {
          if (update.docChanged) {
            this.pushEvent("update_code", { code: update.state.doc.toString() })
          }
        })
      ],
      parent: this.el.parentElement
    })
    
    this.el.style.display = 'none'
    this.editor = editor
  },
  
  updated() {
    if (this.editor && this.el.value !== this.editor.state.doc.toString()) {
      this.editor.dispatch({
        changes: {
          from: 0,
          to: this.editor.state.doc.length,
          insert: this.el.value
        }
      })
    }
  },
  
  destroyed() {
    if (this.editor) {
      this.editor.destroy()
    }
  }
}

// REPL Input Hook
Hooks.ReplInput = {
  mounted() {
    this.el.addEventListener('keydown', (e) => {
      if (e.key === 'Enter' && !e.shiftKey) {
        e.preventDefault()
        this.pushEvent("execute_code", { code: this.el.value })
      } else if (e.key === 'ArrowUp' && e.ctrlKey) {
        e.preventDefault()
        this.pushEvent("navigate_history", { direction: "up" })
      } else if (e.key === 'ArrowDown' && e.ctrlKey) {
        e.preventDefault()
        this.pushEvent("navigate_history", { direction: "down" })
      }
    })
    
    // Auto-resize textarea
    this.el.addEventListener('input', () => {
      this.el.style.height = 'auto'
      this.el.style.height = Math.min(this.el.scrollHeight, 200) + 'px'
    })
  }
}

// Command Palette Hook
Hooks.CommandPalette = {
  mounted() {
    this.shortcuts = {
      'ctrl+k': () => this.pushEvent("toggle_command_palette"),
      'ctrl+shift+p': () => this.pushEvent("toggle_command_palette"),
      'escape': () => this.pushEvent("close_command_palette"),
      '/': (e) => {
        if (e.target.tagName !== 'INPUT' && e.target.tagName !== 'TEXTAREA') {
          e.preventDefault()
          this.pushEvent("focus_search")
        }
      }
    }
    
    document.addEventListener('keydown', (e) => {
      const shortcut = this.getShortcut(e)
      if (this.shortcuts[shortcut]) {
        this.shortcuts[shortcut](e)
      }
    })
  },
  
  getShortcut(e) {
    let keys = []
    if (e.ctrlKey) keys.push('ctrl')
    if (e.shiftKey) keys.push('shift')
    if (e.altKey) keys.push('alt')
    if (e.metaKey) keys.push('cmd')
    keys.push(e.key.toLowerCase())
    return keys.join('+')
  }
}

// Terminal Output Hook
Hooks.TerminalOutput = {
  mounted() {
    this.scrollToBottom()
  },
  
  updated() {
    this.scrollToBottom()
  },
  
  scrollToBottom() {
    this.el.scrollTop = this.el.scrollHeight
  }
}

// Component Preview Hook
Hooks.ComponentPreview = {
  mounted() {
    this.setupResizeHandling()
  },
  
  setupResizeHandling() {
    const resizeHandle = this.el.querySelector('.resize-handle')
    if (resizeHandle) {
      let isResizing = false
      
      resizeHandle.addEventListener('mousedown', (e) => {
        isResizing = true
        document.addEventListener('mousemove', handleMouseMove)
        document.addEventListener('mouseup', handleMouseUp)
      })
      
      const handleMouseMove = (e) => {
        if (!isResizing) return
        const containerWidth = this.el.parentElement.offsetWidth
        const newWidth = (e.clientX / containerWidth) * 100
        this.el.style.width = Math.min(Math.max(newWidth, 20), 80) + '%'
      }
      
      const handleMouseUp = () => {
        isResizing = false
        document.removeEventListener('mousemove', handleMouseMove)
        document.removeEventListener('mouseup', handleMouseUp)
      }
    }
  }
}

// Initialize LiveSocket
let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
let liveSocket = new LiveSocket("/live", Socket, {
  params: {_csrf_token: csrfToken},
  hooks: Hooks,
  dom: {
    onBeforeElUpdated(from, to) {
      if (from._x_dataStack) {
        window.Alpine.clone(from, to)
      }
    }
  }
})

// Show progress bar on live navigation and form submits
topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"})
window.addEventListener("phx:page-loading-start", info => topbar.show())
window.addEventListener("phx:page-loading-stop", info => topbar.hide())

// Connect if there are any LiveViews on the page
liveSocket.connect()

// Expose liveSocket on window for web console debug logs and latency simulation
window.liveSocket = liveSocket