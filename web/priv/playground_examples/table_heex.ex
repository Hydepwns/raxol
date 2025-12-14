# Raxol Table - Using HEEx Components
import Raxol.HEEx.Components

# Define your data
@data [
  %{name: "Alice", email: "alice@example.com", role: "Admin"},
  %{name: "Bob", email: "bob@example.com", role: "User"}
]

def render(assigns) do
  ~H"""
  <.terminal_box border="single" padding={1}>
    <table class="w-full">
      <thead>
        <tr class="border-b">
          <th class="text-left p-2">Name</th>
          <th class="text-left p-2">Email</th>
          <th class="text-left p-2">Role</th>
        </tr>
      </thead>
      <tbody>
        <%= for row <- @data do %>
          <tr class="border-b hover:bg-gray-50">
            <td class="p-2"><%= row.name %></td>
            <td class="p-2"><%= row.email %></td>
            <td class="p-2"><%= row.role %></td>
          </tr>
        <% end %>
      </tbody>
    </table>
  </.terminal_box>
  """
end

# For terminal-native tables:
# alias Raxol.UI.Components.Display.Table
#
# Table.new(%{
#   columns: [
#     %{key: :name, header: "Name", width: 20},
#     %{key: :email, header: "Email", width: 25}
#   ],
#   data: @data,
#   sortable: true,
#   striped: true
# })
