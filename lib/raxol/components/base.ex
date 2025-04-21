defmodule Raxol.Components.Base do
  @moduledoc """
  Provides base functionality and utilities for Raxol components.

  This module contains shared functionality used across different components,
  including common validation, styling, and event handling patterns.
  """

  use Raxol.Component

  alias Raxol.Core.Events.Event
  alias Raxol.Style

  @type state :: map()

  @doc """
  Validates component props against a schema.

  ## Example

      def validate_props(props) do
        Base.validate_props(props, %{
          required: [:label],
          optional: [:style, :disabled],
          types: %{
            label: :string,
            style: {:one_of, [:primary, :secondary, :danger]},
            disabled: :boolean
          }
        })
      end
  """
  def validate_props(props, schema) do
    with :ok <- validate_required(props, schema[:required] || []),
         :ok <- validate_types(props, schema[:types] || %{}) do
      :ok
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Creates a base style for components with common properties.
  """
  def base_style(opts \\ []) do
    Style.new(
      padding: Keyword.get(opts, :padding, [1, 2]),
      margin: Keyword.get(opts, :margin, [0, 0]),
      border: Keyword.get(opts, :border, :none),
      width: Keyword.get(opts, :width, :auto),
      height: Keyword.get(opts, :height, :auto)
    )
  end

  @doc """
  Handles common events like focus, blur, and keyboard navigation.
  """
  def handle_common_events(%Event{type: :focus} = _event, state) do
    {Map.put(state, :focused, true), []}
  end

  def handle_common_events(%Event{type: :blur} = _event, state) do
    {Map.put(state, :focused, false), []}
  end

  def handle_common_events(
        %Event{type: :key, data: %{key: key}} = _event,
        state
      ) do
    case key do
      :tab -> {state, [{:focus_next, state.focus_key}]}
      {:shift, :tab} -> {state, [{:focus_previous, state.focus_key}]}
      _ -> {state, []}
    end
  end

  def handle_common_events(_event, state), do: {state, []}

  # Private functions

  defp validate_required(props, required) do
    missing = Enum.filter(required, &(not Map.has_key?(props, &1)))

    if Enum.empty?(missing) do
      :ok
    else
      {:error, "Missing required props: #{Enum.join(missing, ", ")}"}
    end
  end

  defp validate_types(props, types) do
    Enum.reduce_while(props, :ok, fn {key, value}, :ok ->
      case validate_type(value, types[key]) do
        :ok ->
          {:cont, :ok}

        {:error, reason} ->
          {:halt, {:error, "Invalid type for #{key}: #{reason}"}}
      end
    end)
  end

  defp validate_type(_value, nil), do: :ok
  defp validate_type(value, :string) when is_binary(value), do: :ok
  defp validate_type(value, :boolean) when is_boolean(value), do: :ok
  defp validate_type(value, :integer) when is_integer(value), do: :ok
  defp validate_type(value, :atom) when is_atom(value), do: :ok

  defp validate_type(value, {:one_of, options}),
    do:
      if(value in options,
        do: :ok,
        else:
          {:error, "expected one of #{inspect(options)}, got #{inspect(value)}"}
      )

  defp validate_type(value, type),
    do: {:error, "expected #{inspect(type)}, got #{inspect(value)}"}
end
