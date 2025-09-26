#!/usr/bin/env elixir

# Example script demonstrating the Raxol Cloud integration system
# This script shows how to initialize and use the cloud features

# Ensure Raxol is loaded
Code.require_file("../lib/raxol.ex")

IO.puts("Raxol Cloud Integration Example")
IO.puts("==============================")
IO.puts("")

# Initialize the cloud system
IO.puts("Initializing cloud system...")

{status, result} =
  Raxol.Cloud.init(
    edge: [mode: :auto, sync_interval: 30000],
    monitoring: [active: true, backends: [:prometheus]],
    providers: [:aws]
  )

case status do
  :ok ->
    IO.puts("[OK] Cloud system initialized successfully")

  :error ->
    IO.puts("[FAIL] Failed to initialize cloud system: #{inspect(result)}")
    System.halt(1)
end

edge_config = Raxol.Cloud.config(:get, :edge)

# Update configuration
{status, result} = Raxol.Cloud.config(:set, [:edge, :mode], :hybrid)

case status do
  :ok ->
    IO.puts("[OK] Configuration updated successfully")

  :error ->
    IO.puts("[FAIL] Failed to update configuration: #{inspect(result)}")
end

Raxol.Cloud.status()

Raxol.Cloud.monitor(:metric, "example.counter",
  value: 1,
  tags: ["example:true"]
)

Raxol.Cloud.monitor(:metric, "example.gauge",
  value: 42.5,
  tags: ["example:true"]
)

Raxol.Cloud.monitor(:metric, "example.timer",
  value: 123.45,
  tags: ["example:true", "operation:test"]
)

IO.puts("[OK] Metrics recorded")
IO.puts("")

# Record an error
IO.puts("Recording an error...")
error = %RuntimeError{message: "This is a test error"}

Raxol.Cloud.monitor(:error, error,
  context: %{test: true},
  severity: :warning,
  tags: ["example:true"]
)

IO.puts("[OK] Error recorded")
IO.puts("")

# Run a health check
IO.puts("Running health check...")
{status, result} = Raxol.Cloud.monitor(:health)
IO.puts("Health check result: #{inspect(result)}")
IO.puts("")

# Execute a function at the edge or in the cloud
IO.puts("Executing a function...")

{status, result} =
  Raxol.Cloud.execute(
    fn ->
      # Simulate some work
      Process.sleep(100)
      {:ok, %{data: "test", timestamp: DateTime.utc_now()}}
    end,
    priority: :speed
  )

case status do
  :ok ->
    {location, data} = result
    IO.puts("[OK] Function executed successfully at #{location}")

  :error ->
    IO.puts("[FAIL] Function execution failed: #{inspect(result)}")
end

IO.puts("")

# Discover services
IO.puts("Discovering services...")
{status, services} = Raxol.Cloud.discover(type: :database)

case status do
  :ok ->
    IO.puts("[OK] Services discovered:")

    Enum.each(services, fn service ->
      IO.puts("  - #{service.name} (#{service.type}): #{service.endpoint}")
    end)

  :error ->
    IO.puts("[FAIL] Service discovery failed: #{inspect(services)}")
end

IO.puts("")

# Register a service
IO.puts("Registering a service...")

{status, result} =
  Raxol.Cloud.register(
    name: "example-service",
    type: :api,
    endpoint: "example-service.local:8080",
    health_check_path: "/health"
  )

case status do
  :ok ->
    IO.puts("[OK] Service registered: #{result.registration_id}")

  :error ->
    IO.puts("[FAIL] Service registration failed: #{inspect(result)}")
end

IO.puts("")

# Deploy a component
IO.puts("Deploying a component...")

{status, result} =
  Raxol.Cloud.deploy(
    component: :example_component,
    version: "1.0.0",
    environment: :development,
    strategy: :blue_green
  )

case status do
  :ok ->
    IO.puts("[OK] Deployment started: #{result.deployment_id}")

  :error ->
    IO.puts("[FAIL] Deployment failed: #{inspect(result)}")
end

IO.puts("")

# Scale a service
IO.puts("Scaling a service...")

{status, result} =
  Raxol.Cloud.scale(
    service: "example-service",
    min: 2,
    max: 5,
    metrics: [
      %{name: "cpu", target: 70},
      %{name: "requests", target: 1000}
    ]
  )

case status do
  :ok ->
    IO.puts(
      "[OK] Scaling initiated: #{result.service} from #{result.current} to #{result.target} instances"
    )

  :error ->
    IO.puts("[FAIL] Scaling failed: #{inspect(result)}")
end

IO.puts("")

# Get a service connection
IO.puts("Getting a service connection...")

{status, result} =
  Raxol.Cloud.connect(
    service: :storage,
    provider: :aws,
    region: "us-west-2"
  )

case status do
  :ok ->
    IO.puts("[OK] Service connection established: #{result.endpoint}")

  :error ->
    IO.puts("[FAIL] Service connection failed: #{inspect(result)}")
end

IO.puts("")

# Trigger an alert
IO.puts("Triggering an alert...")

Raxol.Cloud.monitor(:alert, :example_alert,
  data: %{
    message: "This is a test alert",
    value: 0.95,
    threshold: 0.9
  },
  severity: :warning
)

IO.puts("[OK] Alert triggered")
IO.puts("")

# Stop the cloud system
IO.puts("Stopping cloud system...")
Raxol.Cloud.stop()
IO.puts("[OK] Cloud system stopped")
IO.puts("")

IO.puts("Example completed successfully!")
