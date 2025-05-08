# test/support/mock_plugin_behaviours.ex

defmodule Raxol.TestSupport.MockPluginBehaviour do
  @moduledoc false
  @callback id() :: atom
  @callback version() :: String.t()
  @callback init(Keyword.t()) :: {:ok, map} | {:error, any}
  @callback terminate(atom, map) :: any
  @callback get_commands() :: [{atom, function, non_neg_integer}]
end

defmodule Raxol.TestSupport.MockPluginMetadataProvider do
  @moduledoc false
  @callback metadata() :: map
end
