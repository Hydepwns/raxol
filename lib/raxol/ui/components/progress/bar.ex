defmodule Raxol.UI.Components.Progress.Bar do
  @moduledoc """
  Progress bar component for terminal UIs.

  Provides horizontal progress bars with customizable appearance.
  """

  @doc """
  Creates a progress bar.
  """
  def bar(value, opts \\ []) when is_number(value) do
    max = Keyword.get(opts, :max, 100)
    width = Keyword.get(opts, :width, 20)
    style = Keyword.get(opts, :style, :solid)

    percentage = min(100, value / max * 100)
    filled = round(width * percentage / 100)
    empty = width - filled

    {filled_char, empty_char} = get_bar_chars(style)

    bar_content =
      String.duplicate(filled_char, filled) <>
        String.duplicate(empty_char, empty)

    if Keyword.get(opts, :show_percentage, true) do
      "[#{bar_content}] #{round(percentage)}%"
    else
      "[#{bar_content}]"
    end
  end

  @doc """
  Creates a progress bar with a label.
  """
  def bar_with_label(value, label, opts \\ []) do
    bar_string = bar(value, Keyword.put(opts, :show_percentage, false))
    percentage = round(min(100, value / Keyword.get(opts, :max, 100) * 100))

    "#{label}: #{bar_string} #{percentage}%"
  end

  # Private helpers

  defp get_bar_chars(:solid), do: {"=", " "}
  defp get_bar_chars(:blocks), do: {"█", "░"}
  defp get_bar_chars(:dots), do: {"●", "○"}
  defp get_bar_chars(:ascii), do: {"#", "-"}
  defp get_bar_chars(:simple), do: {">", " "}
  defp get_bar_chars(_), do: {"=", " "}
end
