defmodule Raxol.Terminal.Parser.StateBehaviour do
  @moduledoc """
  Defines the behaviour for parser states.
  """

  alias Raxol.Terminal.Emulator

  @type emulator :: Emulator.t()
  @type state :: any()

  @callback handle(emulator(), state(), binary()) ::
              {:continue, emulator(), state(), binary()}
              | {:finished, emulator(), state()}
              | {:incomplete, emulator(), state()}

  @callback handle_byte(byte(), emulator(), state()) ::
              {:ok, emulator(), state()} | {:error, atom(), emulator(), state()}

  @callback handle_escape(emulator(), state()) ::
              {:ok, emulator(), state()} | {:error, atom(), emulator(), state()}

  @callback handle_control_sequence(emulator(), state()) ::
              {:ok, emulator(), state()} | {:error, atom(), emulator(), state()}

  @callback handle_osc_string(emulator(), state()) ::
              {:ok, emulator(), state()} | {:error, atom(), emulator(), state()}

  @callback handle_dcs_string(emulator(), state()) ::
              {:ok, emulator(), state()} | {:error, atom(), emulator(), state()}

  @callback handle_apc_string(emulator(), state()) ::
              {:ok, emulator(), state()} | {:error, atom(), emulator(), state()}

  @callback handle_pm_string(emulator(), state()) ::
              {:ok, emulator(), state()} | {:error, atom(), emulator(), state()}

  @callback handle_sos_string(emulator(), state()) ::
              {:ok, emulator(), state()} | {:error, atom(), emulator(), state()}

  @callback handle_unknown(emulator(), state()) ::
              {:ok, emulator(), state()} | {:error, atom(), emulator(), state()}
end
