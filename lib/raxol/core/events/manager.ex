defmodule Raxol.Core.Events.Manager do
  @moduledoc """
  Alias module for Raxol.Core.Events.EventManager.

  This provides backward compatibility for code that references 
  Raxol.Core.Events.Manager instead of Raxol.Core.Events.EventManager.
  """

  # Delegate all functions to EventManager
  defdelegate start_link(opts \\ []), to: Raxol.Core.Events.EventManager
  defdelegate init(), to: Raxol.Core.Events.EventManager

  defdelegate notify(event_type, data, opts \\ []),
    to: Raxol.Core.Events.EventManager

  defdelegate register_handler(event_types, target, handler),
    to: Raxol.Core.Events.EventManager

  defdelegate unregister_handler(event_types, target, handler),
    to: Raxol.Core.Events.EventManager

  defdelegate subscribe(event_types, opts \\ []),
    to: Raxol.Core.Events.EventManager

  defdelegate unsubscribe(subscription_ref), to: Raxol.Core.Events.EventManager
end
