defmodule Raxol.UI.Theming.PaletteRegistry do
  @moduledoc """
  Registry for custom color palettes used in the Raxol theming system.

  This module provides persistent storage and management of custom color palettes
  that can be used with the Colors.convert_to_palette/2 function.
  """

  import Raxol.Guards
  use GenServer
  require Logger

  @type palette_name :: atom()
  @type color_index :: 0..255
  @type color_rgb :: {0..255, 0..255, 0..255}
  @type palette_color :: {color_index, color_rgb}
  @type palette :: [palette_color()]

  # Client API

  @doc """
  Starts the palette registry.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Registers a custom color palette.

  ## Examples

      iex> register(:my_palette, [{0, {0, 0, 0}}, {1, {255, 255, 255}}])
      :ok
  """
  def register(name, colors) when atom?(name) and list?(colors) do
    GenServer.call(__MODULE__, {:register, name, colors})
  end

  @doc """
  Unregisters a custom color palette.

  ## Examples

      iex> unregister(:my_palette)
      :ok
  """
  def unregister(name) when atom?(name) do
    GenServer.call(__MODULE__, {:unregister, name})
  end

  @doc """
  Gets a custom palette by name.

  ## Examples

      iex> get(:my_palette)
      {:ok, [{0, {0, 0, 0}}, {1, {255, 255, 255}}]}

      iex> get(:nonexistent)
      {:error, :not_found}
  """
  def get(name) when atom?(name) do
    GenServer.call(__MODULE__, {:get, name})
  end

  @doc """
  Lists all registered custom palettes.

  ## Examples

      iex> list()
      [:my_palette, :another_palette]
  """
  def list do
    GenServer.call(__MODULE__, :list)
  end

  @doc """
  Checks if a palette exists.

  ## Examples

      iex> exists?(:my_palette)
      true

      iex> exists?(:nonexistent)
      false
  """
  def exists?(name) when atom?(name) do
    GenServer.call(__MODULE__, {:exists?, name})
  end

  @doc """
  Updates an existing palette.

  ## Examples

      iex> update(:my_palette, [{0, {0, 0, 0}}, {1, {128, 128, 128}}])
      :ok
  """
  def update(name, colors) when atom?(name) and list?(colors) do
    GenServer.call(__MODULE__, {:update, name, colors})
  end

  # Server Callbacks

  @impl true
  def init(opts) do
    # Load palettes from persistent storage if available
    palettes = load_palettes_from_storage()

    state = %{
      palettes: palettes,
      storage_path: Keyword.get(opts, :storage_path, "priv/palettes.json")
    }

    Logger.info("Palette registry started with #{map_size(palettes)} palettes")
    {:ok, state}
  end

  @impl true
  def handle_call({:register, name, colors}, _from, state) do
    case validate_palette(colors) do
      :ok ->
        new_palettes = Map.put(state.palettes, name, colors)
        new_state = %{state | palettes: new_palettes}
        save_palettes_to_storage(new_state.palettes, state.storage_path)
        Logger.info("Registered palette: #{name}")
        {:reply, :ok, new_state}

      {:error, reason} ->
        Logger.warning("Failed to register palette #{name}: #{inspect(reason)}")
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:unregister, name}, _from, state) do
    case Map.get(state.palettes, name) do
      nil ->
        {:reply, {:error, :not_found}, state}

      _palette ->
        new_palettes = Map.delete(state.palettes, name)
        new_state = %{state | palettes: new_palettes}
        save_palettes_to_storage(new_state.palettes, state.storage_path)
        Logger.info("Unregistered palette: #{name}")
        {:reply, :ok, new_state}
    end
  end

  @impl true
  def handle_call({:get, name}, _from, state) do
    case Map.get(state.palettes, name) do
      nil ->
        {:reply, {:error, :not_found}, state}

      palette ->
        {:reply, {:ok, palette}, state}
    end
  end

  @impl true
  def handle_call(:list, _from, state) do
    palette_names = Map.keys(state.palettes)
    {:reply, palette_names, state}
  end

  @impl true
  def handle_call({:exists?, name}, _from, state) do
    exists = Map.has_key?(state.palettes, name)
    {:reply, exists, state}
  end

  @impl true
  def handle_call({:update, name, colors}, _from, state) do
    case Map.get(state.palettes, name) do
      nil ->
        {:reply, {:error, :not_found}, state}

      _existing ->
        case validate_palette(colors) do
          :ok ->
            new_palettes = Map.put(state.palettes, name, colors)
            new_state = %{state | palettes: new_palettes}
            save_palettes_to_storage(new_state.palettes, state.storage_path)
            Logger.info("Updated palette: #{name}")
            {:reply, :ok, new_state}

          {:error, reason} ->
            Logger.warning(
              "Failed to update palette #{name}: #{inspect(reason)}"
            )

            {:reply, {:error, reason}, state}
        end
    end
  end

  # Private Functions

  defp validate_palette(colors) do
    if Enum.all?(colors, &valid_palette_color?/1) do
      :ok
    else
      {:error, :invalid_color_format}
    end
  end

  defp valid_palette_color?({index, {r, g, b}})
       when is_integer(index) and
              r in 0..255 and
              g in 0..255 and
              b in 0..255 do
    true
  end

  defp valid_palette_color?(_), do: false

  defp load_palettes_from_storage do
    # This would load from a JSON file or database
    # For now, return empty map - implement persistence as needed
    %{}
  end

  defp save_palettes_to_storage(palettes, storage_path) do
    # This would save to a JSON file or database
    # For now, just log - implement persistence as needed
    Logger.debug("Would save #{map_size(palettes)} palettes to #{storage_path}")
    :ok
  end
end
