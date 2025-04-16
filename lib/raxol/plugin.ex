defmodule Raxol.Plugin do
  @moduledoc """
  Defines the behavior for Raxol plugins.
  This module provides a set of callbacks that plugins must implement.
  """

  defmacro __using__(_opts) do
    quote do
      @behaviour Raxol.Plugin

      @impl true
      def init(opts), do: {:ok, opts}

      @impl true
      def handle_event(_event, state), do: {:ok, state}

      @impl true
      def handle_input(_input, state), do: {:ok, state}

      @impl true
      def handle_output(_output, state), do: {:ok, state}

      @impl true
      def handle_mouse(_event, state, _emulator_state), do: {:ok, state}

      @impl true
      def handle_resize(_width, _height, state), do: {:ok, state}

      @impl true
      def cleanup(_state), do: :ok

      @impl true
      def get_dependencies, do: []

      @impl true
      def get_api_version, do: "1.0.0"

      defoverridable init: 1,
                     handle_event: 2,
                     handle_input: 2,
                     handle_output: 2,
                     handle_mouse: 3,
                     handle_resize: 3,
                     cleanup: 1,
                     get_dependencies: 0,
                     get_api_version: 0
    end
  end

  @doc """
  Initializes the plugin with the given options.
  """
  @callback init(opts :: map()) ::
              {:ok, state :: term()} | {:error, reason :: String.t()}

  @doc """
  Handles a plugin event.
  """
  @callback handle_event(event :: term(), state :: term()) ::
              {:ok, state :: term()} | {:error, reason :: String.t()}

  @doc """
  Handles input from the terminal.
  """
  @callback handle_input(input :: String.t(), state :: term()) ::
              {:ok, state :: term()} | {:error, reason :: String.t()}

  @doc """
  Handles output to the terminal.
  """
  @callback handle_output(output :: String.t(), state :: term()) ::
              {:ok, state :: term()} | {:error, reason :: String.t()}

  @doc """
  Handles mouse events. Requires the emulator state for context.
  """
  @callback handle_mouse(
              event :: term(),
              state :: term(),
              emulator_state :: term()
            ) ::
              {:ok, state :: term()} | {:error, reason :: String.t()}

  @doc """
  Handles terminal resize events.
  """
  @callback handle_resize(
              width :: non_neg_integer(),
              height :: non_neg_integer(),
              state :: term()
            ) :: {:ok, state :: term()} | {:error, reason :: String.t()}

  @doc """
  Cleans up any resources used by the plugin.
  """
  @callback cleanup(state :: term()) :: :ok | {:error, reason :: String.t()}

  @doc """
  Returns a list of plugin dependencies.
  """
  @callback get_dependencies() :: list(map())

  @doc """
  Returns the plugin's API version.
  """
  @callback get_api_version() :: String.t()
end
