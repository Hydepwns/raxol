# Deployment Guide

## Options

### [Fly.io](FLY_IO.md) -- Primary Production

Phoenix LiveView playground with full backend. Auto-scaling, WebSocket support, PostgreSQL.

- **URL**: https://raxol.fly.dev
- **Deploy**: `flyctl deploy`

### [WASM](WASM.md) -- Browser Deployment

Compile Raxol to WebAssembly for client-side execution. Experimental, with limited BEAM feature support. Useful for offline apps, embedded terminals, and zero-server deployment.

## Quick Start

### Fly.io

```bash
brew install flyctl
flyctl auth login
flyctl deploy
flyctl status --app raxol
```

### WASM

```bash
mix raxol.wasm.build
mix raxol.wasm.serve
```

## Infrastructure

- **Primary**: Fly.io (production app)
- **CDN**: Cloudflare Pages (static assets, optional)
- **Metrics**: GitHub Pages (performance dashboard)

See [FLY_IO.md](FLY_IO.md) for full infrastructure details.
