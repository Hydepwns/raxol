defmodule RaxolPlaygroundWeb.PlaygroundComponents do
  @moduledoc "Shared UI components for the Raxol playground."
  use Phoenix.Component

  alias RaxolPlaygroundWeb.Playground.Helpers

  attr(:title, :string, required: true)

  def terminal_chrome(assigns) do
    ~H"""
    <div class="terminal-chrome-bar">
      <div class="terminal-chrome-dot terminal-chrome-dot--red" aria-hidden="true"></div>
      <div class="terminal-chrome-dot terminal-chrome-dot--yellow" aria-hidden="true"></div>
      <div class="terminal-chrome-dot terminal-chrome-dot--green" aria-hidden="true"></div>
      <span class="terminal-chrome-title"><%= @title %></span>
    </div>
    """
  end

  attr(:variant, :atom, default: :banner)
  attr(:class, :string, default: "")

  def ssh_callout(assigns) do
    assigns = Phoenix.Component.assign(assigns, :ssh_cmd, Helpers.ssh_command())

    ~H"""
    <div class={[
      "font-mono text-sm",
      @variant == :banner && "panel p-4",
      @variant == :footer && "px-6 py-3",
      @class
    ]} style={"#{if @variant == :footer, do: "border-top: 1px solid rgba(168, 154, 128, 0.12); background: rgba(18, 18, 26, 0.85);", else: ""}"}>
      <span style="color: rgba(232, 228, 220, 0.5);">
        <%= if @variant == :banner do %>
          Try the real terminal experience:
        <% else %>
          Try the real terminal:
        <% end %>
      </span>
      <span style="color: #ffcd9c; margin-left: 0.5rem;"><%= @ssh_cmd %></span>
      <span style="color: rgba(232, 228, 220, 0.25); margin: 0 0.5rem;">|</span>
      <span style="color: #58a1c6;">mix raxol.playground</span>
    </div>
    """
  end

  attr(:description, :string, default: nil)

  def terminal_fallback(assigns) do
    ~H"""
    <div class="py-8 text-center font-mono" style="color: rgba(232, 228, 220, 0.4);">
      <%= if @description do %>
        <p class="mb-2" style="color: rgba(232, 228, 220, 0.5);"><%= @description %></p>
      <% end %>
      <p class="mb-4">For the full interactive experience:</p>
      <p style="color: #58a1c6;">$ mix raxol.playground</p>
      <p class="mt-1" style="color: #ffcd9c;">$ <%= Helpers.ssh_command() %></p>
    </div>
    """
  end

  attr(:show, :boolean, required: true)
  attr(:code, :string, default: "")

  def code_panel(assigns) do
    ~H"""
    <%= if @show do %>
      <div class="w-full lg:w-1/3 border-t lg:border-t-0 flex flex-col max-h-64 lg:max-h-none" style="border-color: rgba(168, 154, 128, 0.12); background: rgba(10, 10, 12, 0.85);">
        <div class="px-4 py-2 text-sm font-mono font-medium" style="color: rgba(232, 228, 220, 0.6); background: rgba(18, 18, 26, 0.95); border-bottom: 1px solid rgba(168, 154, 128, 0.12);">
          Code Snippet
        </div>
        <div class="flex-1 overflow-auto p-4">
          <pre class="font-mono text-sm whitespace-pre-wrap" style="color: #58a1c6;"><%= String.trim(@code) %></pre>
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
        class="font-mono px-3 py-1 text-sm rounded"
        style="background: rgba(18, 18, 26, 0.85); border: 1px solid rgba(168, 154, 128, 0.12); color: #e8e4dc;"
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
    <span class={"badge #{complexity_badge_variant(@level)}"}>
      <%= Helpers.complexity_label(@level) %>
    </span>
    """
  end

  @doc "Copyable command block with click-to-copy button."
  attr(:command, :string, required: true)
  attr(:comment, :string, default: nil)
  attr(:color, :string, default: "#ffcd9c")
  attr(:id, :string, required: true)

  def copyable_command(assigns) do
    ~H"""
    <div class="terminal-chrome relative group" style="padding: 0;">
      <div class="terminal-chrome-body flex items-center justify-between" style="padding: 0.75rem 1.25rem;">
        <div>
          <span style="color: rgba(232, 228, 220, 0.35);">$</span>
          <span style={"color: #{@color}; margin-left: 0.5rem;"}><%= @command %></span>
          <%= if @comment do %>
            <span style="color: rgba(232, 228, 220, 0.25); margin-left: 1rem;"># <%= @comment %></span>
          <% end %>
        </div>
        <button
          id={@id}
          phx-hook="CopyToClipboard"
          data-copy={@command}
          class="opacity-0 group-hover:opacity-100 transition-opacity font-mono cursor-pointer"
          style="font-size: clamp(0.55rem, 0.5rem + 0.25vw, 0.65rem); color: rgba(232, 228, 220, 0.35); background: none; border: 1px solid rgba(168, 154, 128, 0.12); padding: 0.2rem 0.5rem; border-radius: 3px; text-transform: uppercase; letter-spacing: 0.1em;"
          aria-label={"Copy command: #{@command}"}
        >
          copy
        </button>
      </div>
    </div>
    """
  end

  defp complexity_badge_variant(:basic), do: "badge--sky"
  defp complexity_badge_variant(:intermediate), do: "badge--gold"
  defp complexity_badge_variant(:advanced), do: ""
  defp complexity_badge_variant(_), do: "badge--gold"
end
