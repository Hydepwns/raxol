defmodule Raxol.Plugins.SearchPlugin do
  @moduledoc """
  Plugin for text search functionality.
  """

  @behaviour Raxol.Plugins.Plugin

  defstruct [
    search_term: nil,
    search_results: [],
    current_result_index: 0
  ]

  def init do
    %{
      search_term: nil,
      search_results: [],
      current_result_index: 0
    }
  end

  @impl true
  def handle_input(plugin, input) do
    case input do
      "/" <> search_term ->
        start_search(plugin, search_term)
      "n" when plugin.search_term != nil ->
        next_result(plugin)
      "N" when plugin.search_term != nil ->
        prev_result(plugin)
      "\e" ->  # Escape key
        clear_search(plugin)
      _ -> {:ok, plugin}
    end
  end

  @impl true
  def handle_mouse(_plugin, _event) do
    :ok
  end

  @impl true
  def handle_output(plugin, _output) do
    {:ok, plugin}
  end

  @impl true
  def handle_resize(plugin, _width, _height) do
    {:ok, plugin}
  end

  @impl true
  def cleanup(_plugin) do
    :ok
  end

  @impl true
  def get_name(plugin) do
    plugin.name
  end

  @impl true
  def is_enabled?(plugin) do
    plugin.enabled
  end

  @impl true
  def enable(plugin) do
    %{plugin | enabled: true}
  end

  @impl true
  def disable(plugin) do
    %{plugin | enabled: false}
  end

  # Private functions

  defp start_search(plugin, search_term) do
    if search_term == "" do
      {:ok, %{plugin | search_term: nil, search_results: [], current_result_index: 0}}
    else
      # TODO: Implement actual search functionality
      {:ok, %{plugin | search_term: search_term, search_results: [], current_result_index: 0}}
    end
  end

  defp next_result(plugin) do
    if plugin.search_term && length(plugin.search_results) > 0 do
      new_index = rem(plugin.current_result_index + 1, length(plugin.search_results))
      {:ok, %{plugin | current_result_index: new_index}}
    else
      {:ok, plugin}
    end
  end

  defp prev_result(plugin) do
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

  defp clear_search(plugin) do
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