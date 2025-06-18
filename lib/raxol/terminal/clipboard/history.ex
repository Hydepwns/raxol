defmodule Raxol.Terminal.Clipboard.History do
  @moduledoc """
  Manages clipboard history for the terminal.
  """

  defstruct [:entries, :max_size]

  @type t :: %__MODULE__{
          # {content, format}
          entries: list({String.t(), String.t()}),
          max_size: non_neg_integer()
        }

  @doc """
  Creates a new clipboard history with the specified size limit.
  """
  @spec new(non_neg_integer()) :: t()
  def new(max_size) do
    %__MODULE__{
      entries: [],
      max_size: max_size
    }
  end

  @doc """
  Adds content to the clipboard history.
  """
  @spec add(t(), String.t(), String.t()) :: {:ok, t()}
  def add(history, content, format) do
    entries =
      [{content, format} | history.entries]
      |> Enum.take(history.max_size)

    {:ok, %{history | entries: entries}}
  end

  @doc """
  Gets content from the clipboard history by index.
  """
  @spec get(t(), non_neg_integer(), String.t()) ::
          {:ok, String.t()} | {:error, :not_found}
  def get(history, index, format) do
    case Enum.at(history.entries, index) do
      {content, ^format} -> {:ok, content}
      _ -> {:error, :not_found}
    end
  end

  @doc """
  Gets all entries from the clipboard history with the specified format.
  """
  @spec get_all(t(), String.t(), non_neg_integer() | :infinity) ::
          {:ok, list(String.t()), t()}
  def get_all(history, format, limit \\ :infinity) do
    entries =
      history.entries
      |> Enum.filter(fn {_, f} -> f == format end)
      |> Enum.map(fn {content, _} -> content end)
      |> case do
        entries when limit == :infinity -> entries
        entries -> Enum.take(entries, limit)
      end

    {:ok, entries, history}
  end

  @doc """
  Clears the clipboard history.
  """
  @spec clear(t()) :: {:ok, t()}
  def clear(history) do
    {:ok, %{history | entries: []}}
  end
end
