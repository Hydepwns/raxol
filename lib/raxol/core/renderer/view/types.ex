defmodule Raxol.Core.Renderer.View.Types do
  @moduledoc """
  Type definitions for the Raxol view system.
  """

  alias Raxol.Core.Renderer.Color

  @type position :: {non_neg_integer(), non_neg_integer()}
  @type size :: {non_neg_integer(), non_neg_integer()}
  @type color :: Color.color()
  @type style :: [atom()]
  @type border_style :: :none | :single | :double | :rounded | :bold | :dashed
  @type layout_type :: :flex | :grid | :flow | :absolute
  @type position_type :: :relative | :absolute | :fixed
  @type z_index :: integer()

  @type view :: %{
          type: atom(),
          position: position() | nil,
          position_type: position_type(),
          z_index: z_index(),
          size: size() | nil,
          style: style(),
          fg: color() | nil,
          bg: color() | nil,
          border: border_style(),
          padding: padding(),
          margin: margin(),
          children: [view()],
          content: term()
        }

  @type padding ::
          non_neg_integer()
          | {non_neg_integer(), non_neg_integer()}
          | {non_neg_integer(), non_neg_integer(), non_neg_integer(),
             non_neg_integer()}
  @type margin :: padding()

  @doc """
  Returns the border characters for different border styles.
  """
  def border_chars do
    %{
      single: %{
        top_left: "┌",
        top_right: "┐",
        bottom_left: "└",
        bottom_right: "┘",
        horizontal: "─",
        vertical: "│"
      },
      double: %{
        top_left: "╔",
        top_right: "╗",
        bottom_left: "╚",
        bottom_right: "╝",
        horizontal: "═",
        vertical: "║"
      },
      rounded: %{
        top_left: "╭",
        top_right: "╮",
        bottom_left: "╰",
        bottom_right: "╯",
        horizontal: "─",
        vertical: "│"
      },
      bold: %{
        top_left: "┏",
        top_right: "┓",
        bottom_left: "┗",
        bottom_right: "┛",
        horizontal: "━",
        vertical: "┃"
      },
      dashed: %{
        top_left: "┌",
        top_right: "┐",
        bottom_left: "└",
        bottom_right: "┘",
        horizontal: "┄",
        vertical: "┆"
      }
    }
  end
end
