# WebAssembly Deployment

Raxol can compile to WebAssembly for in-browser terminal emulation without server-side processing.

## Prerequisites

**Rust Toolchain** (1.70+):
```bash
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
rustup target add wasm32-unknown-unknown
```

**wasm-opt** (optional, for optimization):
```bash
npm install -g wasm-opt
# or
brew install binaryen
```

**Elixir** 1.14+ with Mix.

**System requirements:** 4GB RAM for compilation, 500MB disk, macOS/Linux/WSL2.

## Building

```bash
mix raxol.wasm              # basic build
mix raxol.wasm --release    # optimized release
mix raxol.wasm --watch      # dev build with watch mode
```

### Build Config

Configure in `config/wasm.exs`:

```elixir
config :raxol, :wasm,
  output_dir: "priv/static/wasm",
  optimization_level: 2,
  initial_memory: 16,  # MB
  maximum_memory: 256, # MB

  features: [
    :terminal_emulation,
    :ansi_parsing,
    :themes,
    :basic_plugins
  ],

  exclude_features: [
    :docker_integration,
    :native_file_system
  ]
```

### Build Output

```
priv/static/
├── wasm/
│   ├── raxol.wasm        # ~200KB
│   └── index.html        # demo page
└── js/
    └── raxol-terminal.js # JS bindings
```

## Integration

### Vanilla JavaScript

```html
<!DOCTYPE html>
<html>
<head>
  <title>Raxol Terminal</title>
</head>
<body>
  <div id="terminal"></div>

  <script type="module">
    import { RaxolTerminal } from '/js/raxol-terminal.js';

    async function init() {
      const terminal = new RaxolTerminal(80, 24);
      await terminal.initialize('/wasm/raxol.wasm');

      terminal.writeLine('Welcome to Raxol Terminal!');
      terminal.write('$ ');

      document.addEventListener('keypress', (e) => {
        terminal.processInput(e.key);
      });
    }

    init();
  </script>
</body>
</html>
```

### React

```jsx
import React, { useEffect, useRef, useState } from 'react';
import { RaxolTerminal } from './raxol-terminal';

function Terminal({ width = 80, height = 24 }) {
  const terminalRef = useRef(null);
  const [ready, setReady] = useState(false);

  useEffect(() => {
    const terminal = new RaxolTerminal(width, height);

    terminal.initialize('/wasm/raxol.wasm').then(() => {
      terminalRef.current = terminal;
      setReady(true);
    });

    return () => terminal.destroy();
  }, [width, height]);

  const handleInput = (text) => {
    if (terminalRef.current) {
      terminalRef.current.processInput(text);
    }
  };

  return (
    <div className="terminal-container">
      {!ready && <div>Loading terminal...</div>}
      <canvas id="terminal-canvas" />
      <input
        type="text"
        onKeyPress={(e) => {
          if (e.key === 'Enter') {
            handleInput(e.target.value + '\n');
            e.target.value = '';
          }
        }}
      />
    </div>
  );
}

export default Terminal;
```

### Vue.js

```vue
<template>
  <div class="raxol-terminal">
    <div v-if="!ready">Loading terminal...</div>
    <canvas ref="canvas" :width="pixelWidth" :height="pixelHeight" />
    <input
      v-model="inputBuffer"
      @keyup.enter="sendInput"
      class="terminal-input"
    />
  </div>
</template>

<script>
import { RaxolTerminal } from './raxol-terminal';

export default {
  name: 'RaxolTerminal',
  props: {
    width: { type: Number, default: 80 },
    height: { type: Number, default: 24 }
  },
  data() {
    return {
      terminal: null,
      ready: false,
      inputBuffer: ''
    };
  },
  computed: {
    pixelWidth() {
      return this.width * 10;
    },
    pixelHeight() {
      return this.height * 20;
    }
  },
  async mounted() {
    this.terminal = new RaxolTerminal(this.width, this.height);
    await this.terminal.initialize('/wasm/raxol.wasm');
    this.ready = true;
    this.render();
  },
  beforeUnmount() {
    if (this.terminal) {
      this.terminal.destroy();
    }
  },
  methods: {
    sendInput() {
      this.terminal.processInput(this.inputBuffer + '\n');
      this.inputBuffer = '';
      this.render();
    },
    render() {
      const ctx = this.$refs.canvas.getContext('2d');
      const output = this.terminal.getOutput();
      // ... rendering logic
    }
  }
};
</script>
```

### Web Components

```javascript
class RaxolTerminalElement extends HTMLElement {
  constructor() {
    super();
    this.attachShadow({ mode: 'open' });
    this.terminal = null;
  }

  async connectedCallback() {
    const width = this.getAttribute('width') || 80;
    const height = this.getAttribute('height') || 24;

    this.shadowRoot.innerHTML = `
      <style>
        :host {
          display: block;
          background: #2e3436;
          padding: 10px;
        }
        canvas {
          display: block;
        }
      </style>
      <canvas></canvas>
    `;

    this.terminal = new RaxolTerminal(width, height);
    await this.terminal.initialize('/wasm/raxol.wasm');
    this.render();
  }

  disconnectedCallback() {
    if (this.terminal) {
      this.terminal.destroy();
    }
  }

  render() {
    const canvas = this.shadowRoot.querySelector('canvas');
    // Render terminal output
  }
}

customElements.define('raxol-terminal', RaxolTerminalElement);
```

Usage:
```html
<raxol-terminal width="80" height="24"></raxol-terminal>
```

## Deployment Strategies

### Static Hosting (CDN)

Works well for public sites and documentation.

```bash
mix raxol.wasm --release

aws s3 cp priv/static/wasm/raxol.wasm s3://my-cdn/wasm/
aws s3 cp priv/static/js/raxol-terminal.js s3://my-cdn/js/

aws s3 cp s3://my-cdn/wasm/raxol.wasm s3://my-cdn/wasm/raxol.wasm \
  --content-type "application/wasm" \
  --cache-control "public, max-age=31536000"
```

### Application Bundle

For SPAs and React/Vue apps:

```javascript
// webpack.config.js
module.exports = {
  module: {
    rules: [
      {
        test: /\.wasm$/,
        type: 'webassembly/async',
      }
    ]
  },
  experiments: {
    asyncWebAssembly: true
  }
};
```

```javascript
import wasmModule from './raxol.wasm';

const terminal = new RaxolTerminal(80, 24);
await terminal.initializeFromModule(wasmModule);
```

### Service Worker (Offline/PWA)

```javascript
// service-worker.js
const CACHE_NAME = 'raxol-v1';
const urlsToCache = [
  '/wasm/raxol.wasm',
  '/js/raxol-terminal.js'
];

self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(CACHE_NAME)
      .then(cache => cache.addAll(urlsToCache))
  );
});

self.addEventListener('fetch', (event) => {
  if (event.request.url.includes('.wasm')) {
    event.respondWith(
      caches.match(event.request)
        .then(response => response || fetch(event.request))
    );
  }
});
```

### SSR Frameworks

WASM is client-side only. In Next.js, use dynamic imports:

```javascript
import dynamic from 'next/dynamic';

const RaxolTerminal = dynamic(
  () => import('../components/RaxolTerminal'),
  {
    ssr: false,
    loading: () => <p>Loading terminal...</p>
  }
);

export default function Page() {
  return <RaxolTerminal />;
}
```

## Performance

### Lazy Loading

Load the WASM module only when needed:

```javascript
const loadTerminal = async () => {
  const { RaxolTerminal } = await import('./raxol-terminal');
  const terminal = new RaxolTerminal(80, 24);
  await terminal.initialize('/wasm/raxol.wasm');
  return terminal;
};

button.addEventListener('click', async () => {
  const terminal = await loadTerminal();
  terminal.show();
});
```

### Compression

Enable gzip/brotli on your server:

```nginx
# nginx.conf
location ~ \.wasm$ {
  gzip_static on;
  brotli_static on;
  add_header Content-Type application/wasm;
  add_header Cache-Control "public, max-age=31536000";
}
```

### Memory Management

```javascript
const terminal = new RaxolTerminal(80, 24, {
  memory: {
    initial: 8,    // 8MB
    maximum: 64,   // 64MB
    shared: false  // use SharedArrayBuffer if available
  }
});

// Clean up when done
terminal.destroy();
```

### Rendering

```javascript
// Throttle renders with requestAnimationFrame
let renderRequested = false;

function requestRender() {
  if (!renderRequested) {
    renderRequested = true;
    requestAnimationFrame(() => {
      terminal.render();
      renderRequested = false;
    });
  }
}

const handleInput = debounce((input) => {
  terminal.processInput(input);
  requestRender();
}, 16); // ~60fps
```

## Browser Compatibility

| Browser | Minimum Version | Notes |
|---------|----------------|-------|
| Chrome | 57+ | Full support |
| Firefox | 52+ | Full support |
| Safari | 11+ | Limited SharedArrayBuffer |
| Edge | 79+ | Chromium-based |
| Opera | 44+ | Full support |

### Feature Detection

```javascript
if (typeof WebAssembly === 'undefined') {
  console.error('WebAssembly not supported');
  return;
}

const features = {
  wasm: typeof WebAssembly !== 'undefined',
  instantiateStreaming: typeof WebAssembly.instantiateStreaming === 'function',
  sharedArrayBuffer: typeof SharedArrayBuffer !== 'undefined'
};

if (!features.instantiateStreaming) {
  WebAssembly.instantiateStreaming = async (resp, imports) => {
    const source = await (await resp).arrayBuffer();
    return await WebAssembly.instantiate(source, imports);
  };
}
```

### Mobile

```javascript
const isMobile = /iPhone|iPad|iPod|Android/i.test(navigator.userAgent);

const terminal = new RaxolTerminal(
  isMobile ? 40 : 80,
  isMobile ? 20 : 24
);

if (isMobile) {
  terminal.enableTouchKeyboard();
}
```

## Troubleshooting

### WASM module fails to load

Check that Content-Type is `application/wasm`, the file path is correct, and CORS headers are set if loading cross-origin.

### Memory errors ("Cannot grow memory")

Increase initial memory:
```javascript
const terminal = new RaxolTerminal(80, 24, {
  memory: { initial: 32, maximum: 256 }
});
```

### Slow rendering, high CPU

Reduce terminal size, use `mix raxol.wasm --release`, use production JS builds, and add render throttling.

### Input not captured

```javascript
terminalElement.focus();

document.addEventListener('keydown', (e) => {
  if (terminal.isActive()) {
    e.preventDefault();
    terminal.handleKeyDown(e);
  }
});
```

### Debug mode

```javascript
const terminal = new RaxolTerminal(80, 24, {
  debug: true,
  logLevel: 'verbose'
});

terminal.on('metrics', (metrics) => {
  console.log('FPS:', metrics.fps);
  console.log('Memory:', metrics.memory);
});
```

### Error reporting

```javascript
window.addEventListener('error', (e) => {
  if (e.error && e.error.stack.includes('wasm')) {
    console.error('WASM Error:', e.error);
  }
});
```

## Advanced

### Custom Protocols

```javascript
terminal.registerProtocol('custom', {
  pattern: /\x1b\[custom:([^;]+);/,
  handler: (match, args) => {
    console.log('Custom protocol:', args);
  }
});
```

### Dynamic Plugins

```javascript
async function loadPlugin(url) {
  const response = await fetch(url);
  const bytes = await response.arrayBuffer();
  const module = await WebAssembly.instantiate(bytes, {
    env: terminal.getPluginImports()
  });

  terminal.registerPlugin(module.instance.exports);
}

await loadPlugin('/plugins/rainbow-theme.wasm');
```

### Streaming Output

```javascript
const decoder = new TextDecoder();
const reader = response.body.getReader();

while (true) {
  const { done, value } = await reader.read();
  if (done) break;

  const text = decoder.decode(value, { stream: true });
  terminal.processInput(text);
}
```

## Security

### Content Security Policy

```html
<meta http-equiv="Content-Security-Policy" content="
  default-src 'self';
  script-src 'self' 'wasm-unsafe-eval';
  worker-src 'self' blob:;
">
```

### Sandboxing

```javascript
const iframe = document.createElement('iframe');
iframe.sandbox = 'allow-scripts';
iframe.src = '/terminal.html';
document.body.appendChild(iframe);

iframe.contentWindow.postMessage({
  type: 'input',
  data: 'ls -la\n'
}, '*');
```

### Input Validation

```javascript
function sanitizeInput(input) {
  return input.replace(/[\x00-\x08\x0B-\x0C\x0E-\x1F\x7F]/g, '');
}

terminal.processInput(sanitizeInput(userInput));
```

## Resources

- [WebAssembly MDN Documentation](https://developer.mozilla.org/en-US/docs/WebAssembly)
- [Raxol GitHub Repository](https://github.com/axol/raxol)
- [WASM Performance Best Practices](https://developers.google.com/web/updates/2019/02/hotpath-with-wasm)
- [Terminal Emulator Standards](https://invisible-island.net/xterm/ctlseqs/ctlseqs.html)
