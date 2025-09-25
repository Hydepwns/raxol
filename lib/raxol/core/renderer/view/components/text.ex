defmodule Raxol.Core.Renderer.View.Components.Text do
  @moduledoc """
  Handles text rendering for the Raxol view system.
  Provides text styling, wrapping, and alignment functionality.
  """

  @doc """
  Creates a new text view.

  ## Options
    * `:fg` - Foreground color
    * `:bg` - Background color
    * `:style` - List of style atoms (e.g., [:bold, :underline])
    * `:align` - Text alignment (:left, :center, :right)
    * `:wrap` - Text wrapping mode (:none, :char, :word)

  ## Examples

      Text.new("Hello, World!", fg: :red, style: [:bold])
      Text.new("Centered text", align: :center)
  """
  def new(content, opts \\ []) when is_binary(content) do
    %{
      type: :text,
      content: content,
      size: Keyword.get(opts, :size, {1, 1}),
      fg: Keyword.get(opts, :fg),
      bg: Keyword.get(opts, :bg),
      style: Keyword.get(opts, :style, []),
      align: Keyword.get(opts, :align, :left),
      wrap: Keyword.get(opts, :wrap, :none)
    }
  end

  @doc """
  Renders text with the given options and width.
  """
  def render(text, width) do
    text.content
    |> wrap_text(width, text.wrap)
    |> align_text(width, text.align)
    |> apply_styles(text.style)
  end

  @spec wrap_text(any(), String.t() | integer(), any()) :: any()
  defp wrap_text(text, _width, :none), do: [text]
  @spec wrap_text(any(), String.t() | integer(), any()) :: any()
  defp wrap_text(text, width, :char), do: wrap_by_char(text, width)
  @spec wrap_text(any(), String.t() | integer(), any()) :: any()
  defp wrap_text(text, width, :word), do: wrap_by_word(text, width)

  @spec wrap_by_char(any(), String.t() | integer()) :: any()
  defp wrap_by_char(text, width) do
    text
    |> String.graphemes()
    |> Enum.chunk_every(width)
    |> Enum.map(&Enum.join/1)
  end

  @spec wrap_by_word(any(), String.t() | integer()) :: any()
  defp wrap_by_word(text, width) do
    text
    |> String.split(" ")
    |> Enum.reduce({[], ""}, &process_word(&1, &2, width))
    |> (fn {lines, last_line} ->
          case last_line do
            "" -> lines
            _ -> lines ++ [last_line]
          end
        end).()
  end

  @spec process_word(any(), any(), String.t() | integer()) :: any()
  defp process_word(word, {lines, current_line}, width) do
    case String.length(current_line) + String.length(word) + 1 <= width do
      true ->
        new_line = build_line(current_line, word)
        {lines, new_line}

      false ->
        {lines ++ [current_line], word}
    end
  end

  @spec build_line(any(), any()) :: any()
  defp build_line("", word), do: word
  @spec build_line(any(), any()) :: any()
  defp build_line(current_line, word), do: current_line <> " " <> word

  @spec align_text(any(), String.t() | integer(), any()) :: any()
  defp align_text(lines, _width, :left), do: lines

  @spec align_text(any(), String.t() | integer(), any()) :: any()
  defp align_text(lines, width, :right),
    do: Enum.map(lines, &String.pad_leading(&1, width))

  @spec align_text(any(), String.t() | integer(), any()) :: any()
  defp align_text(lines, width, :center),
    do:
      Enum.map(
        lines,
        &String.pad_leading(&1, div(width + String.length(&1), 2))
      )

  @spec apply_styles(any(), any()) :: any()
  defp apply_styles(lines, styles) do
    Enum.map(lines, fn line ->
      Enum.reduce(styles, line, fn style, acc ->
        apply_style(acc, style)
      end)
    end)
  end

  @spec apply_style(any(), any()) :: any()
  defp apply_style(text, :bold), do: "\e[1m#{text}\e[0m"
  @spec apply_style(any(), any()) :: any()
  defp apply_style(text, :underline), do: "\e[4m#{text}\e[0m"
  @spec apply_style(any(), any()) :: any()
  defp apply_style(text, :italic), do: "\e[3m#{text}\e[0m"
  @spec apply_style(any(), any()) :: any()
  defp apply_style(text, :strikethrough), do: "\e[9m#{text}\e[0m"
  @spec apply_style(any(), any()) :: any()
  defp apply_style(text, _), do: text
end
