defmodule Raxol.Terminal.Emulator.Style.Behaviour do
  @moduledoc """
  Defines the behaviour for terminal emulator style management.
  This includes handling text attributes, colors, and text formatting.
  """

  alias Raxol.Terminal.Emulator.Struct, as: EmulatorStruct

  @type color :: {0..255, 0..255, 0..255} | :default
  @type decoration :: :none | :underline | :double_underline | :overline | :strikethrough
  @type intensity :: :normal | :bold | :faint
  @type blink :: :none | :slow | :rapid

  @callback set_attributes(EmulatorStruct.t(), list()) ::
              {:ok, EmulatorStruct.t()} | {:error, String.t()}

  @callback set_foreground(EmulatorStruct.t(), atom() | tuple()) ::
              {:ok, EmulatorStruct.t()} | {:error, String.t()}

  @callback set_background(EmulatorStruct.t(), atom() | tuple()) ::
              {:ok, EmulatorStruct.t()} | {:error, String.t()}

  @callback reset_attributes(EmulatorStruct.t()) :: {:ok, EmulatorStruct.t()}

  @callback set_intensity(EmulatorStruct.t(), intensity()) ::
              {:ok, EmulatorStruct.t()} | {:error, String.t()}

  @callback set_decoration(EmulatorStruct.t(), decoration()) ::
              {:ok, EmulatorStruct.t()} | {:error, String.t()}

  @callback set_blink(EmulatorStruct.t(), blink()) ::
              {:ok, EmulatorStruct.t()} | {:error, String.t()}
end
