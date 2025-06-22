defmodule Raxol.Plugins.SearchPlugin do
  import Raxol.Guards

  @moduledoc """
  Plugin for text search functionality.
  """

  @behaviour Raxol.Plugins.Plugin

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
          current_result_index: integer()
        }

  defstruct name: "search",
            version: "0.1.0",
            description:
              "Provides text search functionality within the terminal.",
            enabled: true,
            config: %{},
            dependencies: [],
            api_version: "1.0.0",
            search_term: nil,
            search_results: [],
            current_result_index: 0

  @impl true
  def init(config \\ %{}) do
    plugin_state = struct(__MODULE__, config)
    {:ok, plugin_state}
  end

  @impl true
  def handle_input(%__MODULE__{} = plugin, input) do
    case input do
      "/search " <> search_term ->
        start_search(plugin, search_term)

      "/n" when plugin.search_term != nil ->
        next_result(plugin)

      "/N" when plugin.search_term != nil ->
        prev_result(plugin)

      "/clear" ->
        clear_search(plugin)

      _ ->
        {:ok, plugin}
    end
  end

  @impl Raxol.Plugins.Plugin
  def handle_mouse(%__MODULE__{} = plugin, event, _emulator_state) do
    case event do
      %{type: :click, y: y} when plugin.search_term != nil ->
        # Convert click position to result index
        result_index = max(0, min(y - 1, length(plugin.search_results) - 1))
        {:ok, %{plugin | current_result_index: result_index}}

      _ ->
        {:ok, plugin}
    end
  end

  @impl Raxol.Plugins.Plugin
  def handle_output(state, _output), do: {:ok, state}

  @impl Raxol.Plugins.Plugin
  def handle_resize(%__MODULE__{} = plugin, _width, _height) do
    {:ok, plugin}
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
end
