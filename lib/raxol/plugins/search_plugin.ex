defmodule Raxol.Plugins.SearchPlugin do
  import Raxol.Guards

  @moduledoc """
  Plugin for text search functionality.
  """

  @type t :: %__MODULE__{
          name: String.t(),
          version: String.t(),
          description: String.t(),
          enabled: boolean(),
          config: map(),
          dependencies: list(map()),
          api_version: String.t(),
          search_term: String.t() | nil,
          search_results: list(any()),
          current_result_index: integer(),
          state: map()
        }

  defstruct [
    :name,
    :version,
    :description,
    :enabled,
    :config,
    :dependencies,
    :api_version,
    :search_term,
    :search_results,
    :current_result_index,
    state: %{}
  ]

  @impl Raxol.Plugins.Plugin
  def init(config \\ %{}) do
    # Initialize the plugin struct with required fields
    metadata = get_metadata()

    plugin_state =
      struct(
        __MODULE__,
        Map.merge(
          %{
            name: metadata.name,
            version: metadata.version,
            description:
              "Plugin that provides search functionality for terminal content.",
            enabled: true,
            config: config,
            dependencies: metadata.dependencies,
            api_version: get_api_version(),
            search_term: nil,
            search_results: [],
            current_result_index: 0,
            state: %{}
          },
          config
        )
      )

    {:ok, plugin_state}
  end

  @impl Raxol.Plugins.Plugin
  def handle_input(%__MODULE__{} = plugin, input) do
    case input do
      "search " <> search_term ->
        updated_plugin = %{plugin | search_term: search_term}
        {:ok, updated_plugin}

      "/search " <> search_term ->
        updated_plugin = %{plugin | search_term: search_term}
        {:ok, updated_plugin}

      "/n" when plugin.search_term != nil ->
        search_results = plugin.search_results || []

        next_index =
          if length(search_results) > 0 do
            min(plugin.current_result_index + 1, length(search_results) - 1)
          else
            0
          end

        updated_plugin = %{plugin | current_result_index: next_index}
        {:ok, updated_plugin}

      "/N" when plugin.search_term != nil ->
        search_results = plugin.search_results || []

        prev_index =
          if length(search_results) > 0 do
            max(plugin.current_result_index - 1, 0)
          else
            0
          end

        updated_plugin = %{plugin | current_result_index: prev_index}
        {:ok, updated_plugin}

      "/clear" ->
        updated_plugin = %{
          plugin
          | search_term: nil,
            search_results: [],
            current_result_index: 0
        }

        {:ok, updated_plugin}

      _ ->
        {:ok, plugin}
    end
  end

  @impl Raxol.Plugins.Plugin
  def handle_output(%__MODULE__{} = plugin, _output) do
    # This plugin doesn't modify output, just passes it through
    {:ok, plugin}
  end

  @impl Raxol.Plugins.Plugin
  def handle_mouse(%__MODULE__{} = plugin, _event, _emulator_state) do
    # This plugin doesn't handle mouse events
    {:ok, plugin}
  end

  @impl Raxol.Plugins.Plugin
  def handle_resize(%__MODULE__{} = plugin, _width, _height) do
    # This plugin doesn't need to react to resize
    {:ok, plugin}
  end

  @impl Raxol.Plugins.Plugin
  def cleanup(%__MODULE__{} = _plugin) do
    :ok
  end

  @impl Raxol.Plugins.Plugin
  def get_dependencies do
    # Define any dependencies this plugin has
    []
  end

  @impl Raxol.Plugins.Plugin
  def get_api_version do
    # Specify the API version this plugin targets
    "1.0.0"
  end

  # Private functions

  defp start_search(%__MODULE__{} = plugin, search_term) do
    if search_term == "" do
      {:ok,
       %{plugin | search_term: nil, search_results: [], current_result_index: 0}}
    else
      # Search through the current terminal buffer
      results = search_terminal_buffer(search_term)

      {:ok,
       %{
         plugin
         | search_term: search_term,
           search_results: results,
           current_result_index: 0
       }}
    end
  end

  defp search_terminal_buffer(search_term) do
    # Get the current terminal buffer and search for matches
    case Process.get(:terminal_buffer) do
      nil ->
        []

      buffer ->
        buffer
        |> String.split("\n")
        |> Enum.with_index(1)
        |> Enum.filter(fn {line, _} -> String.contains?(line, search_term) end)
        |> Enum.map(fn {line, line_num} ->
          %{line: line, line_number: line_num}
        end)
    end
  end

  defp next_result(%__MODULE__{} = plugin) do
    if plugin.search_term && length(plugin.search_results) > 0 do
      new_index =
        rem(plugin.current_result_index + 1, length(plugin.search_results))

      {:ok, %{plugin | current_result_index: new_index}}
    else
      {:ok, plugin}
    end
  end

  defp prev_result(%__MODULE__{} = plugin) do
    if plugin.search_term && length(plugin.search_results) > 0 do
      new_index =
        if plugin.current_result_index == 0 do
          length(plugin.search_results) - 1
        else
          plugin.current_result_index - 1
        end

      {:ok, %{plugin | current_result_index: new_index}}
    else
      {:ok, plugin}
    end
  end

  defp clear_search(%__MODULE__{} = plugin) do
    {:ok,
     %{plugin | search_term: nil, search_results: [], current_result_index: 0}}
  end

  @doc """
  Highlights the search term in the given text.
  """
  def highlight_search_term(text, search_term)
      when binary?(text) and binary?(search_term) and search_term != "" do
    # ANSI escape sequence for highlighting: \e[43m (yellow background)
    String.replace(text, search_term, "\e[43m#{search_term}\e[0m")
  end

  @doc """
  Gets the current search term.
  """
  def get_search_term(plugin) do
    plugin.search_term
  end

  @doc """
  Gets the current search results.
  """
  def get_search_results(plugin) do
    plugin.search_results
  end

  @doc """
  Gets the current result index.
  """
  def get_current_result_index(plugin) do
    plugin.current_result_index
  end

  @doc """
  Gets the current search result.
  """
  def get_current_result(plugin) do
    if length(plugin.search_results) > 0 do
      Enum.at(plugin.search_results, plugin.current_result_index)
    else
      nil
    end
  end

  @doc """
  Returns metadata for the plugin.
  """
  def get_metadata do
    %{
      name: "search",
      version: "0.1.0",
      dependencies: []
    }
  end
end
