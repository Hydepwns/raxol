defmodule Raxol.Terminal.Output.Processor do
  @moduledoc """
  Processes output events for the terminal emulator.
  """

  @doc """
  Styles an output event with the current terminal attributes.
  """
  def style_event(event) do
    case event do
      %{type: :text, content: content, style: style} ->
        styled_content = apply_style(content, style)
        {:ok, %{event | content: styled_content}}

      _ ->
        {:error, :unknown_event_type}
    end
  end

  # Private functions

  defp apply_style(content, style) do
    content
    |> apply_foreground(style.foreground)
    |> apply_background(style.background)
    |> apply_attributes(style.attributes)
  end

  defp apply_foreground(content, nil), do: content

  defp apply_foreground(content, color) do
    "\e[38;5;#{color}m#{content}\e[39m"
  end

  defp apply_background(content, nil), do: content

  defp apply_background(content, color) do
    "\e[48;5;#{color}m#{content}\e[49m"
  end

  defp apply_attributes(content, []), do: content

  defp apply_attributes(content, attributes) do
    codes = Enum.map(attributes, &attribute_to_code/1)
    "\e[#{Enum.join(codes, ";")}m#{content}\e[0m"
  end

  defp attribute_to_code(:bold), do: "1"
  defp attribute_to_code(:dim), do: "2"
  defp attribute_to_code(:italic), do: "3"
  defp attribute_to_code(:underline), do: "4"
  defp attribute_to_code(:blink), do: "5"
  defp attribute_to_code(:reverse), do: "7"
  defp attribute_to_code(:hidden), do: "8"
  defp attribute_to_code(:strikethrough), do: "9"
end
