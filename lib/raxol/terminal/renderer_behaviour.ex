defmodule Raxol.Terminal.RendererBehaviour do
  @moduledoc """
  Behaviour for terminal renderer modules.
  """

  @callback render(renderer :: struct()) :: binary()
  @callback new(screen_buffer :: struct()) :: struct()
  @callback set_theme(renderer :: struct(), theme :: map()) :: struct()
end
