defmodule Raxol.Terminal.Input.Event do
  @moduledoc '''
  Defines the base event struct and common types for input events.
  '''

  @type modifier :: :shift | :ctrl | :alt | :meta
  @type timestamp :: integer()

  defstruct [:timestamp]

  defmodule MouseEvent do
    @moduledoc '''
    Represents a mouse input event.
    '''

    @type button :: :left | :middle | :right | :wheel_up | :wheel_down
    @type action :: :press | :release | :drag | :move

    defstruct [
      :button,
      :action,
      :x,
      :y,
      :modifiers,
      :timestamp
    ]

    @type t :: %__MODULE__{
            button: button(),
            action: action(),
            x: non_neg_integer(),
            y: non_neg_integer(),
            modifiers: [Raxol.Terminal.Input.Event.modifier()],
            timestamp: Raxol.Terminal.Input.Event.timestamp()
          }
  end

  defmodule KeyEvent do
    @moduledoc '''
    Represents a keyboard input event.
    '''

    defstruct [
      :key,
      :modifiers,
      :timestamp
    ]

    @type t :: %__MODULE__{
            key: String.t(),
            modifiers: [Raxol.Terminal.Input.Event.modifier()],
            timestamp: Raxol.Terminal.Input.Event.timestamp()
          }
  end

  @type t :: MouseEvent.t() | KeyEvent.t()
end
