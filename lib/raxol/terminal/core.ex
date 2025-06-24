defmodule Raxol.Terminal.Core do
  @moduledoc """
  Core state struct for the terminal emulator. This struct holds the main state fields used by the emulator state management functions.
  """

  defstruct [
    :active_buffer_type,
    :mode_manager,
    :charset_state,
    :state,
    :memory_limit,
    :current_hyperlink_url,
    :tab_stops,
    :scroll_region,
    :saved_cursor,
    mounted: false,
    render_count: 0
  ]

  @type t :: %__MODULE__{
          active_buffer_type: any(),
          mode_manager: any(),
          charset_state: any(),
          state: any(),
          memory_limit: integer() | nil,
          current_hyperlink_url: String.t() | nil,
          tab_stops: any(),
          scroll_region: {non_neg_integer(), non_neg_integer()} | nil,
          saved_cursor: {non_neg_integer(), non_neg_integer()} | nil
        }
end
