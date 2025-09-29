defmodule Raxol.Themes do
  @moduledoc """
  Theme management system for Raxol terminal.

  This module handles theme loading, application, and management for the
  terminal emulator. It supports dynamic theme switching and plugin-based
  theme customization.
  """

  use Raxol.Core.Behaviours.BaseManager

@behaviour Raxol.Core.Behaviours.BaseManager


  @doc """
  Applies a theme to the terminal.

  ## Parameters
  - `theme`: A theme map with the following structure:
    ```
    %{
      background: color,
      foreground: color,
      cursor: color,
      selection: color
    }
    ```

  Colors can be:
  - Atoms: `:default`, `:black`, `:red`, etc.
  - RGB tuples: `{255, 0, 0}`
  - RGBA tuples: `{255, 0, 0, 128}`

  ## Returns
  - `:ok` on success
  - `{:error, reason}` on failure
  """
  def apply_theme(theme) do
    GenServer.call(__MODULE__, {:apply_theme, theme})
  end

  @doc """
  Gets the currently active theme.

  ## Returns
  The current theme map or `nil` if no theme is active.
  """
  def get_current_theme do
    GenServer.call(__MODULE__, :get_current_theme)
  end

  @doc """
  Loads a theme from a file or predefined theme name.

  ## Parameters
  - `theme_identifier`: Either a file path or a predefined theme name

  ## Returns
  - `{:ok, theme}` on success
  - `{:error, reason}` on failure
  """
  def load_theme(theme_identifier) do
    GenServer.call(__MODULE__, {:load_theme, theme_identifier})
  end

  @doc """
  Lists all available themes.

  ## Returns
  A list of theme names that can be loaded.
  """
  def list_themes do
    GenServer.call(__MODULE__, :list_themes)
  end

  @doc """
  Registers a theme change callback.

  ## Parameters
  - `callback_module`: Module that implements `on_theme_change/1`
  - `callback_fun`: Function name to call (default: `:on_theme_change`)

  ## Returns
  - `:ok` on success
  """
  def register_theme_callback(callback_module, callback_fun \\ :on_theme_change) do
    GenServer.call(
      __MODULE__,
      {:register_callback, callback_module, callback_fun}
    )
  end

  # GenServer callbacks

  @impl true
  @impl true
  def init_manager(:ok) do
    default_theme = %{
      background: :default,
      foreground: :default,
      cursor: :default,
      selection: {128, 128, 128, 64}
    }

    state = %{
      current_theme: default_theme,
      callbacks: []
    }

    {:ok, state}
  end

  @impl true
  @impl true
  def handle_manager_call({:apply_theme, theme}, _from, state) do
    # Validate theme structure
    case validate_theme(theme) do
      :ok ->
        new_state = %{state | current_theme: theme}
        # Notify callbacks
        notify_theme_callbacks(theme, state.callbacks)
        {:reply, :ok, new_state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  @impl true
  def handle_manager_call(:get_current_theme, _from, state) do
    {:reply, state.current_theme, state}
  end

  @impl true
  @impl true
  def handle_manager_call({:load_theme, theme_identifier}, _from, state) do
    case load_theme_from_identifier(theme_identifier) do
      {:ok, theme} ->
        new_state = %{state | current_theme: theme}
        notify_theme_callbacks(theme, state.callbacks)
        {:reply, {:ok, theme}, new_state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  @impl true
  def handle_manager_call(:list_themes, _from, state) do
    themes = ["default", "dark", "light", "high_contrast"]
    {:reply, themes, state}
  end

  @impl true
  @impl true
  def handle_manager_call({:register_callback, module, fun}, _from, state) do
    callback = {module, fun}
    new_callbacks = [callback | state.callbacks]
    new_state = %{state | callbacks: new_callbacks}
    {:reply, :ok, new_state}
  end

  # Private helper functions

  defp validate_theme(theme) do
    required_keys = [:background, :foreground, :cursor]

    missing_keys =
      Enum.filter(required_keys, fn key -> not Map.has_key?(theme, key) end)

    case missing_keys do
      [] -> :ok
      keys -> {:error, "Missing required theme keys: #{inspect(keys)}"}
    end
  end

  defp load_theme_from_identifier("default") do
    {:ok,
     %{
       background: :default,
       foreground: :default,
       cursor: :default,
       selection: {128, 128, 128, 64}
     }}
  end

  defp load_theme_from_identifier("dark") do
    {:ok,
     %{
       background: {0, 0, 0},
       foreground: {255, 255, 255},
       cursor: {255, 255, 255},
       selection: {64, 64, 64, 128}
     }}
  end

  defp load_theme_from_identifier("light") do
    {:ok,
     %{
       background: {255, 255, 255},
       foreground: {0, 0, 0},
       cursor: {0, 0, 0},
       selection: {192, 192, 192, 128}
     }}
  end

  defp load_theme_from_identifier("high_contrast") do
    {:ok,
     %{
       background: {0, 0, 0},
       foreground: {255, 255, 255},
       cursor: {255, 255, 0},
       selection: {255, 255, 255, 128}
     }}
  end

  defp load_theme_from_identifier(path) when is_binary(path) do
    # Try to load from file
    case File.read(path) do
      {:ok, content} ->
        case Jason.decode(content) do
          {:ok, theme_data} ->
            theme = convert_theme_data(theme_data)
            validate_theme(theme)
            {:ok, theme}

          {:error, reason} ->
            {:error, "Failed to parse theme file: #{reason}"}
        end

      {:error, reason} ->
        {:error, "Failed to read theme file: #{reason}"}
    end
  end

  defp load_theme_from_identifier(other) do
    {:error, "Unknown theme identifier: #{inspect(other)}"}
  end

  defp convert_theme_data(data) do
    # Convert string keys to atoms and handle color formats
    data
    |> Enum.map(fn {k, v} ->
      key = if is_binary(k), do: String.to_atom(k), else: k
      value = convert_color_value(v)
      {key, value}
    end)
    |> Map.new()
  end

  defp convert_color_value(color) when is_binary(color) do
    # Handle hex colors, named colors, etc.
    cond do
      String.starts_with?(color, "#") ->
        parse_hex_color(color)

      true ->
        String.to_atom(color)
    end
  end

  defp convert_color_value(color) when is_list(color) do
    # Convert list to tuple for RGB/RGBA
    List.to_tuple(color)
  end

  defp convert_color_value(color), do: color

  defp parse_hex_color("#" <> hex) do
    case String.length(hex) do
      6 ->
        # RGB
        {r, _} = Integer.parse(String.slice(hex, 0, 2), 16)
        {g, _} = Integer.parse(String.slice(hex, 2, 2), 16)
        {b, _} = Integer.parse(String.slice(hex, 4, 2), 16)
        {r, g, b}

      8 ->
        # RGBA
        {r, _} = Integer.parse(String.slice(hex, 0, 2), 16)
        {g, _} = Integer.parse(String.slice(hex, 2, 2), 16)
        {b, _} = Integer.parse(String.slice(hex, 4, 2), 16)
        {a, _} = Integer.parse(String.slice(hex, 6, 2), 16)
        {r, g, b, a}

      _ ->
        :default
    end
  end

  defp notify_theme_callbacks(theme, callbacks) do
    Enum.each(callbacks, fn {module, fun} ->
      try do
        apply(module, fun, [theme])
      rescue
        # Ignore callback errors
        _error -> :ok
      end
    end)
  end
end
