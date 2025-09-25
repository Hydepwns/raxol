defmodule Raxol.UI.Components.HintDisplay do
  @moduledoc """
  Hint display component for contextual help and tooltips.

  Provides inline hints, tooltips, and contextual help for UI components.
  """

  @type config :: %{
          enabled: boolean(),
          position: atom(),
          delay: integer(),
          style: atom(),
          max_width: integer(),
          hints: map()
        }

  @type hint :: %{
          text: binary(),
          type: atom(),
          priority: integer()
        }

  @doc """
  Initializes hint display configuration.
  """
  @spec init(keyword() | map()) :: config()
  def init(opts \\ []) do
    # Handle both keyword lists and maps
    get_option = fn key, default ->
      cond do
        is_list(opts) -> Keyword.get(opts, key, default)
        is_map(opts) -> Map.get(opts, key, default)
        true -> default
      end
    end

    %{
      enabled: get_option.(:enabled, true),
      position: get_option.(:position, :below),
      delay: get_option.(:delay, 500),
      style: get_option.(:style, :tooltip),
      max_width: get_option.(:max_width, 40),
      hints: get_option.(:hints, %{})
    }
  end

  @doc """
  Registers a hint for a component.
  """
  @spec register_hint(config(), binary(), binary(), keyword()) :: config()
  def register_hint(config, component_id, text, opts \\ []) do
    hint = %{
      text: text,
      type: Keyword.get(opts, :type, :info),
      priority: Keyword.get(opts, :priority, 0)
    }

    %{config | hints: Map.put(config.hints, component_id, hint)}
  end

  @doc """
  Gets hint for a component.
  """
  @spec get_hint(config(), binary()) :: hint() | nil
  def get_hint(%{hints: hints}, component_id) do
    Map.get(hints, component_id)
  end

  def get_hint(_, _), do: nil

  @doc """
  Renders a hint display.
  """
  @spec render(hint(), config()) :: binary()
  def render(nil, _), do: ""

  def render(%{text: text, type: type}, config) do
    style = config.style
    max_width = config.max_width

    formatted_text = format_text(text, max_width)
    styled_hint = apply_style(formatted_text, style, type)

    position_hint(styled_hint, config.position)
  end

  @doc """
  Renders inline hint next to content.
  """
  @spec render_inline(binary(), binary(), config()) :: binary()
  def render_inline(content, component_id, config) do
    case get_hint(config, component_id) do
      nil ->
        content

      hint ->
        hint_text = render(hint, config)
        combine_content_and_hint(content, hint_text, config.position)
    end
  end

  @doc """
  Clears all hints.
  """
  @spec clear_hints(config()) :: config()
  def clear_hints(config) do
    %{config | hints: %{}}
  end

  @doc """
  Removes a specific hint.
  """
  @spec remove_hint(config(), binary()) :: config()
  def remove_hint(config, component_id) do
    %{config | hints: Map.delete(config.hints, component_id)}
  end

  # Private helpers

  defp format_text(text, max_width) when byte_size(text) > max_width do
    text
    |> String.slice(0, max_width - 3)
    |> Kernel.<>("...")
  end

  defp format_text(text, _), do: text

  defp apply_style(text, :tooltip, type) do
    prefix = get_type_prefix(type)
    border = get_type_border(type)

    """
    #{border.top}
    #{border.left} #{prefix}#{text} #{border.right}
    #{border.bottom}
    """
    |> String.trim()
  end

  defp apply_style(text, :inline, type) do
    prefix = get_type_prefix(type)
    color = get_type_color(type)

    "#{color}(#{prefix}#{text})\e[0m"
  end

  defp apply_style(text, :minimal, type) do
    color = get_type_color(type)
    "#{color}#{text}\e[0m"
  end

  defp apply_style(text, _, type) do
    apply_style(text, :inline, type)
  end

  defp get_type_prefix(:info), do: "i: "
  defp get_type_prefix(:warning), do: "!: "
  defp get_type_prefix(:error), do: "X: "
  defp get_type_prefix(:success), do: "ok: "
  defp get_type_prefix(:help), do: "?: "
  defp get_type_prefix(_), do: ""

  defp get_type_color(:info), do: "\e[34m"
  defp get_type_color(:warning), do: "\e[33m"
  defp get_type_color(:error), do: "\e[31m"
  defp get_type_color(:success), do: "\e[32m"
  defp get_type_color(:help), do: "\e[36m"
  defp get_type_color(_), do: "\e[37m"

  defp get_type_border(:info) do
    %{top: "---- Info ----", left: "|", right: "|", bottom: "--------------"}
  end

  defp get_type_border(:warning) do
    %{
      top: "!!!! Warning !!!!",
      left: "!",
      right: "!",
      bottom: "!!!!!!!!!!!!!!!"
    }
  end

  defp get_type_border(:error) do
    %{top: "XXXX Error XXXX", left: "X", right: "X", bottom: "XXXXXXXXXXXXXX"}
  end

  defp get_type_border(_) do
    %{top: "---------", left: "|", right: "|", bottom: "---------"}
  end

  defp position_hint(hint, :below) do
    "\n#{hint}"
  end

  defp position_hint(hint, :above) do
    "#{hint}\n"
  end

  defp position_hint(hint, :right) do
    " #{hint}"
  end

  defp position_hint(hint, :left) do
    "#{hint} "
  end

  defp position_hint(hint, _), do: hint

  defp combine_content_and_hint(content, hint, :below) do
    "#{content}#{hint}"
  end

  defp combine_content_and_hint(content, hint, :above) do
    "#{hint}#{content}"
  end

  defp combine_content_and_hint(content, hint, :right) do
    lines = String.split(content, "\n")
    first_line = List.first(lines, "")
    rest_lines = Enum.drop(lines, 1)

    if rest_lines == [] do
      "#{first_line}#{hint}"
    else
      ["#{first_line}#{hint}" | rest_lines] |> Enum.join("\n")
    end
  end

  defp combine_content_and_hint(content, hint, _) do
    combine_content_and_hint(content, hint, :below)
  end
end
