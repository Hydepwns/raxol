defmodule Raxol.SSH do
  @moduledoc """
  SSH app serving for Raxol TEA applications.

  Serves a TEA app over SSH so each connection gets its own
  isolated process running the full init/update/view lifecycle.

  ## Example

      Raxol.SSH.serve(MyApp, port: 2222)
      # Then: ssh localhost -p 2222
  """

  defdelegate serve(app_module, opts \\ []), to: Raxol.SSH.Server
end
