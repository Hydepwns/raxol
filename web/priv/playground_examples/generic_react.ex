use Raxol.UI, framework: :react

def render(assigns) do
  ~H"""
  <div>
    Component: <%= @component_name %>
  </div>
  """
end
