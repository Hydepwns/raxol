defmodule Raxol.Core.Clipboard.Behaviour do
  @moduledoc '''
  Behaviour for clipboard operations.
  '''

  @doc '''
  Copies text to the clipboard.
  '''
  @callback copy(content :: String.t()) :: :ok | {:error, any()}

  @doc '''
  Pastes text from the clipboard.
  '''
  @callback paste() :: {:ok, String.t()} | {:error, any()}
end
