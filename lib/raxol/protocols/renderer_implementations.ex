defmodule Raxol.Protocols.RendererImplementations do
  @moduledoc """
  Protocol implementations for terminal renderer types.
  """

  alias Raxol.Terminal.{Renderer, ScreenBuffer}

  # Implementation for Terminal.Renderer
  defimpl Raxol.Protocols.Renderable, for: Raxol.Terminal.Renderer do
    def render(renderer, opts) do
      # Use the existing render function
      Renderer.render(renderer, opts)
    end

    def render_metadata(renderer) do
      buffer = renderer.screen_buffer
      {width, height} = ScreenBuffer.get_dimensions(buffer)

      %{
        width: width,
        height: height,
        colors: true,
        scrollable: true,
        interactive: true,
        theme: renderer.theme,
        font_settings: renderer.font_settings
      }
    end
  end

  # Implementation for Styleable protocol for Renderer
  defimpl Raxol.Protocols.Styleable, for: Raxol.Terminal.Renderer do
    def apply_style(renderer, style) do
      # Apply style to the theme
      updated_theme = Map.merge(renderer.theme, style)
      %{renderer | theme: updated_theme}
    end

    def get_style(renderer) do
      renderer.theme || %{}
    end

    def merge_styles(renderer, new_style) do
      current_style = get_style(renderer)
      merged = Map.merge(current_style, new_style)
      %{renderer | theme: merged}
    end

    def reset_style(renderer) do
      %{renderer | theme: %{}}
    end

    def to_ansi(renderer) do
      # Convert theme to ANSI codes
      theme = renderer.theme || %{}
      build_ansi_from_theme(theme)
    end

    defp build_ansi_from_theme(theme) do
      codes = []

      # Extract foreground color
      codes = case theme[:foreground] do
        %{default: color} when is_binary(color) ->
          rgb = hex_to_rgb(color)
          ["38;2;#{elem(rgb, 0)};#{elem(rgb, 1)};#{elem(rgb, 2)}" | codes]
        _ -> codes
      end

      # Extract background color
      codes = case theme[:background] do
        %{default: color} when is_binary(color) ->
          rgb = hex_to_rgb(color)
          ["48;2;#{elem(rgb, 0)};#{elem(rgb, 1)};#{elem(rgb, 2)}" | codes]
        _ -> codes
      end

      if codes == [] do
        ""
      else
        "\e[#{Enum.join(codes, ";")}m"
      end
    end

    defp hex_to_rgb("#" <> hex) do
      {r, ""} = Integer.parse(String.slice(hex, 0, 2), 16)
      {g, ""} = Integer.parse(String.slice(hex, 2, 2), 16)
      {b, ""} = Integer.parse(String.slice(hex, 4, 2), 16)
      {r, g, b}
    end

    defp hex_to_rgb(_), do: {0, 0, 0}
  end

  # Implementation for Serializable protocol for Renderer
  defimpl Raxol.Protocols.Serializable, for: Raxol.Terminal.Renderer do
    def serialize(renderer, :json) do
      data = %{
        cursor: renderer.cursor,
        theme: renderer.theme,
        font_settings: renderer.font_settings,
        style_batching: renderer.style_batching,
        content: Renderer.render(renderer)
      }

      case Jason.encode(data) do
        {:ok, json} -> json
        {:error, reason} -> {:error, reason}
      end
    end

    def serialize(renderer, :binary) do
      :erlang.term_to_binary(renderer)
    end

    def serialize(_renderer, format) do
      {:error, {:unsupported_format, format}}
    end

    def serializable?(_renderer, format) do
      format in [:json, :binary]
    end
  end
end