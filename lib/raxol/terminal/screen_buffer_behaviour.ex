defmodule Raxol.Terminal.ScreenBufferBehaviour do
  @moduledoc """
  Behaviour for terminal screen buffer operations.
  """

  alias Raxol.Terminal.ScreenBuffer
  alias Raxol.Terminal.ANSI.TextFormatting

  @callback get_dimensions(buffer :: ScreenBuffer.t()) ::
              {width :: non_neg_integer(), height :: non_neg_integer()}

  @callback new(
              width :: non_neg_integer(),
              height :: non_neg_integer(),
              scrollback_limit :: non_neg_integer()
            ) :: ScreenBuffer.t()

  @callback clear(
              buffer :: ScreenBuffer.t(),
              style :: TextFormatting.text_style()
            ) :: ScreenBuffer.t()

  @callback resize(
              buffer :: ScreenBuffer.t(),
              new_width :: non_neg_integer(),
              new_height :: non_neg_integer()
            ) :: ScreenBuffer.t()
end
