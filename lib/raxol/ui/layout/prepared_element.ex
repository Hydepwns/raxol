defmodule Raxol.UI.Layout.PreparedElement do
  @moduledoc """
  An element with pre-computed text measurements.

  Inspired by Pretext's two-phase prepare/layout architecture: the expensive
  text measurement step (prepare) is separated from the cheap position
  arithmetic step (layout). PreparedElements carry cached measurements
  so that re-layout on resize only needs arithmetic, not re-measurement.
  """

  defstruct [
    :type,
    :element,
    :measured_width,
    :measured_height,
    :children,
    :content_hash
  ]

  @type t :: %__MODULE__{
          type: atom(),
          element: map(),
          measured_width: non_neg_integer(),
          measured_height: non_neg_integer(),
          children: [t()] | nil,
          content_hash: integer() | nil
        }
end
