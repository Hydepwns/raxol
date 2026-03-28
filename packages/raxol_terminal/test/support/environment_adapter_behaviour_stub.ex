unless Code.ensure_loaded?(Raxol.System.EnvironmentAdapterBehaviour) do
  defmodule Raxol.System.EnvironmentAdapterBehaviour do
    @moduledoc false
    @callback get_env(variable :: String.t()) :: String.t() | nil
    @callback cmd(
                command :: String.t(),
                args :: [String.t()],
                options :: Keyword.t()
              ) :: {String.t(), non_neg_integer()} | {:error, any()}
  end
end
