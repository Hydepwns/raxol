# TEA Counter in LiveView
#
# Runs the CounterExample TEA app in the browser via Phoenix LiveView.
#
# Setup:
#   1. Add to your router:
#
#      live "/counter", Raxol.LiveView.TEALive,
#        session: %{"app_module" => "Elixir.CounterExample"}
#
#   2. Or create a dedicated LiveView:
#
#      defmodule MyAppWeb.CounterLive do
#        use Phoenix.LiveView
#
#        @impl true
#        def mount(params, session, socket) do
#          Raxol.LiveView.TEALive.mount(params, session, socket,
#            app_module: CounterExample
#          )
#        end
#
#        @impl true
#        defdelegate handle_event(event, params, socket), to: Raxol.LiveView.TEALive
#
#        @impl true
#        defdelegate handle_info(msg, socket), to: Raxol.LiveView.TEALive
#
#        @impl true
#        defdelegate render(assigns), to: Raxol.LiveView.TEALive
#      end
#
#   3. Start Phoenix: mix phx.server
#   4. Visit http://localhost:4000/counter
#
# The same CounterExample module that runs in the terminal now runs
# in the browser -- same init/1, update/2, view/1 callbacks.
