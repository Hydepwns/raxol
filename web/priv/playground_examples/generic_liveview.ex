use Raxol.UI, framework: :liveview

def mount(_params, _session, socket) do
  {:ok, assign(socket, component_name: "MyComponent")}
end

def render(assigns) do
  ~H"""
  <div>
    Component: <%= @component_name %>
  </div>
  """
end
