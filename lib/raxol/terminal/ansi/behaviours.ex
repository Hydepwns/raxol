defmodule Raxol.Terminal.ANSI.Behaviours do
  @moduledoc """
  Consolidated ANSI behaviours for terminal functionality.
  Consolidates: SixelGraphics.Behaviour, TerminalStateBehaviour, TextFormattingBehaviour.
  """

  defmodule SixelGraphics do
    @moduledoc """
    Behaviour for Sixel graphics support.
    """

    @type t :: %{
            width: non_neg_integer(),
            height: non_neg_integer(),
            data: binary(),
            palette: map(),
            scale: {non_neg_integer(), non_neg_integer()},
            position: {non_neg_integer(), non_neg_integer()}
          }

    @callback new() :: t()
    @callback new(pos_integer(), pos_integer()) :: t()
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

  defmodule TerminalState do
    @moduledoc """
    Behaviour for managing terminal state saving and restoring.
    """

    alias Raxol.Terminal.Emulator
    alias Raxol.Terminal.ANSI.TerminalState

    # Represents the map of state data from restore_state
    @type state_data_map :: map()

    @callback save_state(
                stack :: TerminalState.state_stack(),
                current_emulator_state :: map()
              ) :: TerminalState.state_stack()

    @callback restore_state(stack :: TerminalState.state_stack()) ::
                {new_stack :: TerminalState.state_stack(),
                 state_data :: state_data_map() | nil}

    @callback apply_restored_data(
                emulator_state :: Emulator.t(),
                state_data :: state_data_map() | nil,
                fields_to_restore :: list(atom())
              ) :: Emulator.t()
  end

  defmodule TextFormatting do
    @moduledoc """
    Defines the behaviour for text formatting in the terminal.
    This includes handling text attributes, colors, and special text modes.
    """

    @type color ::
            :black
            | :red
            | :green
            | :yellow
            | :blue
            | :magenta
            | :cyan
            | :white
            | {:rgb, non_neg_integer(), non_neg_integer(), non_neg_integer()}
            | {:index, non_neg_integer()}
            | nil

    @type text_style :: %{
            double_width: boolean(),
            double_height: :none | :top | :bottom,
            bold: boolean(),
            faint: boolean(),
            italic: boolean(),
            underline: boolean(),
            blink: boolean(),
            reverse: boolean(),
            conceal: boolean(),
            strikethrough: boolean(),
            fraktur: boolean(),
            double_underline: boolean(),
            framed: boolean(),
            encircled: boolean(),
            overlined: boolean(),
            foreground: color(),
            background: color(),
            hyperlink: String.t() | nil
          }

    @callback new() :: text_style()
    @callback set_foreground(text_style(), color()) :: text_style()
    @callback set_background(text_style(), color()) :: text_style()
    @callback get_foreground(text_style()) :: color()
    @callback get_background(text_style()) :: color()
    @callback set_double_width(text_style()) :: text_style()
    @callback set_double_height_top(text_style()) :: text_style()
    @callback set_double_height_bottom(text_style()) :: text_style()
    @callback reset_size(text_style()) :: text_style()
    @callback apply_attribute(text_style(), atom()) :: text_style()
    @callback set_bold(text_style()) :: text_style()
    @callback set_faint(text_style()) :: text_style()
    @callback set_italic(text_style()) :: text_style()
    @callback set_underline(text_style()) :: text_style()
    @callback set_blink(text_style()) :: text_style()
    @callback set_reverse(text_style()) :: text_style()
    @callback set_conceal(text_style()) :: text_style()
    @callback set_strikethrough(text_style()) :: text_style()
    @callback set_fraktur(text_style()) :: text_style()
    @callback set_double_underline(text_style()) :: text_style()
    @callback set_framed(text_style()) :: text_style()
    @callback set_encircled(text_style()) :: text_style()
    @callback set_overlined(text_style()) :: text_style()
    @callback set_hyperlink(text_style(), String.t() | nil) :: text_style()
    @callback reset_attributes(text_style()) :: text_style()
    @callback set_attributes(text_style(), list(atom())) :: text_style()
    @callback set_custom(text_style(), atom(), any()) :: text_style()
    @callback update_attrs(text_style(), map()) :: text_style()
    @callback validate(text_style()) ::
                {:ok, text_style()} | {:error, String.t()}
    @callback reset_bold(text_style()) :: text_style()
    @callback reset_italic(text_style()) :: text_style()
    @callback reset_underline(text_style()) :: text_style()
    @callback reset_blink(text_style()) :: text_style()
    @callback reset_reverse(text_style()) :: text_style()
    @callback reset_framed_encircled(text_style()) :: text_style()
    @callback reset_overlined(text_style()) :: text_style()
  end

  # Note: Use Raxol.Terminal.ANSI.TextFormatting directly for actual text formatting operations.
  # This module only defines the behaviour contracts.
end
