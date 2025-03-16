# Raxol Cloud Integration System

The Raxol Cloud Integration System provides a comprehensive yet concise set of tools for integrating Raxol applications with cloud services.

## Features

- **Edge Computing**: Run code at the edge or in the cloud
- **Monitoring**: Track metrics, errors, and system health
- **Multi-Cloud Support**: Integrate with popular cloud providers
- **Service Discovery**: Register and discover services
- **Configuration Management**: Centralized configuration

## Modules

- `Raxol.Cloud`: Main API entry point (concise user interface)
- `Raxol.Cloud.Core`: Core integration functionality
- `Raxol.Cloud.Config`: Configuration management
- `Raxol.Cloud.StateManager`: State management via GenServer

## Getting Started

Initialize the cloud system:

```elixir
Raxol.Cloud.init(
  edge: [mode: :auto, sync_interval: 30000],
  monitoring: [active: true, backends: [:prometheus]],
  providers: [:aws]
)
```

## Core Functions

Execute code at edge or cloud:

```elixir
# Execute code based on optimal conditions
Raxol.Cloud.execute(fn -> perform_calculation(data) end, priority: :speed)
```

## Monitor Functions

The unified monitoring API:

```elixir
# Record a metric
Raxol.Cloud.monitor(:metric, "response_time", value: 123, tags: ["api"])

# Record an error
Raxol.Cloud.monitor(:error, exception, severity: :warning)

# Run health check
Raxol.Cloud.monitor(:health)

# Trigger alert
Raxol.Cloud.monitor(:alert, :high_cpu_usage, 
  data: %{value: 0.95}, 
  severity: :critical
)
```

## Config Functions

Manage configuration with a simple API:

```elixir
# Get configuration
edge_config = Raxol.Cloud.config(:get, :edge)

# Update configuration
Raxol.Cloud.config(:set, [:edge, :mode], :hybrid)

# Reload configuration
Raxol.Cloud.config(:reload)
```

## Service Functions

Simplified service management:

```elixir
# Discover services
Raxol.Cloud.discover(type: :database)

# Register a service
Raxol.Cloud.register(
  name: "my-service",
  type: :api,
  endpoint: "my-service.example.com:8080"
)

# Deploy a component
Raxol.Cloud.deploy(
  component: :api_service,
  version: "1.2.3",
  environment: :production
)

# Scale a service
Raxol.Cloud.scale(
  service: "api-server",
  min: 2,
  max: 10
)

# Connect to a service
Raxol.Cloud.connect(
  service: :storage,
  provider: :aws
)
```

## Example

See the `examples/cloud_integration.exs` script for a complete example of using the cloud integration system.

## Environment Variables

Configuration via environment variables:

- `RAXOL_CLOUD_EDGE_MODE=hybrid` - Edge computing mode
- `RAXOL_CLOUD_MONITORING_ACTIVE=true` - Activate monitoring
- `RAXOL_CLOUD_PROVIDERS_AWS_ENABLED=true` - Enable AWS
- `RAXOL_CLOUD_PROVIDERS_AWS_REGION=us-west-2` - AWS region

## Configuration File

Sample configuration (config/cloud.json):

```json
{
  "edge": {
    "mode": "auto",
    "sync_interval": 60000
  },
  "monitoring": {
    "active": true,
    "metrics_interval": 10000,
    "backends": ["prometheus"]
  },
  "providers": {
    "aws": {
      "enabled": true,
      "region": "us-west-2"
    }
  }
}
```
