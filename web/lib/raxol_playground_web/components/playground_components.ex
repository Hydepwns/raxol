defmodule RaxolPlaygroundWeb.PlaygroundComponents do
  @moduledoc "Shared UI components for the Raxol playground."
  use Phoenix.Component

  alias RaxolPlaygroundWeb.Playground.Helpers

  attr(:title, :string, required: true)

  def terminal_chrome(assigns) do
    ~H"""
    <div class="bg-gray-800 px-4 py-2 flex items-center space-x-2 border-b border-gray-700">
      <div class="w-3 h-3 bg-red-500 rounded-full" aria-hidden="true"></div>
      <div class="w-3 h-3 bg-yellow-500 rounded-full" aria-hidden="true"></div>
      <div class="w-3 h-3 bg-green-500 rounded-full" aria-hidden="true"></div>
      <span class="text-gray-400 text-sm ml-4"><%= @title %></span>
    </div>
    """
  end

  attr(:variant, :atom, default: :banner)
  attr(:class, :string, default: "")

  def ssh_callout(assigns) do
    assigns = Phoenix.Component.assign(assigns, :ssh_cmd, Helpers.ssh_command())

    ~H"""
    <div class={[
      "text-green-400 font-mono text-sm",
      @variant == :banner && "bg-gray-900 border border-gray-800 rounded-lg p-4",
      @variant == :footer && "bg-gray-900 px-6 py-3 border-t border-gray-700",
      @class
    ]}>
      <%= if @variant == :banner do %>
        Try the real terminal experience:
      <% else %>
        Try the real terminal:
      <% end %>
      <span class="text-white ml-2"><%= @ssh_cmd %></span>
      <span class="text-gray-500 mx-2">|</span>
      <span class="text-white">mix raxol.playground</span>
    </div>
    """
  end

  attr(:description, :string, default: nil)

  def terminal_fallback(assigns) do
    ~H"""
    <div class="text-gray-500 py-8 text-center">
      <%= if @description do %>
        <p class="mb-2 text-gray-400"><%= @description %></p>
      <% end %>
      <p class="mb-4">For the full interactive experience:</p>
      <p class="text-green-400">$ mix raxol.playground</p>
      <p class="text-green-400 mt-1">$ <%= Helpers.ssh_command() %></p>
    </div>
    """
  end

  attr(:show, :boolean, required: true)
  attr(:code, :string, default: "")

  def code_panel(assigns) do
    ~H"""
    <%= if @show do %>
      <div class="w-1/3 border-l bg-gray-900 flex flex-col">
        <div class="px-4 py-2 bg-gray-800 text-gray-300 text-sm font-medium border-b border-gray-700">
          Code Snippet
        </div>
        <div class="flex-1 overflow-auto p-4">
          <pre class="text-green-400 font-mono text-sm whitespace-pre-wrap"><%= String.trim(@code) %></pre>
        </div>
      </div>
    <% end %>
    """
  end

  attr(:theme, :atom, required: true)
  attr(:themes, :list, required: true)
  attr(:form_id, :string, required: true)
  attr(:class, :string, default: "")

  def theme_selector(assigns) do
    ~H"""
    <form phx-change="select_theme" id={@form_id} class={@class}>
      <select
        name="theme"
        aria-label="Terminal color theme"
        class="bg-gray-800 border border-gray-700 text-gray-100 rounded px-3 py-1 text-sm"
      >
        <%= for {key, label, _bg} <- @themes do %>
          <option value={key} selected={@theme == key}><%= label %></option>
        <% end %>
      </select>
    </form>
    """
  end

  attr(:level, :atom, required: true)

  def complexity_badge(assigns) do
    ~H"""
    <span class={"px-2 py-1 text-xs font-medium rounded-full #{Helpers.complexity_class(@level)}"}>
      <%= Helpers.complexity_label(@level) %>
    </span>
    """
  end
end
