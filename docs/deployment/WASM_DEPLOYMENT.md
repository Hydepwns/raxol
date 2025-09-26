# Raxol WebAssembly Deployment Guide

## Overview

Raxol can be compiled to WebAssembly (WASM) for deployment in web browsers, enabling terminal emulation directly in the browser without server-side processing. This guide covers building, deploying, and integrating Raxol's WASM module.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Building WASM Module](#building-wasm-module)
3. [Integration Options](#integration-options)
4. [Deployment Strategies](#deployment-strategies)
5. [Performance Optimization](#performance-optimization)
6. [Browser Compatibility](#browser-compatibility)
7. [Troubleshooting](#troubleshooting)

## Prerequisites

### Required Tools

1. **Rust Toolchain** (1.70+)
   ```bash
   curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
   rustup target add wasm32-unknown-unknown
   ```

2. **wasm-opt** (Optional, for optimization)
   ```bash
   npm install -g wasm-opt
   # or
   brew install binaryen
   ```

3. **Elixir** (1.14+) with Mix

### System Requirements

- 4GB RAM minimum for compilation
- 500MB free disk space
- macOS, Linux, or Windows with WSL2

## Building WASM Module

### Quick Build

```bash
# Basic build
mix raxol.wasm

# Optimized release build
mix raxol.wasm --release

# Development build with watch mode
mix raxol.wasm --watch
```

### Build Configuration

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

The build generates:

```
priv/static/
├── wasm/
│   ├── raxol.wasm        # WebAssembly module (~200KB)
│   └── index.html        # Demo page
└── js/
    └── raxol-terminal.js # JavaScript bindings
```

## Integration Options

### 1. Vanilla JavaScript

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

      // Basic usage
      terminal.writeLine('Welcome to Raxol Terminal!');
      terminal.write('$ ');

      // Handle input
      document.addEventListener('keypress', (e) => {
        terminal.processInput(e.key);
      });
    }

    init();
  </script>
</body>
</html>
```

### 2. React Component

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

### 3. Vue.js Component

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
      return this.width * 10; // 10px per character
    },
    pixelHeight() {
      return this.height * 20; // 20px per line
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
      // Render terminal output to canvas
      const ctx = this.$refs.canvas.getContext('2d');
      const output = this.terminal.getOutput();
      // ... rendering logic
    }
  }
};
</script>
```

### 4. Web Components

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

### 1. Static Hosting (CDN)

**Recommended for:** Public websites, documentation sites

```bash
# Build optimized version
mix raxol.wasm --release

# Upload to CDN
aws s3 cp priv/static/wasm/raxol.wasm s3://my-cdn/wasm/
aws s3 cp priv/static/js/raxol-terminal.js s3://my-cdn/js/

# Set appropriate headers
aws s3 cp s3://my-cdn/wasm/raxol.wasm s3://my-cdn/wasm/raxol.wasm \
  --content-type "application/wasm" \
  --cache-control "public, max-age=31536000"
```

### 2. Application Bundle

**Recommended for:** SPAs, React/Vue applications

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
// Import and use
import wasmModule from './raxol.wasm';

const terminal = new RaxolTerminal(80, 24);
await terminal.initializeFromModule(wasmModule);
```

### 3. Service Worker Caching

**Recommended for:** Offline support, PWAs

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

### 4. Server-Side Rendering (SSR)

**Note:** WASM runs client-side only

```javascript
// Next.js example
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

## Performance Optimization

### 1. Lazy Loading

```javascript
// Load WASM only when needed
const loadTerminal = async () => {
  const { RaxolTerminal } = await import('./raxol-terminal');
  const terminal = new RaxolTerminal(80, 24);
  await terminal.initialize('/wasm/raxol.wasm');
  return terminal;
};

// Triggered by user action
button.addEventListener('click', async () => {
  const terminal = await loadTerminal();
  terminal.show();
});
```

### 2. Compression

Enable gzip/brotli compression on your server:

```nginx
# nginx.conf
location ~ \.wasm$ {
  gzip_static on;
  brotli_static on;
  add_header Content-Type application/wasm;
  add_header Cache-Control "public, max-age=31536000";
}
```

### 3. Memory Management

```javascript
// Configure memory limits
const terminal = new RaxolTerminal(80, 24, {
  memory: {
    initial: 8,    // 8MB initial
    maximum: 64,   // 64MB maximum
    shared: false  // Use SharedArrayBuffer if available
  }
});

// Clean up when done
terminal.destroy();
```

### 4. Rendering Optimization

```javascript
// Use requestAnimationFrame for smooth rendering
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

// Debounce input handling
const handleInput = debounce((input) => {
  terminal.processInput(input);
  requestRender();
}, 16); // ~60fps
```

## Browser Compatibility

### Supported Browsers

| Browser | Minimum Version | Notes |
|---------|----------------|-------|
| Chrome | 57+ | Full support |
| Firefox | 52+ | Full support |
| Safari | 11+ | Limited SharedArrayBuffer |
| Edge | 79+ | Chromium-based |
| Opera | 44+ | Full support |

### Feature Detection

```javascript
// Check WASM support
if (typeof WebAssembly === 'undefined') {
  console.error('WebAssembly not supported');
  // Fall back to server-side terminal
  return;
}

// Check for required features
const features = {
  wasm: typeof WebAssembly !== 'undefined',
  instantiateStreaming: typeof WebAssembly.instantiateStreaming === 'function',
  sharedArrayBuffer: typeof SharedArrayBuffer !== 'undefined'
};

// Adapt based on capabilities
if (!features.instantiateStreaming) {
  // Use polyfill
  WebAssembly.instantiateStreaming = async (resp, imports) => {
    const source = await (await resp).arrayBuffer();
    return await WebAssembly.instantiate(source, imports);
  };
}
```

### Mobile Support

```javascript
// Detect mobile and adjust
const isMobile = /iPhone|iPad|iPod|Android/i.test(navigator.userAgent);

const terminal = new RaxolTerminal(
  isMobile ? 40 : 80,  // Smaller width on mobile
  isMobile ? 20 : 24   // Fewer lines on mobile
);

// Touch input handling
if (isMobile) {
  terminal.enableTouchKeyboard();
}
```

## Troubleshooting

### Common Issues

#### 1. WASM Module Failed to Load

**Error:** `Failed to compile WebAssembly module`

**Solutions:**
- Check Content-Type header is `application/wasm`
- Verify file path is correct
- Ensure CORS headers if loading cross-origin
- Check browser console for detailed error

#### 2. Memory Error

**Error:** `Cannot grow memory`

**Solutions:**
```javascript
// Increase initial memory
const terminal = new RaxolTerminal(80, 24, {
  memory: { initial: 32, maximum: 256 }
});
```

#### 3. Performance Issues

**Symptoms:** Slow rendering, high CPU usage

**Solutions:**
- Reduce terminal size
- Enable optimization: `mix raxol.wasm --release`
- Use production build of JavaScript
- Implement render throttling

#### 4. Input Not Working

**Error:** Keyboard input not captured

**Solutions:**
```javascript
// Ensure focus
terminalElement.focus();

// Prevent default behaviors
document.addEventListener('keydown', (e) => {
  if (terminal.isActive()) {
    e.preventDefault();
    terminal.handleKeyDown(e);
  }
});
```

### Debug Mode

Enable debug output:

```javascript
const terminal = new RaxolTerminal(80, 24, {
  debug: true,
  logLevel: 'verbose'
});

// Monitor performance
terminal.on('metrics', (metrics) => {
  console.log('FPS:', metrics.fps);
  console.log('Memory:', metrics.memory);
});
```

### Error Reporting

```javascript
window.addEventListener('error', (e) => {
  if (e.error && e.error.stack.includes('wasm')) {
    // Report WASM errors
    console.error('WASM Error:', e.error);
    // Send to error tracking service
  }
});
```

## Advanced Topics

### Custom Protocols

Implement custom terminal protocols:

```javascript
terminal.registerProtocol('custom', {
  pattern: /\x1b\[custom:([^;]+);/,
  handler: (match, args) => {
    // Handle custom sequence
    console.log('Custom protocol:', args);
  }
});
```

### Plugin System

Load WASM plugins dynamically:

```javascript
async function loadPlugin(url) {
  const response = await fetch(url);
  const bytes = await response.arrayBuffer();
  const module = await WebAssembly.instantiate(bytes, {
    env: terminal.getPluginImports()
  });

  terminal.registerPlugin(module.instance.exports);
}

// Usage
await loadPlugin('/plugins/rainbow-theme.wasm');
```

### Streaming Output

Handle large outputs efficiently:

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

## Security Considerations

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
// Run terminal in sandboxed iframe
const iframe = document.createElement('iframe');
iframe.sandbox = 'allow-scripts';
iframe.src = '/terminal.html';
document.body.appendChild(iframe);

// Communicate via postMessage
iframe.contentWindow.postMessage({
  type: 'input',
  data: 'ls -la\n'
}, '*');
```

### Input Validation

```javascript
// Sanitize user input
function sanitizeInput(input) {
  // Remove control characters except standard ones
  return input.replace(/[\x00-\x08\x0B-\x0C\x0E-\x1F\x7F]/g, '');
}

terminal.processInput(sanitizeInput(userInput));
```

## Resources

- [WebAssembly MDN Documentation](https://developer.mozilla.org/en-US/docs/WebAssembly)
- [Raxol GitHub Repository](https://github.com/axol/raxol)
- [WASM Performance Best Practices](https://developers.google.com/web/updates/2019/02/hotpath-with-wasm)
- [Terminal Emulator Standards](https://invisible-island.net/xterm/ctlseqs/ctlseqs.html)

## Support

For issues or questions:
- GitHub Issues: [github.com/axol/raxol/issues](https://github.com/axol/raxol/issues)
- Documentation: [raxol.io/docs](https://raxol.io/docs)
- Community Discord: [discord.gg/raxol](https://discord.gg/raxol)