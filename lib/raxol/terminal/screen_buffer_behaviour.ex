defmodule Raxol.Terminal.ScreenBufferBehaviour do
  @moduledoc """
  Defines the behaviour for screen buffer implementations.
  This behaviour specifies the required callbacks for any module that implements
  screen buffer functionality.
  """

  alias Raxol.Terminal.ANSI.TextFormatting

  @type t :: term()
  @type text_style :: TextFormatting.text_style()

  @callback new(non_neg_integer(), non_neg_integer(), non_neg_integer()) :: t()
  @callback resize(t(), non_neg_integer(), non_neg_integer()) :: t()
  @callback write_char(t(), non_neg_integer(), non_neg_integer(), String.t(), text_style() | nil) :: t()
  @callback write_string(t(), non_neg_integer(), non_neg_integer(), String.t(), text_style() | nil) :: t()
  @callback get_char(t(), non_neg_integer(), non_neg_integer()) :: String.t()
  @callback get_cell(t(), non_neg_integer(), non_neg_integer()) :: term()
  @callback clear(t(), text_style() | nil) :: t()
  @callback clear_line(t(), non_neg_integer(), text_style() | nil) :: t()
  @callback insert_lines(t(), non_neg_integer()) :: t()
  @callback delete_lines(t(), non_neg_integer()) :: t()
  @callback insert_chars(t(), non_neg_integer()) :: t()
  @callback delete_chars(t(), non_neg_integer()) :: t()
  @callback erase_chars(t(), non_neg_integer()) :: t()
  @callback scroll_up(t(), non_neg_integer()) :: t()
  @callback scroll_down(t(), non_neg_integer()) :: t()
  @callback get_dimensions(t()) :: {non_neg_integer(), non_neg_integer()}
  @callback get_width(t()) :: non_neg_integer()
  @callback get_height(t()) :: non_neg_integer()
end
