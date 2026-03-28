defmodule Raxol.Terminal.Color.TrueColor.Detection do
  @moduledoc """
  Terminal color capability detection via environment variables.
  """

  @type terminal_capability ::
          :true_color | :color_256 | :color_16 | :monochrome

  @doc """
  Detects the terminal's color capability by inspecting COLORTERM and TERM env vars.
  """
  @spec detect() :: terminal_capability()
  def detect do
    case {supports_true_color?(), supports_256_color?(), supports_16_color?()} do
      {true, _, _} -> :true_color
      {_, true, _} -> :color_256
      {_, _, true} -> :color_16
      _ -> :monochrome
    end
  end

  @doc """
  Returns true if the terminal supports 24-bit true color.
  """
  @spec supports_true_color?() :: boolean()
  def supports_true_color? do
    colorterm = System.get_env("COLORTERM")
    term = System.get_env("TERM")
    check_true_color(colorterm, term)
  end

  @doc """
  Returns true if the terminal supports 256 colors.
  """
  @spec supports_256_color?() :: boolean()
  def supports_256_color? do
    term = System.get_env("TERM")
    check_256_color(term)
  end

  @doc """
  Returns true if the terminal supports 16 colors.
  """
  @spec supports_16_color?() :: boolean()
  def supports_16_color? do
    term = System.get_env("TERM")
    check_16_color(term)
  end

  # -- Private helpers --

  defp check_true_color(colorterm, _term)
       when colorterm in ["truecolor", "24bit"],
       do: true

  defp check_true_color("truecolor", term) when is_binary(term) do
    String.contains?(term, "256color")
  end

  defp check_true_color(_colorterm, _term), do: false

  defp check_256_color(nil), do: false
  defp check_256_color(term) when term == "xterm-kitty", do: true

  defp check_256_color(term) when is_binary(term) do
    String.contains?(term, "256color")
  end

  defp check_16_color(nil), do: false
  defp check_16_color(term) when term in ["dumb", "unknown"], do: false
  defp check_16_color(_term), do: true
end
