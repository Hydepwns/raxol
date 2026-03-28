defmodule Raxol.Component do
  @moduledoc """
  Thin wrapper around `Raxol.UI.Components.Base.Component`.

  For TEA-based applications (the recommended pattern), use
  `use Raxol.Core.Runtime.Application` instead. See the
  [Quickstart](docs/getting-started/QUICKSTART.md).

  This module is kept for backwards compatibility with existing code that
  uses `use Raxol.Component` for stateful widget components.
  """

  @deprecated "Use Raxol.UI.Components.Base.Component directly, or use Raxol.Core.Runtime.Application for TEA apps"

  defmacro __using__(opts) do
    quote do
      use Raxol.UI.Components.Base.Component, unquote(opts)
    end
  end
end
