use Raxol.UI, framework: :liveview

def mount(_params, _session, socket) do
  {:ok, assign(socket,
    label: "Click Me",
    count: 0,
    disabled: false
  )}
end

def handle_event("click", _params, socket) do
  new_count = socket.assigns.count + 1
  {:noreply, assign(socket, :count, new_count)}
end

def render(assigns) do
  ~H"""
  <button
    phx-click="click"
    disabled={@disabled}
    class="btn btn-primary"
  >
    <%= @label %> (Clicked: <%= @count %>)
  </button>
  """
end
