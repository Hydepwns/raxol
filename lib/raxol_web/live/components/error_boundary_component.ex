defmodule RaxolWeb.ErrorBoundaryComponent do
  use RaxolWeb, :live_component
  require Logger

  def render(assigns) do
    ~H"""
    <div class="error-boundary" id={@id}>
      <%= if @error do %>
        <div class="error-fallback bg-red-50 border border-red-200 rounded-lg p-4">
          <div class="flex items-center">
            <div class="flex-shrink-0">
              <svg class="h-5 w-5 text-red-400" viewBox="0 0 20 20" fill="currentColor">
                <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z" clip-rule="evenodd" />
              </svg>
            </div>
            <div class="ml-3">
              <h3 class="text-sm font-medium text-red-800">
                Something went wrong
              </h3>
              <div class="mt-2 text-sm text-red-700">
                <p>An unexpected error occurred. Please try again.</p>
              </div>
              <div class="mt-4">
                <button
                  type="button"
                  phx-click="retry"
                  phx-target={@myself}
                  class="bg-red-50 border border-red-200 rounded-md px-3 py-2 text-sm font-medium text-red-800 hover:bg-red-100 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-red-500"
                >
                  Retry
                </button>
              </div>
            </div>
          </div>
        </div>
      <% else %>
        <%= render_slot(@inner_block) %>
      <% end %>
    </div>
    """
  end

  def handle_event("retry", _, socket) do
    Logger.info(
      "Error boundary retry requested for component #{socket.assigns.id}"
    )

    {:noreply, assign(socket, error: nil)}
  end

  def handle_error(error, stacktrace, socket) do
    Logger.error(
      "Error boundary caught error: #{inspect(error)}\nStacktrace: #{inspect(stacktrace)}"
    )

    {:noreply, assign(socket, error: error)}
  end
end
