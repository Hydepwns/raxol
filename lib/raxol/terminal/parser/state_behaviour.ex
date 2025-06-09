defmodule Raxol.Terminal.Parser.StateBehaviour do
  @moduledoc """
  Behaviour for terminal parser states.
  """

  @type emulator :: Raxol.Terminal.Emulator.t()
  @type parser_state :: Raxol.Terminal.Parser.State.t()
  @type result ::
          {:continue, emulator(), parser_state(), binary()}
          | {:finished, emulator(), parser_state()}
          | {:incomplete, emulator(), parser_state()}
          | {:error, term(), emulator(), parser_state()}

  @callback handle(emulator(), parser_state(), binary()) :: result()
end
