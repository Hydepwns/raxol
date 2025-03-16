defmodule Raxol.Cloud do
  @moduledoc "Cloud integration system for Raxol applications."
  
  alias Raxol.Cloud.{Core, Config, StateManager}
  
  # Lifecycle functions
  def init(opts \\ []), do: Core.init(opts)
  def start(), do: Core.start()
  def stop(), do: Core.stop()
  def status(), do: Core.status()
  
  # Core operations
  def execute(fun, opts \\ []), do: Core.execute(fun, opts)
  
  # Monitoring operations (consolidated)
  def monitor(action, args \\ nil, opts \\ []) do
    case action do
      :metric when is_binary(args) -> Core.record_metric(args, opts[:value] || 1, opts)
      :error -> Core.record_error(args, opts)
      :health -> Core.run_health_check(opts)
      :alert when is_atom(args) -> Core.trigger_alert(args, opts[:data] || %{}, opts)
    end
  end
  
  # Configuration management (simplified)
  def config(action \\ :get, path \\ nil, value \\ nil) do
    case action do
      :get -> Config.get(section: path)
      :set -> Config.update(put_in_path(%{}, List.wrap(path), value))
      :reload -> Config.reload()
    end
  end
  
  # Service management functions (use macro in actual implementation)
  def discover(opts \\ []), do: Core.discover_services(opts)
  def register(opts), do: Core.register_service(opts)
  def deploy(opts), do: Core.deploy(opts)
  def scale(opts), do: Core.scale(opts)
  def connect(opts), do: Core.get_service_connection(opts)
  
  # Private helper for nested path updates
  defp put_in_path(map, [key], value), do: Map.put(map, key, value)
  defp put_in_path(map, [key|rest], value) do
    Map.put(map, key, put_in_path(Map.get(map, key, %{}), rest, value))
  end
end