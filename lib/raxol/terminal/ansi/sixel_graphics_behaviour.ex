defmodule Raxol.Terminal.ANSI.SixelGraphics.Behaviour do
  @moduledoc '''
  Behaviour for Sixel graphics support.
  '''

  @type t :: %{
          width: non_neg_integer(),
          height: non_neg_integer(),
          data: binary(),
          palette: map(),
          scale: {non_neg_integer(), non_neg_integer()},
          position: {non_neg_integer(), non_neg_integer()}
        }

  @callback new() :: t()
  @callback new(non_neg_integer(), non_neg_integer()) :: t()
  @callback set_data(t(), binary()) :: t()
  @callback get_data(t()) :: binary()
  @callback set_palette(t(), map()) :: t()
  @callback get_palette(t()) :: map()
  @callback set_scale(t(), non_neg_integer(), non_neg_integer()) :: t()
  @callback get_scale(t()) :: {non_neg_integer(), non_neg_integer()}
  @callback set_position(t(), non_neg_integer(), non_neg_integer()) :: t()
  @callback get_position(t()) :: {non_neg_integer(), non_neg_integer()}
  @callback encode(t()) :: binary()
  @callback decode(binary()) :: t()
  @callback supported?() :: boolean()
  @callback process_sequence(t(), binary()) :: t()
end
