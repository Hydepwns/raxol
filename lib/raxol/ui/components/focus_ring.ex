defmodule Raxol.UI.Components.FocusRing do
  @moduledoc """
  Focus ring component for accessibility and keyboard navigation.

  Provides visual focus indicators and manages focus state for UI components.
  """

  @type config :: %{
          enabled: boolean(),
          style: atom(),
          color: atom() | binary(),
          width: integer(),
          offset: integer(),
          components: list(binary())
        }

  @doc """
  Initializes focus ring configuration.
  """
  @spec init(keyword()) :: config()
  def init(opts \\ []) do
    %{
      enabled: Keyword.get(opts, :enabled, true),
      style: Keyword.get(opts, :style, :solid),
      color: Keyword.get(opts, :color, :blue),
      width: Keyword.get(opts, :width, 1),
      offset: Keyword.get(opts, :offset, 0),
      components: Keyword.get(opts, :components, [])
    }
  end

  @doc """
  Renders a focus ring around content.
  """
  @spec render(binary(), config()) :: binary()
  def render(content, %{enabled: false}), do: content

  def render(content, config) do
    border_chars = get_border_chars(config.style)
    wrap_with_border(content, border_chars, config)
  end

  @doc """
  Checks if a component should have focus ring.
  """
  @spec should_focus?(binary(), config()) :: boolean()
  def should_focus?(component_id, %{components: components}) do
    component_id in components
  end

  def should_focus?(_, _), do: false

  @doc """
  Adds a component to focus ring tracking.
  """
  @spec add_component(config(), binary()) :: config()
  def add_component(config, component_id) do
    if component_id in config.components do
      config
    else
      %{config | components: [component_id | config.components]}
    end
  end

  @doc """
  Removes a component from focus ring tracking.
  """
  @spec remove_component(config(), binary()) :: config()
  def remove_component(config, component_id) do
    %{
      config
      | components: Enum.reject(config.components, &(&1 == component_id))
    }
  end

  @doc """
  Updates focus ring style.
  """
  @spec set_style(config(), atom()) :: config()
  def set_style(config, style) when is_atom(style) do
    %{config | style: style}
  end

  # Private helpers

  # FocusRing uses ASCII-only chars for accessibility.
  # For Unicode border styles, use BorderRenderer.get_border_chars_8key/1.
  defp get_border_chars(:solid) do
    Raxol.UI.BorderRenderer.get_border_chars_8key(:ascii)
  end

  defp get_border_chars(:double) do
    %{
      top_left: "#",
      top: "=",
      top_right: "#",
      left: "|",
      right: "|",
      bottom_left: "#",
      bottom: "=",
      bottom_right: "#"
    }
  end

  defp get_border_chars(:dots) do
    %{
      top_left: ".",
      top: ".",
      top_right: ".",
      left: ":",
      right: ":",
      bottom_left: ".",
      bottom: ".",
      bottom_right: "."
    }
  end

  defp get_border_chars(:rounded) do
    %{
      top_left: "(",
      top: "-",
      top_right: ")",
      left: "|",
      right: "|",
      bottom_left: "(",
      bottom: "-",
      bottom_right: ")"
    }
  end

  defp get_border_chars(_) do
    get_border_chars(:solid)
  end

  defp wrap_with_border(content, borders, config) do
    lines = String.split(content, "\n")

    width =
      lines |> Enum.map(&Raxol.UI.TextMeasure.display_width/1) |> Enum.max()

    offset_spaces = String.duplicate(" ", config.offset)

    top_line =
      "#{offset_spaces}#{borders.top_left}#{String.duplicate(borders.top, width)}#{borders.top_right}"

    bottom_line =
      "#{offset_spaces}#{borders.bottom_left}#{String.duplicate(borders.bottom, width)}#{borders.bottom_right}"

    middle_lines =
      Enum.map(lines, fn line ->
        display_w = Raxol.UI.TextMeasure.display_width(line)
        pad = String.duplicate(" ", max(width - display_w, 0))
        "#{offset_spaces}#{borders.left}#{line}#{pad}#{borders.right}"
      end)

    ([top_line | middle_lines] ++ [bottom_line])
    |> Enum.join("\n")
  end
end
