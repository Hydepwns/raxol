defmodule Raxol.Terminal.Theme.UnifiedTheme do
  @moduledoc """
  Unified theme system for the Raxol terminal emulator.
  Handles theme management, preview, switching, and customization.
  """

  use GenServer
  require Logger

  # Types
  @type theme_id :: String.t()
  @type theme_state :: %{
          id: theme_id(),
          name: String.t(),
          version: String.t(),
          description: String.t(),
          author: String.t(),
          colors: map(),
          font: map(),
          cursor: map(),
          padding: map(),
          status: :active | :inactive | :error,
          error: String.t() | nil
        }

  # Client API
  def start_link(opts \\ []) do
    opts = case is_map(opts) do
      true -> Enum.into(opts, [])
      false -> opts
    end
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Loads a theme from a file or directory.
  """
  def load_theme(path, opts \\ []) do
    GenServer.call(__MODULE__, {:load_theme, path, opts})
  end

  @doc """
  Unloads a theme by ID.
  """
  def unload_theme(theme_id) do
    GenServer.call(__MODULE__, {:unload_theme, theme_id})
  end

  @doc """
  Gets the state of a theme.
  """
  def get_theme_state(theme_id) do
    GenServer.call(__MODULE__, {:get_theme_state, theme_id})
  end

  @doc """
  Gets all loaded themes.
  """
  def get_themes(opts \\ []) do
    GenServer.call(__MODULE__, {:get_themes, opts})
  end

  @doc """
  Updates a theme's configuration.
  """
  def update_theme_config(theme_id, config) do
    GenServer.call(__MODULE__, {:update_theme_config, theme_id, config})
  end

  @doc """
  Applies a theme to the terminal.
  """
  def apply_theme(theme_id) do
    GenServer.call(__MODULE__, {:apply_theme, theme_id})
  end

  @doc """
  Previews a theme without applying it.
  """
  def preview_theme(theme_id) do
    GenServer.call(__MODULE__, {:preview_theme, theme_id})
  end

  @doc """
  Exports a theme to a file.
  """
  def export_theme(theme_id, path) do
    GenServer.call(__MODULE__, {:export_theme, theme_id, path})
  end

  @doc """
  Imports a theme from a file.
  """
  def import_theme(path) do
    GenServer.call(__MODULE__, {:import_theme, path})
  end

  # Server Callbacks
  def init(opts) when is_list(opts) do
    # Convert keyword list to map
    opts_map = Map.new(opts)
    init(opts_map)
  end

  def init(opts) when is_map(opts) do
    state = %{
      themes: %{},
      theme_paths: Map.get(opts, :theme_paths, []),
      auto_load: Map.get(opts, :auto_load, true),
      current_theme: nil,
      preview_theme: nil,
      theme_config: Map.get(opts, :theme_config, %{})
    }

    case state.auto_load do
      true -> load_themes_from_paths(state.theme_paths)
      false -> :ok
    end

    {:ok, state}
  end

  def handle_call({:load_theme, path, opts}, _from, state) do
    case do_load_theme(path, opts, state) do
      {:ok, theme_id, theme_state} ->
        new_state = put_in(state.themes[theme_id], theme_state)
        {:reply, {:ok, theme_id}, new_state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  def handle_call({:unload_theme, theme_id}, _from, state) do
    case do_unload_theme(theme_id, state) do
      {:ok, new_state} ->
        {:reply, :ok, new_state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  def handle_call({:get_theme_state, theme_id}, _from, state) do
    case Map.get(state.themes, theme_id) do
      nil -> {:reply, {:error, :theme_not_found}, state}
      theme_state -> {:reply, {:ok, theme_state}, state}
    end
  end

  def handle_call({:get_themes, opts}, _from, state) do
    themes = filter_themes(state.themes, opts)
    {:reply, {:ok, themes}, state}
  end

  def handle_call({:update_theme_config, theme_id, config}, _from, state) do
    case do_update_theme_config(theme_id, config, state) do
      {:ok, new_state} ->
        {:reply, :ok, new_state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  def handle_call({:apply_theme, theme_id}, _from, state) do
    case do_apply_theme(theme_id, state) do
      {:ok, new_state} ->
        {:reply, :ok, new_state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  def handle_call({:preview_theme, theme_id}, _from, state) do
    case do_preview_theme(theme_id, state) do
      {:ok, new_state} ->
        {:reply, :ok, new_state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  def handle_call({:export_theme, theme_id, path}, _from, state) do
    case do_export_theme(theme_id, path, state) do
      {:ok, new_state} ->
        {:reply, :ok, new_state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  def handle_call({:import_theme, path}, _from, state) do
    case do_import_theme(path, state) do
      {:ok, theme_id, new_state} ->
        {:reply, {:ok, theme_id}, new_state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  # Private Functions
  defp do_load_theme(path, opts, _state) do
    with {:ok, theme_id} <- generate_theme_id(path),
         {:ok, theme_state} <- load_theme_state(path, opts),
         :ok <- validate_theme(theme_state) do
      {:ok, theme_id, theme_state}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp do_unload_theme(theme_id, state) do
    case Map.get(state.themes, theme_id) do
      nil ->
        {:error, :theme_not_found}

      theme_state ->
        case cleanup_theme(theme_state) do
          :ok ->
            new_state = update_in(state.themes, &Map.delete(&1, theme_id))
            {:ok, new_state}
        end
    end
  end

  defp do_update_theme_config(theme_id, config, state) do
    case Map.get(state.themes, theme_id) do
      nil ->
        {:error, :theme_not_found}

      theme_state ->
        case validate_theme_config(config) do
          :ok ->
            new_theme_state = put_in(theme_state.config, config)
            new_state = put_in(state.themes[theme_id], new_theme_state)
            {:ok, new_state}

          {:error, reason} ->
            {:error, reason}
        end
    end
  end

  defp do_apply_theme(theme_id, state) do
    case Map.get(state.themes, theme_id) do
      nil ->
        {:error, :theme_not_found}

      theme_state ->
        case theme_state.status do
          :active ->
            new_state = %{state | current_theme: theme_id}
            {:ok, new_state}

          :inactive ->
            {:error, :theme_inactive}

          :error ->
            {:error, :theme_error}
        end
    end
  end

  defp do_preview_theme(theme_id, state) do
    case Map.get(state.themes, theme_id) do
      nil ->
        {:error, :theme_not_found}

      theme_state ->
        case theme_state.status do
          :active ->
            new_state = %{state | preview_theme: theme_id}
            {:ok, new_state}

          :inactive ->
            {:error, :theme_inactive}

          :error ->
            {:error, :theme_error}
        end
    end
  end

  defp do_export_theme(theme_id, path, state) do
    case Map.get(state.themes, theme_id) do
      nil ->
        {:error, :theme_not_found}

      theme_state ->
        case export_theme_to_file(theme_state, path) do
          :ok -> {:ok, state}
          {:error, reason} -> {:error, reason}
        end
    end
  end

  defp do_import_theme(path, state) do
    case import_theme_from_file(path) do
      {:ok, theme_state} ->
        theme_id = generate_theme_id(path)
        new_state = put_in(state.themes[theme_id], theme_state)
        {:ok, theme_id, new_state}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp generate_theme_id(path) do
    {:ok, :crypto.hash(:sha256, path) |> Base.encode16()}
  end

  defp load_theme_state(path, _opts) do
    parse_theme_file(path)
  end

  defp validate_theme(theme_state) do
    required_fields = [
      :name,
      :version,
      :description,
      :author,
      :colors,
      :font,
      :cursor,
      :padding
    ]

    case Enum.all?(required_fields, fn field ->
           Map.has_key?(theme_state, field) and
             Map.get(theme_state, field) != nil
         end) do
      true -> :ok
      false -> {:error, :invalid_theme_format}
    end
  end

  defp validate_theme_config(config) do
    case is_map(config) do
      true -> :ok
      false -> {:error, :invalid_config_format}
    end
  end

  defp cleanup_theme(_theme_state) do
    # In a real implementation, this would clean up any resources used by the theme
    :ok
  end

  defp filter_themes(themes, opts) do
    themes
    |> Enum.filter(fn {_id, theme} ->
      Enum.all?(opts, fn
        {:status, status} -> theme.status == status
        _ -> true
      end)
    end)
    |> Map.new()
  end

  defp load_themes_from_paths(paths) do
    Enum.each(paths, &load_themes_from_path/1)
  end

  defp load_themes_from_path(path) do
    case File.ls(path) do
      {:ok, files} ->
        Enum.each(files, &load_theme_from_path(path, &1))

      {:error, reason} ->
        Logger.error("Failed to list theme directory #{path}: #{reason}")
    end
  end

  defp load_theme_from_path(base_path, file) do
    full_path = Path.join(base_path, file)

    case File.dir?(full_path) do
      true -> load_theme_from_directory(full_path)
      false -> load_theme_from_file(full_path)
    end
  end

  defp load_theme_from_directory(_path) do
    # Implementation for loading theme from directory
    :ok
  end

  defp load_theme_from_file(_path) do
    # Implementation for loading theme from file
    :ok
  end

  defp export_theme_to_file(theme_state, path) do
    case Jason.encode(theme_state) do
      {:ok, json} ->
        case File.write(path, json) do
          :ok -> :ok
          {:error, reason} -> {:error, {:file_write_error, reason}}
        end

      {:error, reason} ->
        {:error, {:json_encode_error, reason}}
    end
  end

  defp import_theme_from_file(path) do
    parse_theme_file(path)
  end

  defp parse_theme_file(path) do
    case File.read(path) do
      {:ok, content} ->
        case Jason.decode(content) do
          {:ok, theme_data} ->
            {:ok, build_theme_state(theme_data)}

          {:error, reason} ->
            {:error, {:invalid_theme_format, reason}}
        end

      {:error, reason} ->
        {:error, {:file_read_error, reason}}
    end
  end

  defp build_theme_state(theme_data) do
    %{
      # Will be set by generate_theme_id
      id: nil,
      name: theme_data["name"],
      version: theme_data["version"],
      description: theme_data["description"],
      author: theme_data["author"],
      colors: theme_data["colors"],
      font: theme_data["font"],
      cursor: theme_data["cursor"],
      padding: theme_data["padding"],
      status: :active,
      error: nil,
      config: %{}
    }
  end
end
