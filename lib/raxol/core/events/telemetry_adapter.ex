defmodule Raxol.Core.Events.TelemetryAdapter do
  @moduledoc """
  Adapter to migrate from EventManager to :telemetry.

  This module provides a compatibility layer to gradually migrate the event system
  from the custom EventManager to the standard :telemetry library.
  """

  @doc """
  Dispatches an event using telemetry.

  Converts EventManager dispatch calls to telemetry execute calls.
  """
  def dispatch(event_name, data \\ %{})
      when is_atom(event_name) or is_tuple(event_name) do
    telemetry_event = normalize_event_name(event_name)
    measurements = extract_measurements(data)
    metadata = extract_metadata(data)

    :telemetry.execute(telemetry_event, measurements, metadata)
    :ok
  end

  @doc """
  Registers a handler using telemetry.

  Converts EventManager handler registration to telemetry attach.
  """
  def register_handler(handler_id, event_pattern, handler_fun, config \\ []) do
    telemetry_events = pattern_to_telemetry_events(event_pattern)

    :telemetry.attach_many(
      handler_id,
      telemetry_events,
      handler_fun,
      config
    )
  end

  @doc """
  Unregisters a handler using telemetry.
  """
  def unregister_handler(handler_id) do
    :telemetry.detach(handler_id)
  end

  # Private functions

  @spec normalize_event_name(String.t() | atom()) :: any()
  defp normalize_event_name(event_name) when is_atom(event_name) do
    [:raxol, :events, event_name]
  end

  @spec normalize_event_name(any()) :: any()
  defp normalize_event_name({category, event})
       when is_atom(category) and is_atom(event) do
    [:raxol, :events, category, event]
  end

  @spec normalize_event_name(String.t() | atom()) :: any()
  defp normalize_event_name(event_name) when is_tuple(event_name) do
    [:raxol, :events | Tuple.to_list(event_name)]
  end

  @spec extract_measurements(any()) :: any()
  defp extract_measurements(%{measurements: measurements}), do: measurements
  @spec extract_measurements(any()) :: any()
  defp extract_measurements(%{value: value}), do: %{value: value}
  @spec extract_measurements(any()) :: any()
  defp extract_measurements(%{count: count}), do: %{count: count}
  @spec extract_measurements(any()) :: any()
  defp extract_measurements(%{duration: duration}), do: %{duration: duration}
  @spec extract_measurements(any()) :: any()
  defp extract_measurements(_), do: %{}

  @spec extract_metadata(any()) :: any()
  defp extract_metadata(%{metadata: metadata}), do: metadata

  @spec extract_metadata(any()) :: any()
  defp extract_metadata(data) when is_map(data) do
    data
    |> Map.delete(:measurements)
    |> Map.delete(:value)
    |> Map.delete(:count)
    |> Map.delete(:duration)
  end

  @spec extract_metadata(any()) :: any()
  defp extract_metadata(_), do: %{}

  @spec pattern_to_telemetry_events(any()) :: any()
  defp pattern_to_telemetry_events(:all), do: [[:raxol, :events, :_]]

  @spec pattern_to_telemetry_events(any()) :: any()
  defp pattern_to_telemetry_events(pattern) when is_atom(pattern) do
    [[:raxol, :events, pattern]]
  end

  @spec pattern_to_telemetry_events(any()) :: any()
  defp pattern_to_telemetry_events(patterns) when is_list(patterns) do
    Enum.map(patterns, fn pattern ->
      [:raxol, :events | List.wrap(pattern)]
    end)
  end

  @spec pattern_to_telemetry_events(any()) :: any()
  defp pattern_to_telemetry_events(pattern), do: [[:raxol, :events, pattern]]
end
