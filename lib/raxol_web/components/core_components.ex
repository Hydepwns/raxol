defmodule RaxolWeb.CoreComponents do
  @moduledoc """
  Provides core UI components for the Raxol web interface.
  """

  use Phoenix.Component

  @doc """
  Renders a button with the given text and options.
  """
  attr :type, :string, default: "button"
  attr :class, :string, default: nil
  attr :disabled, :boolean, default: false
  attr :rest, :global, include: ~w(form name value)
  slot(:inner_block, required: true)

  def button(assigns) do
    ~H"""
    <button
      type={@type}
      class={[
        "px-4 py-2 rounded-lg font-semibold text-sm",
        "bg-primary-600 text-white hover:bg-primary-700",
        "focus:outline-none focus:ring-2 focus:ring-primary-500 focus:ring-offset-2",
        "disabled:opacity-50 disabled:cursor-not-allowed",
        @class
      ]}
      disabled={@disabled}
      {@rest}
    >
      <%= render_slot(@inner_block) %>
    </button>
    """
  end

  @doc """
  Renders a form input with the given type and options.
  """
  attr :type, :string, default: "text"
  attr :name, :string, required: true
  attr(:value, :any)
  attr :placeholder, :string, default: nil
  attr :class, :string, default: nil
  attr :disabled, :boolean, default: false
  attr :min, :string, default: nil
  attr :max, :string, default: nil
  attr :step, :string, default: nil
  attr :rest, :global, include: ~w(autocomplete form required)

  def input(assigns) do
    ~H"""
    <input
      type={@type}
      name={@name}
      value={@value}
      placeholder={@placeholder}
      class={[
        "block w-full rounded-lg border-gray-300 shadow-sm",
        "focus:border-primary-500 focus:ring-primary-500",
        "disabled:opacity-50 disabled:cursor-not-allowed",
        @class
      ]}
      disabled={@disabled}
      min={@min}
      max={@max}
      step={@step}
      {@rest}
    />
    """
  end

  @doc """
  Renders a label for a form input.
  """
  attr :for, :string, required: true
  attr :class, :string, default: nil
  slot(:inner_block, required: true)

  def label(assigns) do
    ~H"""
    <label
      for={@for}
      class={[
        "block text-sm font-medium text-gray-700",
        @class
      ]}
    >
      <%= render_slot(@inner_block) %>
    </label>
    """
  end

  @doc """
  Renders a form group with a label and input.
  """
  attr :name, :string, required: true
  attr :label, :string, required: true
  attr :type, :string, default: "text"
  attr(:value, :any)
  attr :placeholder, :string, default: nil
  attr :class, :string, default: nil
  attr :disabled, :boolean, default: false
  attr :min, :string, default: nil
  attr :max, :string, default: nil
  attr :step, :string, default: nil
  attr :rest, :global, include: ~w(autocomplete form required)

  def form_group(assigns) do
    ~H"""
    <div class={["space-y-1", @class]}>
      <.label for={@name}><%= @label %></.label>
      <.input
        type={@type}
        name={@name}
        value={@value}
        placeholder={@placeholder}
        disabled={@disabled}
        min={@min}
        max={@max}
        step={@step}
        {@rest}
      />
    </div>
    """
  end

  @doc """
  Renders a flash message.
  """
  attr :kind, :string, required: true
  attr :title, :string, default: nil
  attr :rest, :global, include: ~w(phx-click phx-value)
  slot(:inner_block, required: true)

  def flash(assigns) do
    ~H"""
    <div
      role="alert"
      class={[
        "rounded-lg p-4",
        @kind == "info" && "bg-blue-50 text-blue-800",
        @kind == "error" && "bg-red-50 text-red-800",
        @kind == "success" && "bg-green-50 text-green-800",
        @kind == "warning" && "bg-yellow-50 text-yellow-800"
      ]}
      {@rest}
    >
      <%= if @title do %>
        <h3 class="text-sm font-medium"><%= @title %></h3>
      <% end %>
      <div class="mt-2 text-sm">
        <%= render_slot(@inner_block) %>
      </div>
    </div>
    """
  end
end
