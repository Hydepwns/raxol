defmodule Raxol.Telegram.OutputAdapter do
  @moduledoc """
  Converts a Raxol screen buffer into Telegram-formatted output.

  Renders the buffer as a monospace code block using Telegram's HTML
  parse mode (`<pre>` tags). Generates inline keyboard markup from
  navigation defaults or view tree button elements.
  """

  @default_width 40
  @default_height 20

  @doc """
  Converts a screen buffer (map with `:cells` list-of-lists and `:width`/`:height`)
  to a Telegram HTML string wrapped in `<pre>` tags.

  Cells are expected to be maps with a `:char` field.
  """
  @spec buffer_to_text(map()) :: String.t()
  def buffer_to_text(%{cells: cells}) when is_list(cells) do
    cells
    |> Enum.map(fn line when is_list(line) ->
      line
      |> Enum.map_join("", fn
        %{char: char} when is_binary(char) -> char
        _ -> " "
      end)
      |> String.trim_trailing()
    end)
    |> trim_trailing_empty()
    |> Enum.join("\n")
  end

  def buffer_to_text(_), do: ""

  @doc """
  Wraps buffer text in `<pre>` tags for Telegram HTML parse_mode.

  Escapes HTML entities in the buffer content.
  """
  @spec buffer_to_html(map()) :: String.t()
  def buffer_to_html(buffer) do
    text = buffer_to_text(buffer)
    "<pre>#{escape_html(text)}</pre>"
  end

  @doc """
  Builds a default navigation inline keyboard.

  Returns a list of button rows, where each button is a map with
  `:text` and `:callback_data` keys.
  """
  @spec default_keyboard() :: [[map()]]
  def default_keyboard do
    [
      [
        %{text: "\u25C0", callback_data: "key:left"},
        %{text: "\u25B2", callback_data: "key:up"},
        %{text: "\u25BC", callback_data: "key:down"},
        %{text: "\u25B6", callback_data: "key:right"}
      ],
      [
        %{text: "Tab", callback_data: "key:tab"},
        %{text: "Space", callback_data: "key:space"},
        %{text: "Enter", callback_data: "key:enter"},
        %{text: "Quit", callback_data: "key:q"}
      ]
    ]
  end

  @doc """
  Builds an inline keyboard from a view tree by extracting button elements.

  Falls back to `default_keyboard/0` if no buttons are found.
  """
  @spec build_keyboard(map() | list() | nil) :: [[map()]]
  def build_keyboard(nil), do: default_keyboard()

  def build_keyboard(view_tree) do
    buttons = extract_buttons(view_tree, [])

    case buttons do
      [] ->
        default_keyboard()

      found ->
        button_row =
          found
          |> Enum.reverse()
          |> Enum.map(fn {label, id} ->
            %{text: label, callback_data: "btn:#{id}"}
          end)

        [button_row | default_keyboard()]
    end
  end

  @doc """
  Formats a complete Telegram message payload.

  Returns `{html_text, keyboard}` suitable for sending via Bot API.
  """
  @spec format_message(map(), map() | list() | nil) :: {String.t(), [[map()]]}
  def format_message(buffer, view_tree \\ nil) do
    html = buffer_to_html(buffer)
    keyboard = build_keyboard(view_tree)
    {html, keyboard}
  end

  @doc """
  Returns the default terminal dimensions for Telegram rendering.
  """
  @spec default_size() :: {pos_integer(), pos_integer()}
  def default_size, do: {@default_width, @default_height}

  # -- Private --

  defp extract_buttons(node, acc) when is_map(node) do
    acc =
      case node do
        %{type: :button, id: id, content: label} when is_binary(id) and is_binary(label) ->
          [{label, id} | acc]

        %{type: :button, id: id, attrs: %{label: label}}
        when is_binary(id) and is_binary(label) ->
          [{label, id} | acc]

        _ ->
          acc
      end

    children = Map.get(node, :children, [])

    if is_list(children) do
      Enum.reduce(children, acc, &extract_buttons/2)
    else
      acc
    end
  end

  defp extract_buttons(nodes, acc) when is_list(nodes) do
    Enum.reduce(nodes, acc, &extract_buttons/2)
  end

  defp extract_buttons(_, acc), do: acc

  defp trim_trailing_empty(lines) do
    lines
    |> Enum.reverse()
    |> Enum.drop_while(&(&1 == ""))
    |> Enum.reverse()
  end

  @doc """
  Escapes HTML entities for Telegram's HTML parse mode.
  """
  @spec escape_html(String.t()) :: String.t()
  def escape_html(text) do
    text
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
  end
end
