/**
 * Raxol Web Application Entry Point
 */

// Phoenix and LiveView are available from deps via esbuild NODE_PATH
import { Socket } from "phoenix"
import { LiveSocket } from "phoenix_live_view"
import TerminalDemo from "./terminal_hook"

// LiveView hooks
const Hooks = {
  TerminalDemo
}

// CSRF token for secure requests
const csrfToken = document.querySelector("meta[name='csrf-token']")?.getAttribute('content')

// Create LiveSocket connection
const liveSocket = new LiveSocket('/live', Socket, {
  hooks: Hooks,
  params: { _csrf_token: csrfToken }
})

// Expose socket for terminal hook channel access
window.liveSocket = liveSocket

// Only connect if not already connected
if (!window.liveSocketConnected) {
  window.liveSocketConnected = true
  liveSocket.connect()
}
