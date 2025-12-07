# Deployment Guide

Deploy Raxol applications to production environments.

## Deployment Options

### [Fly.io](FLY_IO.md) - Primary Production Hosting
Phoenix LiveView playground with full backend capabilities.

- **URL**: https://raxol.fly.dev
- **Features**: Auto-scaling, WebSocket support, PostgreSQL
- **Stack**: Phoenix, LiveView, Elixir/OTP
- **Commands**: `flyctl deploy`

### [WASM](WASM.md) - Browser Deployment
Compile Raxol to WebAssembly for client-side execution.

- **Use Cases**: Offline apps, embedded terminals, zero-server deployment
- **Stack**: Elixir → BEAM → WASM
- **Limitations**: Experimental, limited BEAM features

## Quick Start

### Fly.io Deployment

```bash
# Install Fly CLI
brew install flyctl

# Login
flyctl auth login

# Deploy
flyctl deploy

# Check status
flyctl status --app raxol
```

### WASM Build

```bash
# Build WASM binary
mix raxol.wasm.build

# Serve locally
mix raxol.wasm.serve
```

## Infrastructure

- **Primary**: Fly.io (production)
- **CDN**: Cloudflare Pages (static assets, optional)
- **Metrics**: GitHub Pages (performance dashboard)

See [FLY_IO.md](FLY_IO.md) for complete infrastructure details.
