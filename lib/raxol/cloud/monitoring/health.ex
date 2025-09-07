# Health implementation for monitoring
defmodule Raxol.Cloud.Monitoring.Health do
  @moduledoc false

  def init(config) do
    health_state = %{
      status: :unknown,
      last_check: nil,
      components: %{},
      config: config
    }

    Raxol.Cloud.Monitoring.Server.init_health(health_state)
    :ok
  end

  def check(opts \\ []) do
    opts = normalize_opts(opts)
    health_state = get_health_state()

    components_to_check =
      Keyword.get(opts, :components, [:system, :application, :connections])

    timeout = Keyword.get(opts, :timeout, 5000)

    component_results =
      components_to_check
      |> Enum.map(fn component ->
        {component, check_component(component, timeout)}
      end)
      |> Enum.into(%{})

    status = determine_overall_status(component_results)

    updated_health_state = %{
      health_state
      | status: status,
        last_check: DateTime.utc_now(),
        components: Map.merge(health_state.components, component_results)
    }

    Raxol.Cloud.Monitoring.Server.update_health(updated_health_state)

    %{
      status: status,
      components: component_results,
      timestamp: updated_health_state.last_check
    }
  end

  def last_check_time() do
    health_state = get_health_state()
    health_state.last_check
  end

  defp get_health_state() do
    Raxol.Cloud.Monitoring.Server.get_health_status() ||
      %{status: :unknown, last_check: nil, components: %{}, config: %{}}
  end

  defp check_component(:system, _timeout) do
    :ok
  end

  defp check_component(:application, _timeout) do
    :healthy
  end

  defp check_component(:connections, _timeout) do
    :healthy
  end

  defp check_component(_, _) do
    :unknown
  end

  defp normalize_opts(opts) when is_map(opts), do: Enum.into(opts, [])
  defp normalize_opts(opts), do: opts

  # Helper function for pattern matching instead of if statement
  defp determine_overall_status(component_results) do
    has_unhealthy =
      Enum.any?(component_results, fn {_, status} -> status == :unhealthy end)

    get_status_from_health_check(has_unhealthy)
  end

  defp get_status_from_health_check(true), do: :unhealthy
  defp get_status_from_health_check(false), do: :healthy
end
