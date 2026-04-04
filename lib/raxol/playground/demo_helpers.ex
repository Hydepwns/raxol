defmodule Raxol.Playground.DemoHelpers do
  @moduledoc """
  Shared helpers for playground demo TEA apps.

  Small utilities that eliminate the most common duplication
  across demos while keeping demos self-contained and readable.
  """

  @doc """
  Moves a cursor index down (increment), clamped to `max_index`.
  """
  @spec cursor_down(non_neg_integer(), non_neg_integer()) :: non_neg_integer()
  def cursor_down(current, max_index), do: min(current + 1, max_index)

  @doc """
  Moves a cursor index up (decrement), clamped to 0.
  """
  @spec cursor_up(non_neg_integer()) :: non_neg_integer()
  def cursor_up(current), do: max(current - 1, 0)

  @doc """
  Returns `"> "` if `index` matches `selected`, else `"  "`.
  """
  @spec cursor_prefix(non_neg_integer(), non_neg_integer()) :: String.t()
  def cursor_prefix(index, selected) when index == selected, do: "> "
  def cursor_prefix(_index, _selected), do: "  "

  @doc """
  Cycles an index forward through a list length, wrapping around.
  """
  @spec cycle_next(non_neg_integer(), non_neg_integer()) :: non_neg_integer()
  def cycle_next(current, count), do: rem(current + 1, count)

  @doc """
  Navigate backward through input history.

  Expects the model to have `:input_history`, `:history_index`, `:input`, and `:cursor` fields.
  """
  @spec history_prev(map()) :: map()
  def history_prev(%{input_history: []} = model), do: model

  def history_prev(model) do
    idx = (model.history_index || -1) + 1
    idx = min(idx, length(model.input_history) - 1)
    input = Enum.at(model.input_history, idx, model.input)
    %{model | history_index: idx, input: input, cursor: String.length(input)}
  end

  @doc """
  Navigate forward through input history.

  Expects the model to have `:input_history`, `:history_index`, `:input`, and `:cursor` fields.
  """
  @spec history_next(map()) :: map()
  def history_next(model) do
    case model.history_index do
      nil ->
        model

      0 ->
        %{model | history_index: nil, input: "", cursor: 0}

      idx ->
        new_idx = idx - 1
        input = Enum.at(model.input_history, new_idx, "")

        %{
          model
          | history_index: new_idx,
            input: input,
            cursor: String.length(input)
        }
    end
  end
end
