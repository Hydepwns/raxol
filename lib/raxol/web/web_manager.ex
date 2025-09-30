defmodule Raxol.Web.WebManager do
  @moduledoc """
  Web manager for Raxol web interface.

  This is a minimal implementation providing basic web management functionality.
  """

  use Raxol.Core.Behaviours.BaseManager

  # BaseManager provides start_link/1 with proper option handling
  # The default name should be set via options when starting

  @impl Raxol.Core.Behaviours.BaseManager
  def init_manager(_opts) do
    {:ok, %{}}
  end

  # BaseManager provides default implementations for handle_manager_call,
  # handle_manager_cast, and handle_manager_info which handle unmatched messages
end
