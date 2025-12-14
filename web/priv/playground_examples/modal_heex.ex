# Raxol Modal - LiveView Implementation
import Raxol.HEEx.Components

def mount(_params, _session, socket) do
  {:ok, assign(socket, modal_open: false)}
end

def handle_event("open_modal", _, socket) do
  {:noreply, assign(socket, modal_open: true)}
end

def handle_event("close_modal", _, socket) do
  {:noreply, assign(socket, modal_open: false)}
end

def render(assigns) do
  ~H"""
  <.terminal_button phx-click="open_modal" role="primary">
    Open Modal
  </.terminal_button>

  <%= if @modal_open do %>
    <div class="fixed inset-0 bg-black/50 flex items-center justify-center">
      <.terminal_box border="double" padding={3}>
        <.terminal_column gap={2}>
          <.terminal_text bold color="cyan">Confirm Action</.terminal_text>
          <.terminal_text>Are you sure you want to proceed?</.terminal_text>
          <.terminal_row gap={2}>
            <.terminal_button phx-click="close_modal" role="secondary">
              Cancel
            </.terminal_button>
            <.terminal_button phx-click="confirm" role="primary">
              Confirm
            </.terminal_button>
          </.terminal_row>
        </.terminal_column>
      </.terminal_box>
    </div>
  <% end %>
  """
end

# Terminal-native modal:
# alias Raxol.UI.Components.Modal
# Modal.alert("Title", "Message")
# Modal.confirm("Are you sure?", on_confirm: fn -> ... end)
