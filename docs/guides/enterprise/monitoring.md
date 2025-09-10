# Monitoring & Observability

Comprehensive monitoring and observability features for Raxol applications in production environments.

## Overview

Raxol provides built-in telemetry and monitoring capabilities that integrate with popular observability platforms, enabling you to track performance, diagnose issues, and ensure reliability.

## Metrics Collection

### Built-in Metrics

Raxol automatically collects key metrics:

```elixir
# Automatically collected metrics
- terminal.sessions.active (gauge)
- terminal.sessions.created (counter)
- terminal.sessions.duration (histogram)
- terminal.commands.executed (counter)
- terminal.commands.duration (histogram)
- terminal.render.time (histogram)
- terminal.events.processed (counter)
- websocket.connections.active (gauge)
- websocket.messages.sent (counter)
- websocket.messages.received (counter)
```

### Custom Metrics

Define application-specific metrics:

```elixir
defmodule MyApp.Metrics do
  use Raxol.Enterprise.Telemetry
  
  def setup do
    # Counter
    counter(:user_actions, 
      description: "Total user actions",
      tags: [:action_type, :user_role]
    )
    
    # Histogram
    histogram(:query_duration,
      description: "Database query duration",
      unit: :millisecond,
      buckets: [10, 50, 100, 500, 1000]
    )
    
    # Gauge
    gauge(:queue_depth,
      description: "Current queue depth",
      unit: :item
    )
  end
  
  def track_action(action, user) do
    increment(:user_actions, 
      tags: [action_type: action, user_role: user.role]
    )
  end
  
  def track_query(duration) do
    record(:query_duration, duration)
  end
end
```

## Telemetry Backends

### Prometheus

```elixir
config :raxol, :telemetry,
  backend: :prometheus,
  prometheus: [
    port: 9090,
    path: "/metrics",
    format: :text,  # or :protobuf
    basic_auth: [
      username: "prometheus",
      password: {:system, "PROMETHEUS_PASSWORD"}
    ]
  ]
```

### StatsD

```elixir
config :raxol, :telemetry,
  backend: :statsd,
  statsd: [
    host: "statsd.monitoring.local",
    port: 8125,
    prefix: "raxol",
    tags: [
      environment: :production,
      region: "us-east-1"
    ]
  ]
```

### OpenTelemetry

```elixir
config :raxol, :telemetry,
  backend: :opentelemetry,
  opentelemetry: [
    endpoint: "https://otel-collector.local:4318",
    headers: [
      {"Authorization", "Bearer ${OTEL_TOKEN}"}
    ],
    resource: [
      service_name: "raxol-app",
      service_version: "1.0.0"
    ]
  ]
```

## Distributed Tracing

### Trace Context Propagation

```elixir
defmodule MyApp.TracedComponent do
  use Raxol.Enterprise.Tracing
  
  @trace span: "user_action"
  def handle_action(action, user) do
    with_span "validate_permissions", %{user_id: user.id} do
      validate_user_permissions(user, action)
    end
    
    with_span "execute_action", %{action: action} do
      result = execute(action)
      add_span_attribute(:result_size, byte_size(result))
      result
    end
  end
end
```

### Cross-Service Tracing

```elixir
defmodule MyApp.ServiceClient do
  use Raxol.Enterprise.Tracing.HTTP
  
  def call_external_service(data) do
    # Automatically propagates trace context
    traced_request(:post, "https://api.service.com/endpoint",
      body: data,
      headers: [{"Content-Type", "application/json"}]
    )
  end
end
```

## Health Checks

### Endpoint Configuration

```elixir
defmodule MyAppWeb.HealthCheck do
  use Raxol.Enterprise.HealthCheck
  
  # Liveness probe - is the app running?
  health_check :liveness, "/health/live" do
    check :memory_usage do
      memory = :erlang.memory(:total) / 1_024 / 1_024
      if memory < 1000 do
        {:ok, "Memory usage: #{round(memory)}MB"}
      else
        {:error, "High memory usage: #{round(memory)}MB"}
      end
    end
  end
  
  # Readiness probe - is the app ready to serve traffic?
  health_check :readiness, "/health/ready" do
    check :database do
      case Ecto.Adapters.SQL.query(Repo, "SELECT 1") do
        {:ok, _} -> {:ok, "Database connected"}
        {:error, _} -> {:error, "Database unavailable"}
      end
    end
    
    check :redis do
      case Redix.command(:redis, ["PING"]) do
        {:ok, "PONG"} -> {:ok, "Redis connected"}
        _ -> {:error, "Redis unavailable"}
      end
    end
  end
end
```

## Logging

### Structured Logging

```elixir
defmodule MyApp.Logger do
  use Raxol.Enterprise.Logger
  
  def log_user_action(user, action, metadata \\ %{}) do
    info("User action performed",
      user_id: user.id,
      username: user.username,
      action: action,
      ip_address: metadata[:ip],
      session_id: metadata[:session_id],
      timestamp: DateTime.utc_now()
    )
  end
  
  def log_error(error, context) do
    error("Application error",
      error: Exception.format(:error, error),
      context: context,
      stacktrace: Exception.format_stacktrace()
    )
  end
end
```

### Log Aggregation

```elixir
config :logger,
  backends: [
    :console,
    {Raxol.Enterprise.Logger.Backend, :json}
  ]

config :logger, :json,
  format: :json,
  metadata: [:request_id, :user_id, :session_id],
  destination: [
    {:file, "/var/log/raxol/app.log"},
    {:tcp, "logstash.local", 5514}
  ]
```

## Performance Monitoring

### Application Performance Monitoring (APM)

```elixir
defmodule MyApp.APM do
  use Raxol.Enterprise.APM
  
  # Automatically instrument functions
  @instrument timing: true, errors: true
  def process_request(request) do
    # Processing logic
  end
  
  # Manual instrumentation
  def complex_operation(data) do
    start_transaction("complex_operation")
    
    try do
      with_segment "data_validation" do
        validate(data)
      end
      
      result = with_segment "data_processing" do
        process(data)
      end
      
      end_transaction(:success)
      result
    rescue
      error ->
        end_transaction(:error, error)
        reraise error, __STACKTRACE__
    end
  end
end
```

### Performance Budgets

```elixir
config :raxol, :performance,
  budgets: [
    {~r/^terminal\.render/, max: 16},  # 60 FPS
    {~r/^api\./, max: 100},             # 100ms API response
    {~r/^database\./, max: 50}          # 50ms DB queries
  ],
  alerts: [
    channel: :slack,
    webhook: {:system, "SLACK_WEBHOOK_URL"}
  ]
```

## Alerting

### Alert Configuration

```elixir
defmodule MyApp.Alerts do
  use Raxol.Enterprise.Alerting
  
  alert :high_error_rate do
    description "Error rate exceeds threshold"
    
    metric :error_rate do
      query """
        rate(terminal_errors_total[5m]) > 0.05
      """
    end
    
    threshold :critical, value: 0.1
    threshold :warning, value: 0.05
    
    notify :pagerduty, severity: :critical
    notify :slack, severity: :warning
  end
  
  alert :memory_usage do
    description "High memory usage detected"
    
    metric :memory_percent do
      query """
        (beam_memory_bytes / beam_memory_limit_bytes) * 100
      """
    end
    
    threshold :critical, value: 90
    threshold :warning, value: 80
    
    notify :email, to: ["ops@company.com"]
  end
end
```

### Notification Channels

```elixir
config :raxol, :alerting,
  channels: [
    pagerduty: [
      api_key: {:system, "PAGERDUTY_API_KEY"},
      routing_key: "YOUR_ROUTING_KEY"
    ],
    slack: [
      webhook_url: {:system, "SLACK_WEBHOOK_URL"},
      channel: "#alerts",
      username: "Raxol Alerts"
    ],
    email: [
      adapter: Bamboo.SMTPAdapter,
      server: "smtp.company.com",
      port: 587,
      username: {:system, "SMTP_USERNAME"},
      password: {:system, "SMTP_PASSWORD"}
    ]
  ]
```

## Dashboards

### Grafana Integration

```json
{
  "dashboard": {
    "title": "Raxol Application Dashboard",
    "panels": [
      {
        "title": "Active Sessions",
        "targets": [{
          "expr": "terminal_sessions_active"
        }]
      },
      {
        "title": "Command Execution Time",
        "targets": [{
          "expr": "histogram_quantile(0.95, terminal_commands_duration_bucket)"
        }]
      },
      {
        "title": "Error Rate",
        "targets": [{
          "expr": "rate(terminal_errors_total[5m])"
        }]
      }
    ]
  }
}
```

### Real-Time Dashboard

```elixir
defmodule MyAppWeb.DashboardLive do
  use Phoenix.LiveView
  use Raxol.Enterprise.LiveDashboard
  
  def render(assigns) do
    ~H"""
    <.dashboard>
      <.metric_card title="Active Users" value={@active_users} />
      <.metric_card title="Commands/sec" value={@commands_per_sec} />
      <.metric_card title="Avg Response Time" value={@avg_response_time} unit="ms" />
      
      <.time_series_chart 
        title="System Metrics" 
        data={@metrics_data}
        series={[:cpu, :memory, :connections]} 
      />
      
      <.alert_list alerts={@active_alerts} />
    </.dashboard>
    """
  end
  
  def mount(_params, _session, socket) do
    if connected?(socket) do
      # Subscribe to real-time metrics
      subscribe_to_metrics()
      :timer.send_interval(1000, :update_metrics)
    end
    
    {:ok, assign(socket, initial_metrics())}
  end
end
```

## Best Practices

1. **Start with Basics**: Begin with basic metrics and expand as needed
2. **Use Sampling**: For high-volume metrics, use sampling to reduce overhead
3. **Set SLOs**: Define Service Level Objectives and monitor them
4. **Correlate Metrics**: Link metrics with logs and traces for debugging
5. **Automate Responses**: Set up automated remediation for common issues
6. **Review Regularly**: Regularly review and update monitoring configuration

## Troubleshooting

### Debug Telemetry

```elixir
# Enable debug mode
config :telemetry, :debug, true

# Test metric emission
Raxol.Enterprise.Telemetry.test_emit(:my_metric, 42)

# View active metrics
Raxol.Enterprise.Telemetry.list_metrics()
```

### Common Issues

1. **Missing Metrics**: Check metric registration and backend connectivity
2. **High Cardinality**: Review tags to avoid explosion of time series
3. **Performance Impact**: Use sampling for high-frequency metrics

## Next Steps

- Set up [Security](security.md) monitoring
- Configure [Deployment](deployment.md) with monitoring infrastructure
- Plan [Scaling](scaling.md) based on metrics