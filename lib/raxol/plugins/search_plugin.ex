defmodule Raxol.Plugins.SearchPlugin do
  @moduledoc """
  Plugin for text search functionality.
  """

  @behaviour Raxol.Plugins.Plugin
  alias Raxol.Plugins.Plugin

  @type t :: %__MODULE__{
    # Plugin behaviour fields
    name: String.t(),
    version: String.t(),
    description: String.t(),
    enabled: boolean(),
    config: map(),
    dependencies: list(map()),
    api_version: String.t(),
    # Plugin specific state
    search_term: String.t() | nil,
    search_results: list(any()), # TODO: Define a proper result type
    current_result_index: integer()
  }

  defstruct [
    # Plugin behaviour fields
    name: "search",
    version: "0.1.0",
    description: "Provides text search functionality within the terminal.",
    enabled: true,
    config: %{},
    dependencies: [],
    api_version: "1.0.0",
    # Plugin specific state
    search_term: nil,
    search_results: [],
    current_result_index: 0
  ]

  @impl true
  def init(config \\ %{}) do
    plugin_state = struct(__MODULE__, config) # Merges config with defaults in struct
    {:ok, plugin_state}
  end

  @impl true
  def handle_input(%__MODULE__{} = plugin, input) do
    case input do
      "/" <> search_term ->
        start_search(plugin, search_term)
      "n" when plugin.search_term != nil ->
        next_result(plugin)
      "N" when plugin.search_term != nil ->
        prev_result(plugin)
      "\e" ->  # Escape key
        clear_search(plugin)
      _ -> {:ok, plugin} # Return the full plugin state
    end
  end

  @impl true
  def handle_mouse(%__MODULE__{} = plugin, _event) do
    {:ok, plugin} # Return the full plugin state
  end

  @impl true
  def handle_output(%__MODULE__{} = plugin, _output) do
    {:ok, plugin} # Return the full plugin state
  end

  @impl true
  def handle_resize(%__MODULE__{} = plugin, _width, _height) do
    {:ok, plugin} # Return the full plugin state
  end

  @impl true
  def cleanup(%__MODULE__{} = _plugin) do
    :ok
  end

  @impl true
  def get_dependencies do
    # Define any dependencies this plugin has
    []
  end

  @impl true
  def get_api_version do
    # Specify the API version this plugin targets
    "1.0.0"
  end

  # Private functions

  defp start_search(%__MODULE__{} = plugin, search_term) do
    if search_term == "" do
      {:ok, %{plugin | search_term: nil, search_results: [], current_result_index: 0}}
    else
      # TODO: Implement actual search functionality
      {:ok, %{plugin | search_term: search_term, search_results: [], current_result_index: 0}}
    end
  end

  defp next_result(%__MODULE__{} = plugin) do
    if plugin.search_term && length(plugin.search_results) > 0 do
      new_index = rem(plugin.current_result_index + 1, length(plugin.search_results))
      {:ok, %{plugin | current_result_index: new_index}}
    else
      {:ok, plugin}
    end
  end

  defp prev_result(%__MODULE__{} = plugin) do
    if plugin.search_term && length(plugin.search_results) > 0 do
      new_index = if plugin.current_result_index == 0 do
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
    {:ok, %{plugin | search_term: nil, search_results: [], current_result_index: 0}}
  end

  @doc """
  Highlights the search term in the given text.
  """
  def highlight_search_term(text, search_term) when is_binary(text) and is_binary(search_term) and search_term != "" do
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
end
