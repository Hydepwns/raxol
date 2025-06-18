defmodule Raxol.UI.Components.Input.TextInput.Renderer do
  @moduledoc '''
  Handles rendering logic for the TextInput component.
  This includes display value formatting, style management, and visual feedback.
  '''

  use Phoenix.Component

  @doc '''
  Renders the text input component with appropriate styling and visual feedback.
  '''
  def render(assigns) do
    ~H'''
    <div class="text-input">
      <input
        type="text"
        value={@value}
        placeholder={@placeholder}
        class={[
          "text-input__field",
          @error && "text-input__field--error",
          @warning && "text-input__field--warning"
        ]}
        phx-keydown="keydown"
        phx-keyup="keyup"
        phx-blur="blur"
        phx-focus="focus"
      />
      <%= if @error do %>
        <div class="text-input__error">
          <%= @error %>
        </div>
      <% end %>
      <%= if @warning do %>
        <div class="text-input__warning">
          <%= @warning %>
        </div>
      <% end %>
    </div>
    '''
  end

  # Private helpers
end
