import { TerminalScroll } from "./terminal_live";
import { Socket } from "phoenix";
import { LiveSocket } from "phoenix_live_view";

let Hooks = {};
Hooks.TerminalScroll = TerminalScroll;

let csrfToken = document
  .querySelector("meta[name='csrf-token']")
  ?.getAttribute("content");
let liveSocket = new LiveSocket("/live", Socket, {
  hooks: Hooks,
  params: { _csrf_token: csrfToken },
});

liveSocket.connect();

window.liveSocket = liveSocket;
