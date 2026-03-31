defmodule Raxol.Core.ErrorHandler do
  @moduledoc """
  Deprecated. Use `Raxol.Core.ErrorHandling` instead.

  All functions have been consolidated into `Raxol.Core.ErrorHandling`.
  This module delegates to it for backwards compatibility.
  """

  @doc false
  defmacro with_error_handling(operation, opts \\ [], do: block) do
    quote do
      Raxol.Core.ErrorHandling.execute_with_handling(
        unquote(operation),
        unquote(opts),
        fn -> unquote(block) end
      )
    end
  end

  @deprecated "Use Raxol.Core.ErrorHandling.execute_with_handling/3 instead"
  defdelegate execute_with_handling(operation, opts, fun), to: Raxol.Core.ErrorHandling

  @deprecated "Use Raxol.Core.ErrorHandling.error/3 instead"
  defdelegate error(type, message, context \\ %{}), to: Raxol.Core.ErrorHandling

  @deprecated "Use Raxol.Core.ErrorHandling.handle_error/2 instead"
  defdelegate handle_error(result, opts), to: Raxol.Core.ErrorHandling

  @deprecated "Use Raxol.Core.ErrorHandling.normalize_error/1 instead"
  defdelegate normalize_error(error), to: Raxol.Core.ErrorHandling

  @deprecated "Use Raxol.Core.ErrorHandling.log_error/4 instead"
  defdelegate log_error(operation, error, context \\ %{}, severity \\ :error),
    to: Raxol.Core.ErrorHandling

  @deprecated "Use Raxol.Core.ErrorHandling.execute_pipeline/1 instead"
  defdelegate execute_pipeline(steps), to: Raxol.Core.ErrorHandling

  @deprecated "Use Raxol.Core.ErrorHandling.handle_genserver_error/3 instead"
  defdelegate handle_genserver_error(error, state, module), to: Raxol.Core.ErrorHandling
end
