defmodule Raxol.HEEx.Components do
  @moduledoc """
  Terminal-specific components for HEEx templates.

  These components provide terminal equivalents of common HTML elements,
  with terminal-specific styling and behavior.
  """

  use Phoenix.Component

  @doc """
  Terminal box component - equivalent to HTML div with borders.
  """
  attr :padding, :integer, default: 0
  attr :border, :string, default: "none"
  attr :width, :integer, default: nil
  attr :height, :integer, default: nil
  attr :class, :string, default: ""
  attr(:rest, :global)
  slot(:inner_block, required: true)

  def terminal_box(assigns) do
    ~H"""
    <div class={"terminal-box #{@class}"} 
         data-padding={@padding}
         data-border={@border}
         data-width={@width}
         data-height={@height}
         {@rest}>
      <%= render_slot(@inner_block) %>
    </div>
    """
  end

  @doc """
  Terminal text component with ANSI color and style support.
  """
  attr :color, :string, default: "default"
  attr :background, :string, default: "default"
  attr :bold, :boolean, default: false
  attr :italic, :boolean, default: false
  attr :underline, :boolean, default: false
  attr :class, :string, default: ""
  attr(:rest, :global)
  slot(:inner_block, required: true)

  def terminal_text(assigns) do
    ~H"""
    <span class={"terminal-text #{@class}"}
          data-color={@color}
          data-background={@background}
          data-bold={@bold}
          data-italic={@italic}
          data-underline={@underline}
          {@rest}>
      <%= render_slot(@inner_block) %>
    </span>
    """
  end

  @doc """
  Terminal button component with keyboard navigation support.
  """
  attr :type, :string, default: "button"
  attr :class, :string, default: ""
  attr :disabled, :boolean, default: false
  attr :variant, :string, default: "default"
  attr :size, :string, default: "medium"
  attr :rest, :global, include: ~w(phx-click phx-value-*)
  slot(:inner_block, required: true)

  def terminal_button(assigns) do
    ~H"""
    <button class={"terminal-button #{@variant} #{@size} #{@class}"}
            type={@type}
            disabled={@disabled}
            {@rest}>
      <%= render_slot(@inner_block) %>
    </button>
    """
  end

  @doc """
  Terminal input field component.
  """
  attr :type, :string, default: "text"
  attr :name, :string, required: true
  attr :value, :string, default: ""
  attr :placeholder, :string, default: ""
  attr :disabled, :boolean, default: false
  attr :class, :string, default: ""
  attr :width, :integer, default: 20
  attr :rest, :global, include: ~w(phx-change phx-blur phx-focus)

  def terminal_input(assigns) do
    ~H"""
    <input class={"terminal-input #{@class}"}
           type={@type}
           name={@name}
           value={@value}
           placeholder={@placeholder}
           disabled={@disabled}
           data-width={@width}
           {@rest} />
    """
  end

  @doc """
  Terminal list component for displaying collections.
  """
  attr :items, :list, required: true
  attr :class, :string, default: ""
  attr :numbered, :boolean, default: false
  attr(:rest, :global)
  slot(:item, required: true)

  def terminal_list(assigns) do
    ~H"""
    <div class={"terminal-list #{@class}"} 
         data-numbered={@numbered}
         {@rest}>
      <%= for {item, index} <- Enum.with_index(@items) do %>
        <div class="terminal-list-item" data-index={index}>
          <%= render_slot(@item, item) %>
        </div>
      <% end %>
    </div>
    """
  end

  @doc """
  Terminal table component for tabular data.
  """
  attr :rows, :list, required: true
  attr :class, :string, default: ""
  attr :headers, :list, default: []
  attr(:rest, :global)

  slot :col, required: true do
    attr :field, :atom, required: true
    attr(:label, :string)
  end

  def terminal_table(assigns) do
    ~H"""
    <table class={"terminal-table #{@class}"} {@rest}>
      <%= if @headers != [] do %>
        <thead>
          <tr>
            <%= for header <- @headers do %>
              <th><%= header %></th>
            <% end %>
          </tr>
        </thead>
      <% end %>
      <tbody>
        <%= for row <- @rows do %>
          <tr>
            <%= for col <- @col do %>
              <td><%= render_slot(col, Map.get(row, col.field)) %></td>
            <% end %>
          </tr>
        <% end %>
      </tbody>
    </table>
    """
  end
end
