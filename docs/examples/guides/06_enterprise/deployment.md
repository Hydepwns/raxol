# Deployment & Operations

Production deployment strategies and operational best practices for Raxol applications.

## Overview

Raxol applications can be deployed in various environments, from single servers to distributed clusters. This guide covers deployment strategies, containerization, orchestration, and operational considerations.

## Deployment Strategies

### Release Building

#### Using Mix Releases

```bash
# Build a release
MIX_ENV=prod mix deps.get
MIX_ENV=prod mix compile
MIX_ENV=prod mix release

# The release will be in _build/prod/rel/my_app
```

#### Release Configuration

```elixir
# mix.exs
def project do
  [
    releases: [
      my_app: [
        version: "1.0.0",
        applications: [runtime_tools: :permanent],
        include_executables_for: [:unix],
        steps: [:assemble, :tar]
      ]
    ]
  ]
end

# config/releases.exs
import Config

config :my_app, MyAppWeb.Endpoint,
  server: true,
  http: [port: {:system, "PORT"}],
  url: [host: {:system, "HOST"}, port: 443]

config :my_app, :database,
  url: {:system, "DATABASE_URL"}
```

### Container Deployment

#### Dockerfile

```dockerfile
# Build stage
FROM elixir:1.14-alpine AS build

# Install build dependencies
RUN apk add --no-cache build-base git python3

# Prepare build dir
WORKDIR /app

# Install hex + rebar
RUN mix local.hex --force && \
    mix local.rebar --force

# Set build ENV
ENV MIX_ENV=prod

# Install mix dependencies
COPY mix.exs mix.lock ./
RUN mix deps.get --only prod && \
    mix deps.compile

# Copy source
COPY lib lib
COPY priv priv
COPY config config

# Compile and build release
RUN mix do compile, release

# Release stage
FROM alpine:3.17 AS app

RUN apk add --no-cache openssl ncurses-libs

WORKDIR /app

# Create non-root user
RUN addgroup -g 1000 -S app && \
    adduser -u 1000 -S app -G app

# Copy release from build stage
COPY --from=build --chown=app:app /app/_build/prod/rel/my_app ./

USER app

# Set runtime ENV
ENV HOME=/app

EXPOSE 4000

CMD ["bin/my_app", "start"]
```

#### Docker Compose

```yaml
version: '3.8'

services:
  app:
    build: .
    ports:
      - "4000:4000"
    environment:
      - DATABASE_URL=postgres://user:pass@db:5432/myapp
      - SECRET_KEY_BASE=${SECRET_KEY_BASE}
      - PHX_HOST=localhost
    depends_on:
      - db
      - redis

  db:
    image: postgres:14-alpine
    volumes:
      - postgres_data:/var/lib/postgresql/data
    environment:
      - POSTGRES_USER=user
      - POSTGRES_PASSWORD=pass
      - POSTGRES_DB=myapp

  redis:
    image: redis:7-alpine
    volumes:
      - redis_data:/data

volumes:
  postgres_data:
  redis_data:
```

### Kubernetes Deployment

#### Deployment Manifest

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: raxol-app
  labels:
    app: raxol
spec:
  replicas: 3
  selector:
    matchLabels:
      app: raxol
  template:
    metadata:
      labels:
        app: raxol
    spec:
      containers:
      - name: raxol
        image: myregistry/raxol-app:latest
        ports:
        - containerPort: 4000
        env:
        - name: RELEASE_COOKIE
          valueFrom:
            secretKeyRef:
              name: raxol-secrets
              key: cookie
        - name: DATABASE_URL
          valueFrom:
            secretKeyRef:
              name: raxol-secrets
              key: database-url
        resources:
          requests:
            memory: "256Mi"
            cpu: "100m"
          limits:
            memory: "512Mi"
            cpu: "200m"
        livenessProbe:
          httpGet:
            path: /health/live
            port: 4000
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /health/ready
            port: 4000
          initialDelaySeconds: 5
          periodSeconds: 5
```

#### Service & Ingress

```yaml
---
apiVersion: v1
kind: Service
metadata:
  name: raxol-service
spec:
  selector:
    app: raxol
  ports:
    - port: 80
      targetPort: 4000
  type: ClusterIP

---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: raxol-ingress
  annotations:
    nginx.ingress.kubernetes.io/affinity: "cookie"
    nginx.ingress.kubernetes.io/session-cookie-name: "raxol-session"
spec:
  rules:
  - host: app.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: raxol-service
            port:
              number: 80
```

## Load Balancing

### HAProxy Configuration

```
global
    maxconn 4096
    log stdout local0

defaults
    mode http
    timeout connect 5000ms
    timeout client 50000ms
    timeout server 50000ms
    option httplog

frontend web
    bind *:80
    bind *:443 ssl crt /etc/ssl/certs/cert.pem
    redirect scheme https if !{ ssl_fc }
    
    # WebSocket detection
    acl is_websocket hdr(Upgrade) -i WebSocket
    use_backend websocket if is_websocket
    
    default_backend web_servers

backend web_servers
    balance roundrobin
    option httpchk GET /health/ready
    server web1 10.0.1.10:4000 check
    server web2 10.0.1.11:4000 check
    server web3 10.0.1.12:4000 check

backend websocket
    balance source
    option http-server-close
    option forceclose
    server ws1 10.0.1.10:4000 check
    server ws2 10.0.1.11:4000 check
    server ws3 10.0.1.12:4000 check
```

### Nginx Configuration

```nginx
upstream raxol_backend {
    least_conn;
    server 10.0.1.10:4000 max_fails=3 fail_timeout=30s;
    server 10.0.1.11:4000 max_fails=3 fail_timeout=30s;
    server 10.0.1.12:4000 max_fails=3 fail_timeout=30s;
}

server {
    listen 80;
    server_name app.example.com;
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name app.example.com;
    
    ssl_certificate /etc/nginx/ssl/cert.pem;
    ssl_certificate_key /etc/nginx/ssl/key.pem;
    
    location / {
        proxy_pass http://raxol_backend;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

## Blue-Green Deployment

### Implementation Strategy

```elixir
defmodule MyApp.Deployment do
  use Raxol.Enterprise.BlueGreen
  
  def deploy(version) do
    # 1. Deploy to green environment
    deploy_green(version)
    
    # 2. Run health checks
    case health_check_green() do
      :ok ->
        # 3. Switch traffic
        switch_traffic(:green)
        
        # 4. Monitor for issues
        if monitor_deployment(minutes: 10) do
          # 5. Decommission blue
          decommission(:blue)
          {:ok, :deployed}
        else
          # Rollback on issues
          switch_traffic(:blue)
          {:error, :rollback}
        end
        
      :error ->
        {:error, :health_check_failed}
    end
  end
end
```

### Traffic Switching

```bash
#!/bin/bash
# switch_traffic.sh

ENVIRONMENT=$1
LOAD_BALANCER="lb.example.com"

if [ "$ENVIRONMENT" = "green" ]; then
    echo "Switching traffic to green environment..."
    curl -X PUT "http://$LOAD_BALANCER/api/config" \
         -d '{"backend": "green_servers"}'
else
    echo "Switching traffic to blue environment..."
    curl -X PUT "http://$LOAD_BALANCER/api/config" \
         -d '{"backend": "blue_servers"}'
fi
```

## Rollback Procedures

### Automated Rollback

```elixir
defmodule MyApp.Rollback do
  use Raxol.Enterprise.Deployment
  
  def auto_rollback do
    with {:error, metrics} <- check_deployment_health(),
         :ok <- verify_previous_version() do
      
      Logger.error("Deployment health check failed: #{inspect(metrics)}")
      
      # Capture current state
      capture_deployment_state()
      
      # Perform rollback
      case rollback_to_previous() do
        :ok ->
          notify_rollback_success()
          {:ok, :rolled_back}
          
        {:error, reason} ->
          trigger_emergency_response(reason)
          {:error, :rollback_failed}
      end
    end
  end
  
  defp check_deployment_health do
    metrics = [
      error_rate: get_error_rate(),
      response_time: get_response_time(),
      availability: get_availability()
    ]
    
    if deployment_healthy?(metrics) do
      {:ok, metrics}
    else
      {:error, metrics}
    end
  end
end
```

### Manual Rollback

```bash
#!/bin/bash
# rollback.sh

VERSION=$1

echo "Rolling back to version $VERSION..."

# Stop current deployment
kubectl scale deployment raxol-app --replicas=0

# Update image
kubectl set image deployment/raxol-app raxol=myregistry/raxol-app:$VERSION

# Scale back up
kubectl scale deployment raxol-app --replicas=3

# Wait for rollout
kubectl rollout status deployment/raxol-app

echo "Rollback complete"
```

## CI/CD Pipeline

### GitHub Actions

```yaml
name: Deploy

on:
  push:
    branches: [main]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: erlef/setup-beam@v1
        with:
          elixir-version: '1.14'
          otp-version: '25'
      - run: mix deps.get
      - run: mix test
      
  build:
    needs: test
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: docker/setup-buildx-action@v2
      - uses: docker/login-action@v2
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}
      - uses: docker/build-push-action@v4
        with:
          push: true
          tags: ghcr.io/${{ github.repository }}:${{ github.sha }}
          
  deploy:
    needs: build
    runs-on: ubuntu-latest
    steps:
      - uses: azure/setup-kubectl@v3
      - uses: azure/k8s-set-context@v3
        with:
          kubeconfig: ${{ secrets.KUBE_CONFIG }}
      - run: |
          kubectl set image deployment/raxol-app \
            raxol=ghcr.io/${{ github.repository }}:${{ github.sha }}
      - run: kubectl rollout status deployment/raxol-app
```

## Configuration Management

### Environment-Specific Config

```elixir
# config/runtime.exs
import Config

if config_env() == :prod do
  config :my_app,
    environment: System.get_env("ENVIRONMENT", "production"),
    
  config :my_app, MyApp.Repo,
    url: System.get_env("DATABASE_URL"),
    pool_size: String.to_integer(System.get_env("POOL_SIZE", "10")),
    
  config :my_app, MyAppWeb.Endpoint,
    url: [
      host: System.get_env("PHX_HOST"),
      port: 443,
      scheme: "https"
    ],
    http: [
      port: String.to_integer(System.get_env("PORT", "4000"))
    ],
    secret_key_base: System.get_env("SECRET_KEY_BASE")
end
```

### Secret Management

```elixir
defmodule MyApp.Secrets do
  use Raxol.Enterprise.Secrets
  
  # Vault integration
  secret :database_url, from: :vault, path: "secret/data/database"
  secret :api_key, from: :vault, path: "secret/data/external_api"
  
  # AWS Secrets Manager
  secret :smtp_password, from: :aws_secrets, name: "prod/smtp"
  
  # Environment variables with validation
  secret :secret_key_base, from: :env, 
    var: "SECRET_KEY_BASE",
    validate: &(byte_size(&1) >= 64)
end
```

## Monitoring Integration

### Deployment Metrics

```elixir
defmodule MyApp.DeploymentMetrics do
  use Raxol.Enterprise.Metrics
  
  def track_deployment(version) do
    emit(:deployment_started, %{version: version})
    
    # Track deployment stages
    with_timer :deployment_duration do
      track_stage(:build)
      track_stage(:test)
      track_stage(:deploy)
      track_stage(:verify)
    end
    
    emit(:deployment_completed, %{
      version: version,
      duration: get_timer(:deployment_duration)
    })
  end
end
```

## Best Practices

1. **Automate Everything**: CI/CD pipelines, testing, deployments
2. **Monitor Deployments**: Track metrics during and after deployment
3. **Practice Rollbacks**: Regularly test rollback procedures
4. **Use Health Checks**: Implement comprehensive health endpoints
5. **Version Everything**: Tag releases, track configurations
6. **Document Procedures**: Maintain runbooks for operations
7. **Security First**: Scan images, manage secrets properly

## Troubleshooting

### Common Issues

1. **Container Startup Failures**
   - Check logs: `kubectl logs -f pod-name`
   - Verify environment variables
   - Test health check endpoints

2. **Database Connection Issues**
   - Verify network connectivity
   - Check connection pool settings
   - Review database logs

3. **Memory Issues**
   - Monitor BEAM memory usage
   - Adjust container limits
   - Review memory-intensive operations

## Next Steps

- Configure [Monitoring](monitoring.md) for deployment tracking
- Implement [Security](security.md) best practices
- Plan [Scaling](scaling.md) strategies