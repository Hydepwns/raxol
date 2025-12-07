# Deployment Architecture

> [Documentation](../README.md) > [Deployment](README.md) > Fly.io

Raxol uses a multi-tier deployment strategy optimized for different use cases. This document outlines the hosting infrastructure, deployment targets, and their respective purposes.

## Production Hosting Infrastructure

### Primary: Fly.io (Phoenix LiveView Playground)

**URL:** `https://raxol.fly.dev`

**Purpose:** Interactive playground with full backend capabilities

**Status:** ✅ Active and Production Ready
- 2 machines running in SJC region
- Auto-scaling enabled (min: 0, max: dynamic)
- 1GB memory per instance
- Shared CPU (1 core)

**Technology Stack:**
- Phoenix LiveView application
- Full Elixir/OTP runtime
- WebSocket support for real-time interaction
- PostgreSQL (if needed for session persistence)

**Configuration:**
- `fly.toml` - Application configuration
- `docker/Dockerfile.web` - Multi-stage Docker build
- Release command: `/app/bin/migrate`

**Deployment:**
```bash
# Manual deployment
flyctl deploy

# Check status
flyctl status --app raxol

# View logs
flyctl logs --app raxol
```

**Features:**
- Auto-start/stop machines based on traffic
- Force HTTPS
- Custom domain support (raxol.io)
- Connection pooling (soft: 1000, hard: 1000)

### Secondary: Cloudflare Pages (Static Assets)

**Purpose:** CDN for static assets and documentation

**Status:** 🟡 Available (optional)
- Configured but not required for primary functionality
- Can be used to offload static content from Fly.io

**Configuration:**
- `.github/workflows/deploy-web.yml` - Automated deployment
- Deploys `web/priv/static` directory
- Triggered on push to `master` branch

**Limitations:**
- Static files only (HTML, CSS, JS)
- No backend/Phoenix runtime
- No WebSocket support
- Cannot run LiveView features

**Use Case:**
- Marketing pages
- Documentation hosting
- Static asset CDN
- Reduced Fly.io bandwidth usage

### Tertiary: GitHub Pages (Performance Dashboard)

**URL:** GitHub Pages `/performance` subdirectory

**Purpose:** Performance metrics and benchmarking dashboard

**Status:** ✅ Active for metrics only

**Configuration:**
- `.github/workflows/performance-tracking.yml`
- Deploys `docs/performance` directory
- Uses `peaceiris/actions-gh-pages@v4`

**Content:**
- Performance benchmark results
- Historical trend analysis
- Pre-commit check timings
- Not for application hosting

## Deployment Targets Comparison

| Feature | Fly.io | Cloudflare Pages | GitHub Pages |
|---------|--------|------------------|--------------|
| **Primary Use** | Full Application | Static CDN | Metrics Dashboard |
| **Phoenix/LiveView** | ✅ Full Support | ❌ No Backend | ❌ Static Only |
| **WebSockets** | ✅ Yes | ❌ No | ❌ No |
| **Custom Domain** | ✅ raxol.io | ✅ Possible | ✅ Limited |
| **Backend Processing** | ✅ Yes | ❌ No | ❌ No |
| **Auto-scaling** | ✅ Yes | ✅ CDN | N/A |
| **Cost** | Pay-per-use | Free tier | Free |
| **Deploy Method** | flyctl/Docker | GitHub Actions | GitHub Actions |
| **SSL/HTTPS** | ✅ Automatic | ✅ Automatic | ✅ Automatic |

## Recommended Architecture

### Production Setup (Recommended)

```
┌─────────────────────┐
│   raxol.io Domain   │
└──────────┬──────────┘
           │
           ├──────────────────────────────────┐
           │                                  │
           v                                  v
┌──────────────────────┐         ┌─────────────────────┐
│   Fly.io (Primary)   │         │ Cloudflare Pages    │
│  Phoenix LiveView    │         │   (Optional CDN)    │
│  Full Application    │◄────────│   Static Assets     │
│  raxol.fly.dev       │         │   /static/*         │
└──────────────────────┘         └─────────────────────┘
           │
           │ (Optional)
           v
┌──────────────────────┐
│   PostgreSQL DB      │
│   (Fly.io managed)   │
└──────────────────────┘
```

### Why Fly.io is Primary

1. **Full Phoenix Support**: Complete Elixir/OTP runtime
2. **LiveView Required**: WebSocket connections for interactive features
3. **Backend Logic**: Plugin system, session management, state
4. **Already Deployed**: 2 machines currently running
5. **Cost Effective**: Auto-stop when idle (min: 0 machines)

### When to Use Cloudflare Pages

- ✅ Offload static documentation
- ✅ Reduce Fly.io bandwidth costs
- ✅ Marketing landing pages
- ❌ Not for main playground (requires backend)

## CI/CD Pipeline

### Automated Deployments

**On Push to Master:**
1. Unit, Integration, Property tests run
2. Code quality checks (Credo, Dialyzer)
3. Security audit
4. Cloudflare Pages deploys static assets (if configured)

**Manual Deployment to Fly.io:**
```bash
# Build and deploy
flyctl deploy

# With specific Dockerfile
flyctl deploy --dockerfile docker/Dockerfile.web

# Deploy with secrets
flyctl secrets set DATABASE_URL=...
```

### GitHub Actions Workflows

- `.github/workflows/ci-unified.yml` - Test and quality checks
- `.github/workflows/deploy-web.yml` - Cloudflare Pages deployment
- `.github/workflows/performance-tracking.yml` - Metrics to GitHub Pages
- `.github/workflows/security.yml` - Security scanning

## Environment Configuration

### Fly.io Environment Variables

```toml
# fly.toml
[env]
  PHX_HOST = 'raxol.fly.dev'
  PORT = '8080'
```

### Required Secrets

```bash
# Set via flyctl
flyctl secrets set SECRET_KEY_BASE="..."
flyctl secrets set DATABASE_URL="..." # If using PostgreSQL
```

### Build-time Variables

```dockerfile
# docker/Dockerfile.web
ENV MIX_ENV="prod"
ENV SKIP_TERMBOX2_TESTS="true"
ENV TMPDIR="/tmp"
```

## Monitoring and Observability

### Fly.io Monitoring

```bash
# View metrics
flyctl dashboard

# Check machine status
flyctl status

# Live logs
flyctl logs

# SSH into machine
flyctl ssh console
```

### Performance Tracking

- Automated benchmarks run on schedule
- Results published to GitHub Pages
- Historical trends tracked in artifacts
- Performance regression alerts (5% tolerance)

## Disaster Recovery

### Backup Strategy

1. **Application State**: Managed via Fly.io snapshots
2. **Configuration**: Version controlled in git
3. **Database**: Fly.io PostgreSQL automatic backups (if used)
4. **Secrets**: Stored in Fly.io secrets (not in git)

### Rollback Procedure

```bash
# List deployments
flyctl releases

# Rollback to previous
flyctl releases rollback

# Specific version
flyctl releases rollback --version X
```

## Domain Configuration

### Current Setup

- **Production**: `raxol.fly.dev` (Fly.io default)
- **Custom Domain**: `raxol.io` (purchased, needs DNS configuration)

### DNS Configuration for raxol.io

```bash
# Add custom domain
flyctl certs create raxol.io

# Check certificate status
flyctl certs show raxol.io
```

**DNS Records (to configure):**
```
# A Record
raxol.io -> [Fly.io IP]

# CNAME (alternative)
raxol.io -> raxol.fly.dev
```

## Security Considerations

### Fly.io Security

- ✅ Automatic HTTPS/SSL certificates
- ✅ Network isolation between machines
- ✅ Secrets encrypted at rest
- ✅ Regular security patches

### GitHub Actions Security

- ✅ Secrets stored in GitHub Secrets
- ✅ Workflow approval for production deploys
- ✅ Branch protection rules
- ✅ Dependabot security updates

## Cost Optimization

### Fly.io Free Tier

- 3 shared-cpu-1x machines with 256MB RAM (free)
- Current setup: 2x 1GB machines (pays for extra RAM)
- Auto-stop reduces costs when idle

### Optimization Tips

1. **Set min_machines_running = 0**: Auto-stop when idle
2. **Use Cloudflare Pages**: Offload static assets
3. **Optimize Docker image**: Multi-stage builds reduce size
4. **Connection pooling**: Reduce resource usage

## Troubleshooting

### Common Issues

**Deployment Fails:**
```bash
# Check logs
flyctl logs

# Verify secrets
flyctl secrets list

# Check machine health
flyctl status
```

**Assets Not Loading:**
- Verify `mix phx.digest` ran successfully
- Check `web/priv/static` directory exists
- Ensure correct paths in templates

**WebSocket Connection Fails:**
- Verify `force_https = true` in fly.toml
- Check WebSocket endpoint configuration
- Ensure port 8080 is exposed

## References

- [Fly.io Documentation](https://fly.io/docs/)
- [Phoenix Deployment Guide](https://hexdocs.pm/phoenix/deployment.html)
- [Cloudflare Pages Docs](https://developers.cloudflare.com/pages/)
- Project: `fly.toml` configuration
- Project: `docker/Dockerfile.web` build configuration
