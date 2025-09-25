defmodule Raxol.Core.Runtime.Rendering.Engine.Behaviour do
  @moduledoc """
  Behavior for rendering engines.
  """

  @doc """
  Renders a view to output.
  """
  @callback render(view :: term(), context :: term()) ::
              {:ok, term()} | {:error, term()}

  @doc """
  Initializes the rendering engine.
  """
  @callback init(opts :: keyword()) :: {:ok, term()} | {:error, term()}

  @doc """
  Terminates the rendering engine.
  """
  @callback terminate(state :: term()) :: :ok
end
