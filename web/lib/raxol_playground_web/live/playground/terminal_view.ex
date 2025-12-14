defmodule RaxolPlaygroundWeb.Playground.TerminalView do
  @moduledoc """
  Terminal view rendering for the Raxol playground.
  These render ASCII-styled terminal representations of each component.
  Supports multiple color themes.
  """

  use Phoenix.Component

  # Theme color palettes using Tailwind arbitrary values
  @theme_colors %{
    dracula: %{
      fg: "text-[#f8f8f2]",
      comment: "text-[#6272a4]",
      border: "text-[#44475a]",
      cyan: "text-[#8be9fd]",
      green: "text-[#50fa7b]",
      orange: "text-[#ffb86c]",
      pink: "text-[#ff79c6]",
      purple: "text-[#bd93f9]",
      red: "text-[#ff5555]",
      yellow: "text-[#f1fa8c]",
      selection: "bg-[#44475a]"
    },
    nord: %{
      fg: "text-[#eceff4]",
      comment: "text-[#4c566a]",
      border: "text-[#3b4252]",
      cyan: "text-[#88c0d0]",
      green: "text-[#a3be8c]",
      orange: "text-[#d08770]",
      pink: "text-[#b48ead]",
      purple: "text-[#b48ead]",
      red: "text-[#bf616a]",
      yellow: "text-[#ebcb8b]",
      selection: "bg-[#434c5e]"
    },
    monokai: %{
      fg: "text-[#f8f8f2]",
      comment: "text-[#75715e]",
      border: "text-[#49483e]",
      cyan: "text-[#66d9ef]",
      green: "text-[#a6e22e]",
      orange: "text-[#fd971f]",
      pink: "text-[#f92672]",
      purple: "text-[#ae81ff]",
      red: "text-[#f92672]",
      yellow: "text-[#e6db74]",
      selection: "bg-[#49483e]"
    },
    solarized_dark: %{
      fg: "text-[#839496]",
      comment: "text-[#586e75]",
      border: "text-[#073642]",
      cyan: "text-[#2aa198]",
      green: "text-[#859900]",
      orange: "text-[#cb4b16]",
      pink: "text-[#d33682]",
      purple: "text-[#6c71c4]",
      red: "text-[#dc322f]",
      yellow: "text-[#b58900]",
      selection: "bg-[#073642]"
    },
    solarized_light: %{
      fg: "text-[#657b83]",
      comment: "text-[#93a1a1]",
      border: "text-[#eee8d5]",
      cyan: "text-[#2aa198]",
      green: "text-[#859900]",
      orange: "text-[#cb4b16]",
      pink: "text-[#d33682]",
      purple: "text-[#6c71c4]",
      red: "text-[#dc322f]",
      yellow: "text-[#b58900]",
      selection: "bg-[#eee8d5]"
    },
    synthwave84: %{
      fg: "text-[#ffffff]",
      comment: "text-[#848bbd]",
      border: "text-[#2a2139]",
      cyan: "text-[#36f9f6]",
      green: "text-[#72f1b8]",
      orange: "text-[#ff8b39]",
      pink: "text-[#ff7edb]",
      purple: "text-[#ff7edb]",
      red: "text-[#fe4450]",
      yellow: "text-[#fede5d]",
      selection: "bg-[#2a2139]"
    },
    gruvbox_dark: %{
      fg: "text-[#ebdbb2]",
      comment: "text-[#928374]",
      border: "text-[#3c3836]",
      cyan: "text-[#8ec07c]",
      green: "text-[#b8bb26]",
      orange: "text-[#fe8019]",
      pink: "text-[#d3869b]",
      purple: "text-[#d3869b]",
      red: "text-[#fb4934]",
      yellow: "text-[#fabd2f]",
      selection: "bg-[#3c3836]"
    },
    one_dark: %{
      fg: "text-[#abb2bf]",
      comment: "text-[#5c6370]",
      border: "text-[#3e4451]",
      cyan: "text-[#56b6c2]",
      green: "text-[#98c379]",
      orange: "text-[#d19a66]",
      pink: "text-[#c678dd]",
      purple: "text-[#c678dd]",
      red: "text-[#e06c75]",
      yellow: "text-[#e5c07b]",
      selection: "bg-[#3e4451]"
    },
    tokyo_night: %{
      fg: "text-[#c0caf5]",
      comment: "text-[#565f89]",
      border: "text-[#292e42]",
      cyan: "text-[#7dcfff]",
      green: "text-[#9ece6a]",
      orange: "text-[#ff9e64]",
      pink: "text-[#bb9af7]",
      purple: "text-[#bb9af7]",
      red: "text-[#f7768e]",
      yellow: "text-[#e0af68]",
      selection: "bg-[#292e42]"
    },
    catppuccin: %{
      fg: "text-[#cdd6f4]",
      comment: "text-[#6c7086]",
      border: "text-[#313244]",
      cyan: "text-[#89dceb]",
      green: "text-[#a6e3a1]",
      orange: "text-[#fab387]",
      pink: "text-[#f5c2e7]",
      purple: "text-[#cba6f7]",
      red: "text-[#f38ba8]",
      yellow: "text-[#f9e2af]",
      selection: "bg-[#313244]"
    }
  }

  @doc """
  Returns the color palette for a given theme.
  """
  def get_colors(theme) do
    Map.get(@theme_colors, theme, @theme_colors.dracula)
  end

  @doc """
  Renders the appropriate terminal view based on the selected component.
  """
  def render_terminal_demo(assigns) do
    theme = Map.get(assigns, :terminal_theme, :dracula)
    colors = get_colors(theme)
    assigns = assign(assigns, :c, colors)

    case assigns.selected_component && assigns.selected_component.name do
      "Button" -> terminal_button(assigns)
      "TextInput" -> terminal_text_input(assigns)
      "Progress" -> terminal_progress(assigns)
      "Table" -> terminal_table(assigns)
      "Modal" -> terminal_modal(assigns)
      "Menu" -> terminal_menu(assigns)
      _ -> terminal_generic(assigns)
    end
  end

  def terminal_button(assigns) do
    ~H"""
    <pre class={"font-mono text-sm #{@c.green} leading-relaxed"}>
    <span class={@c.border}>+---------------------------+</span>
    <span class={@c.border}>|</span> <span class={@c.cyan}>[</span><span class={"#{@c.fg} #{@c.selection} px-2"}> Click Me </span><span class={@c.cyan}>]</span>  Clicks: <span class={@c.yellow}><%= @demo_state.button_clicks %></span> <span class={@c.border}>|</span>
    <span class={@c.border}>+---------------------------+</span>

    <span class={@c.comment}># Button variants:</span>
    <span class={@c.cyan}>[</span><span class={@c.purple}> Primary </span><span class={@c.cyan}>]</span> <span class={@c.cyan}>[</span><span class={@c.comment}> Secondary </span><span class={@c.cyan}>]</span>
    <span class={@c.cyan}>[</span><span class={@c.green}> Success </span><span class={@c.cyan}>]</span> <span class={@c.cyan}>[</span><span class={@c.red}> Danger </span><span class={@c.cyan}>]</span>
    </pre>
    """
  end

  def terminal_text_input(assigns) do
    value = assigns.demo_state.input_value
    display_value = if value == "", do: "Type something...", else: value
    cursor = if value == "", do: "", else: "_"

    assigns = assign(assigns, display_value: display_value, cursor: cursor)

    ~H"""
    <pre class={"font-mono text-sm #{@c.green} leading-relaxed"}>
    <span class={@c.comment}># Text Input</span>
    <span class={@c.border}>+--------------------------------+</span>
    <span class={@c.border}>|</span> <span class={if @demo_state.input_value == "", do: @c.comment, else: @c.fg}><%= @display_value %></span><span class={"#{@c.green} animate-pulse"}><%= @cursor %></span><span class={@c.border}> |</span>
    <span class={@c.border}>+--------------------------------+</span>

    <span class={@c.comment}># Current value:</span>
    <span class={@c.yellow}>"<%= @demo_state.input_value %>"</span>
    <span class={@c.comment}># Length: <%= String.length(@demo_state.input_value) %> chars</span>
    </pre>
    """
  end

  def terminal_progress(assigns) do
    filled = round(assigns.demo_state.progress_value / 100 * 30)
    empty = 30 - filled
    bar = String.duplicate("=", filled) <> String.duplicate("-", empty)

    assigns = assign(assigns, bar: bar)

    ~H"""
    <pre class={"font-mono text-sm #{@c.green} leading-relaxed"}>
    <span class={@c.comment}># Progress Bar</span>
    <span class={@c.border}>[</span><span class={@c.green}><%= @bar %></span><span class={@c.border}>]</span> <span class={@c.yellow}><%= @demo_state.progress_value %>%</span>

    <span class={@c.comment}># Visual representation:</span>
    <span class={@c.cyan}>Progress:</span> <span class={@c.fg}><%= String.duplicate("#", round(@demo_state.progress_value / 5)) %></span><span class={@c.comment}><%= String.duplicate(".", 20 - round(@demo_state.progress_value / 5)) %></span>
    </pre>
    """
  end

  def terminal_table(assigns) do
    ~H"""
    <pre class={"font-mono text-sm #{@c.green} leading-relaxed"}>
    <span class={@c.comment}># Data Table</span>
    <span class={@c.border}>+----------------+--------------------+--------+</span>
    <span class={@c.border}>|</span> <span class={@c.cyan}>Name</span>           <span class={@c.border}>|</span> <span class={@c.cyan}>Email</span>              <span class={@c.border}>|</span> <span class={@c.cyan}>Role</span>   <span class={@c.border}>|</span>
    <span class={@c.border}>+----------------+--------------------+--------+</span>
    <span class={@c.border}>|</span> <span class={@c.fg}>Alice Johnson</span>  <span class={@c.border}>|</span> <span class={@c.comment}>alice@example.com</span> <span class={@c.border}>|</span> <span class={@c.purple}>Admin</span>  <span class={@c.border}>|</span>
    <span class={@c.border}>|</span> <span class={@c.fg}>Bob Smith</span>      <span class={@c.border}>|</span> <span class={@c.comment}>bob@example.com</span>   <span class={@c.border}>|</span> <span class={@c.comment}>User</span>   <span class={@c.border}>|</span>
    <span class={@c.border}>|</span> <span class={@c.fg}>Carol White</span>    <span class={@c.border}>|</span> <span class={@c.comment}>carol@example.com</span> <span class={@c.border}>|</span> <span class={@c.cyan}>Editor</span> <span class={@c.border}>|</span>
    <span class={@c.border}>+----------------+--------------------+--------+</span>

    <span class={@c.comment}># Sort: <%= @demo_state.table_sort_column || "none" %> (<%= @demo_state.table_sort_direction %>)</span>
    </pre>
    """
  end

  def terminal_modal(assigns) do
    ~H"""
    <pre class={"font-mono text-sm #{@c.green} leading-relaxed"}>
    <span class={@c.comment}># Modal Dialog</span>
    <%= if @demo_state.modal_open do %>
    <span class={@c.border}>+==============================+</span>
    <span class={@c.border}>|</span>  <span class={"#{@c.cyan} font-bold"}>Modal Title</span>                 <span class={@c.border}>|</span>
    <span class={@c.border}>+------------------------------+</span>
    <span class={@c.border}>|</span>                              <span class={@c.border}>|</span>
    <span class={@c.border}>|</span>  <span class={@c.fg}>This is a modal dialog.</span>    <span class={@c.border}>|</span>
    <span class={@c.border}>|</span>  <span class={@c.fg}>Click to close.</span>            <span class={@c.border}>|</span>
    <span class={@c.border}>|</span>                              <span class={@c.border}>|</span>
    <span class={@c.border}>|</span>  <span class={@c.comment}>[Cancel]</span> <span class={@c.cyan}>[Confirm]</span>         <span class={@c.border}>|</span>
    <span class={@c.border}>+==============================+</span>
    <% else %>
    <span class={@c.comment}>(Modal is closed)</span>
    <span class={@c.border}>[</span><span class={@c.cyan}> Open Modal </span><span class={@c.border}>]</span>
    <% end %>
    </pre>
    """
  end

  def terminal_menu(assigns) do
    ~H"""
    <pre class={"font-mono text-sm #{@c.green} leading-relaxed"}>
    <span class={@c.comment}># Menu Bar</span>
    <span class={@c.border}>+------+------+------+------+</span>
    <span class={@c.border}>|</span><%= menu_item(assigns, "File") %><span class={@c.border}>|</span><%= menu_item(assigns, "Edit") %><span class={@c.border}>|</span><%= menu_item(assigns, "View") %><span class={@c.border}>|</span><%= menu_item(assigns, "Help") %><span class={@c.border}>|</span>
    <span class={@c.border}>+------+------+------+------+</span>

    <span class={@c.comment}># Selected: </span><span class={@c.yellow}><%= @demo_state.selected_menu_item || "None" %></span>
    </pre>
    """
  end

  defp menu_item(assigns, item) do
    is_selected = assigns.demo_state.selected_menu_item == item
    class = if is_selected, do: "#{assigns.c.selection} #{assigns.c.fg}", else: assigns.c.fg

    assigns = assign(assigns, item: item, class: class)

    ~H"""
    <span class={@class}> <%= @item %> </span>
    """
  end

  def terminal_generic(assigns) do
    ~H"""
    <pre class={"font-mono text-sm #{@c.green} leading-relaxed"}>
    <span class={@c.comment}># Raxol Terminal View</span>
    <span class={@c.comment}># Select a component to see</span>
    <span class={@c.comment}># its terminal representation.</span>

    <span class={@c.cyan}>$</span> <span class={@c.fg}>raxol --help</span>
    </pre>
    """
  end
end
