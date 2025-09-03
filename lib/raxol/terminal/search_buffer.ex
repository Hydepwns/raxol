defmodule Raxol.Terminal.SearchBuffer do
  @moduledoc """
  Manages search state, options, matches, and history for terminal search operations.
  """

  @type match :: %{
          line: integer(),
          start: integer(),
          length: integer(),
          text: String.t()
        }
  @type options :: %{case_sensitive: boolean(), regex: boolean()}

  @type t :: %__MODULE__{
          pattern: String.t() | nil,
          options: options(),
          matches: [match()],
          current_index: integer(),
          history: [String.t()]
        }

  defstruct pattern: nil,
            options: %{case_sensitive: false, regex: false},
            matches: [],
            current_index: -1,
            history: []

  @doc """
  Starts a new search with the given pattern.
  """
  @spec start_search(t(), String.t()) :: {:ok, t()} | {:error, term()}
  def start_search(buffer, pattern) when is_binary(pattern) do
    if pattern == "" do
      {:error, :empty_pattern}
    else
      # For now, just clear matches; real impl would search buffer content
      new_buffer = %{
        buffer
        | pattern: pattern,
          matches: [],
          current_index: -1,
          history: add_pattern_to_history(buffer.history, pattern)
      }

      {:ok, new_buffer}
    end
  end

  @doc """
  Finds the next match in the search.
  """
  @spec find_next(t()) :: {:ok, t(), match()} | {:error, term()}
  def find_next(%__MODULE__{matches: [], pattern: nil} = _buffer),
    do: {:error, :no_search}

  def find_next(%__MODULE__{matches: []} = _buffer), do: {:error, :no_matches}

  def find_next(%__MODULE__{matches: matches, current_index: idx} = buffer) do
    new_idx = rem(idx + 1, length(matches))
    {:ok, %{buffer | current_index: new_idx}, Enum.at(matches, new_idx)}
  end

  @doc """
  Finds the previous match in the search.
  """
  @spec find_previous(t()) :: {:ok, t(), match()} | {:error, term()}
  def find_previous(%__MODULE__{matches: [], pattern: nil} = _buffer),
    do: {:error, :no_search}

  def find_previous(%__MODULE__{matches: []} = _buffer),
    do: {:error, :no_matches}

  def find_previous(%__MODULE__{matches: matches, current_index: idx} = buffer) do
    new_idx = rem(idx - 1 + length(matches), length(matches))
    {:ok, %{buffer | current_index: new_idx}, Enum.at(matches, new_idx)}
  end

  @doc """
  Gets the current search pattern.
  """
  @spec get_pattern(t()) :: String.t() | nil
  def get_pattern(%__MODULE__{pattern: pattern}), do: pattern

  @doc """
  Sets the search options.
  """
  @spec set_options(t(), map()) :: t()
  def set_options(buffer, opts) when is_map(opts) do
    %{buffer | options: Map.merge(buffer.options, opts)}
  end

  @doc """
  Gets the current search options.
  """
  @spec get_options(t()) :: map()
  def get_options(%__MODULE__{options: opts}), do: opts

  @doc """
  Gets all matches in the current search.
  """
  @spec get_all_matches(t()) :: [match()]
  def get_all_matches(%__MODULE__{matches: matches}), do: matches

  @doc """
  Gets the current match index.
  """
  @spec get_current_index(t()) :: integer()
  def get_current_index(%__MODULE__{current_index: idx}), do: idx

  @doc """
  Gets the total number of matches.
  """
  @spec get_match_count(t()) :: non_neg_integer()
  def get_match_count(%__MODULE__{matches: matches}), do: length(matches)

  @doc """
  Highlights all matches in the current view (no-op placeholder).
  """
  @spec highlight_matches(t()) :: t()
  def highlight_matches(buffer), do: buffer

  @doc """
  Clears the current search.
  """
  @spec clear(t()) :: t()
  def clear(buffer) do
    %{buffer | pattern: nil, matches: [], current_index: -1}
  end

  @doc """
  Gets the search history.
  """
  @spec get_search_history(t()) :: [String.t()]
  def get_search_history(%__MODULE__{history: history}), do: history

  @doc """
  Adds a pattern to the search history.
  """
  @spec add_to_history(t(), String.t()) :: t()
  def add_to_history(buffer, pattern) when is_binary(pattern) do
    %{buffer | history: add_pattern_to_history(buffer.history, pattern)}
  end

  @doc """
  Clears the search history.
  """
  @spec clear_history(t()) :: t()
  def clear_history(buffer), do: %{buffer | history: []}

  # Helper
  defp add_pattern_to_history(history, pattern) do
    [pattern | Enum.reject(history, &(&1 == pattern))]
    # Limit history size
    |> Enum.take(20)
  end
end
