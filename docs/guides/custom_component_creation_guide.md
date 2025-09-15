# Custom Component Creation Guide

## Overview

This guide walks you through creating custom Raxol components from scratch, covering everything from basic stateless components to complex interactive widgets with advanced features.

## Quick Start

### Creating Your First Component

```bash
# Generate component scaffolding
mix raxol.gen.component MyButton --framework react

# This creates:
# - lib/raxol/ui/components/my_button.ex
# - test/raxol/ui/components/my_button_test.exs
# - examples/components/my_button_example.ex
```

### Basic Component Structure

```elixir
defmodule Raxol.UI.Components.MyButton do
  @moduledoc """
  A customizable button component with multiple variants and states.
  """
  
  use Raxol.UI, framework: :react
  import Raxol.LiveView, only: [assign: 2, assign: 3, assign_new: 2, update: 3]
  
  @doc """
  Button component with extensive customization options.
  
  ## Props
  - `:variant` - Button style (`:primary`, `:secondary`, `:danger`)
  - `:size` - Button size (`:small`, `:medium`, `:large`)  
  - `:disabled` - Whether button is disabled
  - `:loading` - Show loading spinner
  - `:full_width` - Expand to full container width
  
  ## Examples
  
      <.my_button variant="primary" size="large">
        Save Changes
      </.my_button>
      
      <.my_button variant="danger" loading={true}>
        Delete Account
      </.my_button>
  """
  def my_button(assigns) do
    assigns = 
      assigns
      |> assign_new(:variant, fn -> "primary" end)
      |> assign_new(:size, fn -> "medium" end)
      |> assign_new(:disabled, fn -> false end)
      |> assign_new(:loading, fn -> false end)
      |> assign_new(:full_width, fn -> false end)
      |> assign(:button_classes, build_button_classes(assigns))
    
    ~H"""
    <button 
      type="button"
      class={@button_classes}
      disabled={@disabled or @loading}
      {@rest}
    >
      <%= if @loading do %>
        <.spinner class="inline w-4 h-4 mr-2" />
      <% end %>
      <%= render_slot(@inner_block) %>
    </button>
    """
  end
  
  defp build_button_classes(assigns) do
    base_classes = "inline-flex items-center justify-center font-medium rounded-md transition-colors focus:outline-none focus:ring-2 focus:ring-offset-2"
    
    variant_classes = case assigns[:variant] do
      "primary" -> "bg-blue-600 text-white hover:bg-blue-700 focus:ring-blue-500"
      "secondary" -> "bg-gray-200 text-gray-900 hover:bg-gray-300 focus:ring-gray-500"
      "danger" -> "bg-red-600 text-white hover:bg-red-700 focus:ring-red-500"
      _ -> "bg-gray-100 text-gray-900 hover:bg-gray-200 focus:ring-gray-500"
    end
    
    size_classes = case assigns[:size] do
      "small" -> "px-2 py-1 text-sm"
      "medium" -> "px-4 py-2 text-base"
      "large" -> "px-6 py-3 text-lg"
      _ -> "px-4 py-2 text-base"
    end
    
    width_classes = if assigns[:full_width], do: "w-full", else: ""
    
    disabled_classes = if assigns[:disabled] or assigns[:loading] do
      "opacity-50 cursor-not-allowed"
    else
      "cursor-pointer"
    end
    
    [base_classes, variant_classes, size_classes, width_classes, disabled_classes]
    |> Enum.join(" ")
    |> String.trim()
  end
end
```

## Advanced Component Patterns

### Stateful Component with Hooks

```elixir
defmodule Raxol.UI.Components.SearchInput do
  use Raxol.UI, framework: :react
  import Raxol.LiveView, only: [assign: 2, assign: 3, assign_new: 2, update: 3]
  
  def mount(_params, _session, socket) do
    socket = 
      socket
      |> assign(:query, "")
      |> assign(:suggestions, [])
      |> assign(:loading, false)
      |> assign(:focused, false)
      |> assign(:debounce_ref, nil)
    
    {:ok, socket}
  end
  
  def search_input(assigns) do
    assigns = assign_new(assigns, :placeholder, fn -> "Search..." end)
    
    ~H"""
    <div class="relative">
      <.form 
        for={%{}}
        as={:search}
        phx-change="search_change"
        phx-submit="search_submit"
        phx-target={@myself}
        autocomplete="off"
      >
        <input 
          type="text"
          name="query"
          value={@query}
          placeholder={@placeholder}
          phx-focus="search_focus"
          phx-blur="search_blur"
          phx-target={@myself}
          class="w-full px-4 py-2 border border-gray-300 rounded-md focus:ring-2 focus:ring-blue-500 focus:border-transparent"
        />
        
        <%= if @loading do %>
          <.spinner class="absolute right-3 top-3 w-4 h-4" />
        <% end %>
      </.form>
      
      <%= if @focused and length(@suggestions) > 0 do %>
        <.search_suggestions suggestions={@suggestions} target={@myself} />
      <% end %>
    </div>
    """
  end
  
  def handle_event("search_change", %{"search" => %{"query" => query}}, socket) do
    # Cancel previous debounce
    if socket.assigns.debounce_ref do
      Process.cancel_timer(socket.assigns.debounce_ref)
    end
    
    # Debounce search requests
    debounce_ref = Process.send_after(self(), {:perform_search, query}, 300)
    
    socket = 
      socket
      |> assign(:query, query)
      |> assign(:debounce_ref, debounce_ref)
      |> assign(:loading, query != "")
    
    {:noreply, socket}
  end
  
  def handle_event("search_focus", _params, socket) do
    {:noreply, assign(socket, :focused, true)}
  end
  
  def handle_event("search_blur", _params, socket) do
    # Delay blur to allow suggestion clicks
    Process.send_after(self(), :delayed_blur, 100)
    {:noreply, socket}
  end
  
  def handle_info({:perform_search, query}, socket) do
    suggestions = if String.length(query) >= 2 do
      search_suggestions(query)
    else
      []
    end
    
    socket = 
      socket
      |> assign(:suggestions, suggestions)
      |> assign(:loading, false)
      |> assign(:debounce_ref, nil)
    
    {:noreply, socket}
  end
  
  def handle_info(:delayed_blur, socket) do
    {:noreply, assign(socket, :focused, false)}
  end
  
  defp search_suggestions(query) do
    # Implement your search logic here
    # This could call an external service, search a database, etc.
    []
  end
end
```

### Component with Slots and Dynamic Content

```elixir
defmodule Raxol.UI.Components.Card do
  use Raxol.UI, framework: :react
  import Raxol.LiveView, only: [assign: 2, assign: 3, assign_new: 2, update: 3]
  
  @doc """
  Flexible card component with multiple slots for complex layouts.
  
  ## Slots
  - `:header` - Card header content
  - `:body` - Main card content  
  - `:footer` - Card footer content
  - `:actions` - Action buttons area
  
  ## Examples
  
      <.card>
        <:header>
          <h3>Card Title</h3>
        </:header>
        
        <:body>
          <p>Card content goes here</p>
        </:body>
        
        <:actions>
          <.button variant="primary">Save</button>
          <.button variant="secondary">Cancel</button>
        </:actions>
      </.card>
  """
  def card(assigns) do
    assigns = 
      assigns
      |> assign_new(:class, fn -> "" end)
      |> assign_new(:padding, fn -> "p-6" end)
      |> assign(:card_classes, build_card_classes(assigns))
    
    ~H"""
    <div class={@card_classes}>
      <%= if slot_assigned?(@header) do %>
        <div class="card-header border-b border-gray-200 pb-4 mb-4">
          <%= render_slot(@header) %>
        </div>
      <% end %>
      
      <div class="card-body">
        <%= if slot_assigned?(@body) do %>
          <%= render_slot(@body) %>
        <% else %>
          <%= render_slot(@inner_block) %>
        <% end %>
      </div>
      
      <%= if slot_assigned?(@footer) or slot_assigned?(@actions) do %>
        <div class="card-footer border-t border-gray-200 pt-4 mt-4">
          <%= if slot_assigned?(@footer) do %>
            <div class="footer-content">
              <%= render_slot(@footer) %>
            </div>
          <% end %>
          
          <%= if slot_assigned?(@actions) do %>
            <div class="actions flex justify-end space-x-2">
              <%= render_slot(@actions) %>
            </div>
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end
  
  defp build_card_classes(assigns) do
    base_classes = "bg-white rounded-lg border border-gray-200 shadow-sm"
    padding_classes = assigns[:padding] || "p-6"
    custom_classes = assigns[:class] || ""
    
    [base_classes, padding_classes, custom_classes]
    |> Enum.join(" ")
    |> String.trim()
  end
  
  defp slot_assigned?(slot) do
    slot != [] and slot != nil
  end
end
```

## Multi-Framework Support

### Creating Framework-Agnostic Components

```elixir
defmodule Raxol.UI.Components.DataTable do
  @moduledoc """
  Universal data table component that works across all Raxol frameworks.
  """
  
  # Import all framework modules
  use Raxol.UI, framework: :react
  use Raxol.UI, framework: :svelte  
  use Raxol.UI, framework: :liveview
  use Raxol.UI, framework: :heex
  
  @doc """
  Framework-agnostic data table implementation.
  """
  def data_table(assigns) do
    assigns = normalize_data_table_assigns(assigns)
    
    case get_framework(assigns) do
      :react -> data_table_react(assigns)
      :svelte -> data_table_svelte(assigns)
      :liveview -> data_table_liveview(assigns)
      :heex -> data_table_heex(assigns)
      :raw -> data_table_raw(assigns)
    end
  end
  
  # React implementation
  defp data_table_react(assigns) do
    ~H"""
    <div class="data-table-container">
      <table class="min-w-full divide-y divide-gray-200">
        <thead class="bg-gray-50">
          <tr>
            <%= for column <- @columns do %>
              <th 
                class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider"
                onClick={() => handleSort('<%= column.key %>')}
              >
                <%= column.title %>
                <%= if @sort_column == column.key do %>
                  <.sort_icon direction={@sort_direction} />
                <% end %>
              </th>
            <% end %>
          </tr>
        </thead>
        <tbody class="bg-white divide-y divide-gray-200">
          <%= for row <- @data do %>
            <tr class="hover:bg-gray-50">
              <%= for column <- @columns do %>
                <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                  <%= render_cell_value(row, column) %>
                </td>
              <% end %>
            </tr>
          <% end %>
        </tbody>
      </table>
    </div>
    """
  end
  
  # Svelte implementation
  defp data_table_svelte(assigns) do
    ~H"""
    <div class="data-table-container">
      <table class="min-w-full divide-y divide-gray-200">
        <thead class="bg-gray-50">
          <tr>
            {#each columns as column}
              <th 
                class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider"
                on:click={() => handleSort(column.key)}
              >
                {column.title}
                {#if sortColumn === column.key}
                  <SortIcon direction={sortDirection} />
                {/if}
              </th>
            {/each}
          </tr>
        </thead>
        <tbody class="bg-white divide-y divide-gray-200">
          {#each data as row}
            <tr class="hover:bg-gray-50">
              {#each columns as column}
                <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                  {@html renderCellValue(row, column)}
                </td>
              {/each}
            </tr>
          {/each}
        </tbody>
      </table>
    </div>
    """
  end
  
  # LiveView implementation  
  defp data_table_liveview(assigns) do
    ~H"""
    <div class="data-table-container">
      <table class="min-w-full divide-y divide-gray-200">
        <thead class="bg-gray-50">
          <tr>
            <%= for column <- @columns do %>
              <th 
                class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider cursor-pointer"
                phx-click="sort"
                phx-value-column={column.key}
              >
                <%= column.title %>
                <%= if @sort_column == column.key do %>
                  <.sort_icon direction={@sort_direction} />
                <% end %>
              </th>
            <% end %>
          </tr>
        </thead>
        <tbody class="bg-white divide-y divide-gray-200" phx-update="stream" id="table-rows">
          <%= for {dom_id, row} <- @streams.data do %>
            <tr id={dom_id} class="hover:bg-gray-50">
              <%= for column <- @columns do %>
                <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                  <%= render_cell_value(row, column) %>
                </td>
              <% end %>
            </tr>
          <% end %>
        </tbody>
      </table>
    </div>
    """
  end
  
  defp normalize_data_table_assigns(assigns) do
    assigns
    |> assign_new(:columns, fn -> [] end)
    |> assign_new(:data, fn -> [] end)
    |> assign_new(:sort_column, fn -> nil end)
    |> assign_new(:sort_direction, fn -> :asc end)
    |> assign_new(:loading, fn -> false end)
  end
  
  defp render_cell_value(row, column) do
    case column.render do
      nil -> Map.get(row, column.key, "")
      render_func when is_function(render_func) -> render_func.(row)
      template -> Phoenix.HTML.raw(EEx.eval_string(template, assigns: [row: row]))
    end
  end
end
```

## Component Testing

### Comprehensive Test Suite

```elixir
defmodule Raxol.UI.Components.MyButtonTest do
  use Raxol.TestCase, async: true
  
  import Raxol.UI.Components.MyButton
  
  describe "my_button/1" do
    test "renders with default props" do
      html = 
        render_component(&my_button/1, %{}, do: "Click me")
        |> rendered_to_string()
      
      assert html =~ "Click me"
      assert html =~ "bg-blue-600" # primary variant default
      assert html =~ "px-4 py-2"   # medium size default
      refute html =~ "opacity-50"  # not disabled
      refute html =~ "cursor-not-allowed"
    end
    
    test "applies variant classes correctly" do
      for variant <- ["primary", "secondary", "danger"] do
        html = 
          render_component(&my_button/1, %{variant: variant}, do: "Test")
          |> rendered_to_string()
          
        case variant do
          "primary" -> assert html =~ "bg-blue-600"
          "secondary" -> assert html =~ "bg-gray-200"  
          "danger" -> assert html =~ "bg-red-600"
        end
      end
    end
    
    test "handles disabled state" do
      html = 
        render_component(&my_button/1, %{disabled: true}, do: "Disabled")
        |> rendered_to_string()
        
      assert html =~ "disabled"
      assert html =~ "opacity-50"
      assert html =~ "cursor-not-allowed"
    end
    
    test "shows loading state" do
      html = 
        render_component(&my_button/1, %{loading: true}, do: "Loading")
        |> rendered_to_string()
        
      assert html =~ "disabled"
      assert html =~ "spinner"
    end
    
    test "applies full width styling" do
      html = 
        render_component(&my_button/1, %{full_width: true}, do: "Full Width")
        |> rendered_to_string()
        
      assert html =~ "w-full"
    end
    
    test "passes through additional attributes" do
      html = 
        render_component(&my_button/1, %{
          "data-testid": "my-button",
          "aria-label": "Custom button"
        }, do: "Custom")
        |> rendered_to_string()
        
      assert html =~ ~s(data-testid="my-button")
      assert html =~ ~s(aria-label="Custom button")
    end
  end
  
  describe "accessibility" do
    test "has proper ARIA attributes" do
      html = 
        render_component(&my_button/1, %{disabled: true}, do: "Disabled Button")
        |> rendered_to_string()
        
      assert html =~ ~s(role="button")
      assert html =~ ~s(disabled)
      
      # Test with screen reader
      assert_accessible(html)
    end
    
    test "supports keyboard navigation" do
      {:ok, view, _html} = live_isolated_component(&my_button/1, %{})
      
      # Test focus and blur
      assert render_focus(view, "button") =~ "focus:ring-2"
      assert render_blur(view, "button")
    end
  end
  
  describe "performance" do
    test "renders efficiently with large datasets" do
      {time, _result} = :timer.tc(fn ->
        for _i <- 1..1000 do
          render_component(&my_button/1, %{}, do: "Button")
        end
      end)
      
      # Should render 1000 buttons in less than 100ms
      assert time < 100_000
    end
    
    test "class computation is optimized" do
      assigns = %{variant: "primary", size: "large", disabled: false}
      
      {time, classes} = :timer.tc(fn ->
        MyButton.build_button_classes(assigns)
      end)
      
      assert time < 10  # microseconds
      assert is_binary(classes)
      assert String.contains?(classes, "bg-blue-600")
    end
  end
end
```

## Component Documentation

### Interactive Documentation

```elixir
defmodule Raxol.UI.Components.MyButton.Docs do
  @moduledoc """
  Interactive documentation and examples for MyButton component.
  """
  
  use Raxol.UI, framework: :liveview
  import Raxol.LiveView, only: [assign: 2, assign: 3, assign_new: 2, update: 3]
  
  def mount(_params, _session, socket) do
    socket = 
      socket
      |> assign(:selected_variant, "primary")
      |> assign(:selected_size, "medium")
      |> assign(:disabled, false)
      |> assign(:loading, false)
      |> assign(:full_width, false)
      
    {:ok, socket}
  end
  
  def render(assigns) do
    ~H"""
    <div class="component-docs">
      <header class="mb-8">
        <h1 class="text-3xl font-bold mb-2">MyButton Component</h1>
        <p class="text-gray-600">
          A versatile button component with multiple variants, sizes, and states.
        </p>
      </header>
      
      <section class="playground mb-8">
        <h2 class="text-2xl font-semibold mb-4">Interactive Playground</h2>
        
        <div class="grid grid-cols-1 lg:grid-cols-2 gap-8">
          <div class="controls">
            <h3 class="text-lg font-medium mb-3">Controls</h3>
            
            <.form for={%{}} as={:button_config} phx-change="update_config">
              <div class="space-y-4">
                <div>
                  <label class="block text-sm font-medium mb-2">Variant</label>
                  <select name="variant" value={@selected_variant} class="form-select">
                    <option value="primary">Primary</option>
                    <option value="secondary">Secondary</option>
                    <option value="danger">Danger</option>
                  </select>
                </div>
                
                <div>
                  <label class="block text-sm font-medium mb-2">Size</label>
                  <select name="size" value={@selected_size} class="form-select">
                    <option value="small">Small</option>
                    <option value="medium">Medium</option>
                    <option value="large">Large</option>
                  </select>
                </div>
                
                <div class="space-y-2">
                  <label class="flex items-center">
                    <input 
                      type="checkbox" 
                      name="disabled" 
                      checked={@disabled}
                      class="form-checkbox"
                    />
                    <span class="ml-2">Disabled</span>
                  </label>
                  
                  <label class="flex items-center">
                    <input 
                      type="checkbox" 
                      name="loading" 
                      checked={@loading}
                      class="form-checkbox"
                    />
                    <span class="ml-2">Loading</span>
                  </label>
                  
                  <label class="flex items-center">
                    <input 
                      type="checkbox" 
                      name="full_width" 
                      checked={@full_width}
                      class="form-checkbox"
                    />
                    <span class="ml-2">Full Width</span>
                  </label>
                </div>
              </div>
            </.form>
          </div>
          
          <div class="preview">
            <h3 class="text-lg font-medium mb-3">Preview</h3>
            
            <div class="p-6 bg-gray-50 rounded-lg">
              <Raxol.UI.Components.MyButton.my_button 
                variant={@selected_variant}
                size={@selected_size}
                disabled={@disabled}
                loading={@loading}
                full_width={@full_width}
              >
                Click me!
              </Raxol.UI.Components.MyButton.my_button>
            </div>
            
            <div class="mt-4">
              <h4 class="text-md font-medium mb-2">Generated Code</h4>
              <pre class="bg-gray-900 text-green-400 p-4 rounded text-sm overflow-auto"><code><%= generate_code_example(assigns) %></code></pre>
            </div>
          </div>
        </div>
      </section>
      
      <section class="examples mb-8">
        <h2 class="text-2xl font-semibold mb-4">Common Examples</h2>
        
        <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
          <.example_card title="Call to Action">
            <Raxol.UI.Components.MyButton.my_button variant="primary" size="large">
              Get Started
            </Raxol.UI.Components.MyButton.my_button>
            
            <:code>
              <.my_button variant="primary" size="large">
                Get Started
              </.my_button>
            </:code>
          </.example_card>
          
          <.example_card title="Form Actions">
            <div class="space-x-2">
              <Raxol.UI.Components.MyButton.my_button variant="primary">
                Save
              </Raxol.UI.Components.MyButton.my_button>
              <Raxol.UI.Components.MyButton.my_button variant="secondary">
                Cancel
              </Raxol.UI.Components.MyButton.my_button>
            </div>
            
            <:code>
              <.my_button variant="primary">Save</.my_button>
              <.my_button variant="secondary">Cancel</.my_button>
            </:code>
          </.example_card>
          
          <.example_card title="Loading State">
            <Raxol.UI.Components.MyButton.my_button variant="primary" loading={true}>
              Processing...
            </Raxol.UI.Components.MyButton.my_button>
            
            <:code>
              <.my_button variant="primary" loading={true}>
                Processing...
              </.my_button>
            </:code>
          </.example_card>
        </div>
      </section>
      
      <section class="api-reference">
        <h2 class="text-2xl font-semibold mb-4">API Reference</h2>
        
        <div class="overflow-x-auto">
          <table class="min-w-full divide-y divide-gray-200">
            <thead class="bg-gray-50">
              <tr>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Prop</th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Type</th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Default</th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Description</th>
              </tr>
            </thead>
            <tbody class="bg-white divide-y divide-gray-200">
              <tr>
                <td class="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900">variant</td>
                <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">"primary" | "secondary" | "danger"</td>
                <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">"primary"</td>
                <td class="px-6 py-4 text-sm text-gray-500">Visual style of the button</td>
              </tr>
              <tr>
                <td class="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900">size</td>
                <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">"small" | "medium" | "large"</td>
                <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">"medium"</td>
                <td class="px-6 py-4 text-sm text-gray-500">Size of the button</td>
              </tr>
              <tr>
                <td class="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900">disabled</td>
                <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">boolean</td>
                <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">false</td>
                <td class="px-6 py-4 text-sm text-gray-500">Whether the button is disabled</td>
              </tr>
              <tr>
                <td class="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900">loading</td>
                <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">boolean</td>
                <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">false</td>
                <td class="px-6 py-4 text-sm text-gray-500">Show loading spinner and disable button</td>
              </tr>
              <tr>
                <td class="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900">full_width</td>
                <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">boolean</td>
                <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">false</td>
                <td class="px-6 py-4 text-sm text-gray-500">Expand button to full container width</td>
              </tr>
            </tbody>
          </table>
        </div>
      </section>
    </div>
    """
  end
  
  def handle_event("update_config", params, socket) do
    config = params["button_config"] || %{}
    
    socket = 
      socket
      |> assign(:selected_variant, config["variant"] || "primary")
      |> assign(:selected_size, config["size"] || "medium")
      |> assign(:disabled, config["disabled"] == "true")
      |> assign(:loading, config["loading"] == "true")
      |> assign(:full_width, config["full_width"] == "true")
      
    {:noreply, socket}
  end
  
  defp generate_code_example(assigns) do
    props = []
    
    props = if assigns.selected_variant != "primary" do
      [~s(variant="#{assigns.selected_variant}") | props]
    else
      props
    end
    
    props = if assigns.selected_size != "medium" do
      [~s(size="#{assigns.selected_size}") | props]
    else
      props
    end
    
    props = if assigns.disabled, do: ["disabled={true}" | props], else: props
    props = if assigns.loading, do: ["loading={true}" | props], else: props
    props = if assigns.full_width, do: ["full_width={true}" | props], else: props
    
    props_string = 
      if length(props) > 0 do
        " " <> Enum.join(props, " ")
      else
        ""
      end
    
    """
    <.my_button#{props_string}>
      Click me!
    </.my_button>
    """
  end
end
```

## Component Library Organization

### File Structure

```
lib/raxol/ui/components/
├── base/                    # Basic building blocks
│   ├── button.ex
│   ├── input.ex
│   ├── card.ex
│   └── modal.ex
├── display/                 # Display components
│   ├── table.ex
│   ├── list.ex
│   ├── avatar.ex
│   └── badge.ex
├── forms/                   # Form components
│   ├── form.ex
│   ├── field_group.ex
│   ├── select.ex
│   └── checkbox.ex
├── layout/                  # Layout components
│   ├── container.ex
│   ├── grid.ex
│   ├── sidebar.ex
│   └── navbar.ex
├── feedback/                # User feedback
│   ├── alert.ex
│   ├── toast.ex
│   ├── spinner.ex
│   └── progress.ex
└── specialized/             # Domain-specific
    ├── calendar.ex
    ├── code_editor.ex
    ├── file_upload.ex
    └── chart.ex
```

### Component Registry

```elixir
defmodule Raxol.UI.ComponentRegistry do
  @moduledoc """
  Central registry for all Raxol components with metadata and examples.
  """
  
  @components %{
    # Base Components
    button: %{
      module: Raxol.UI.Components.Button,
      category: :base,
      description: "Versatile button component with multiple variants",
      tags: [:interactive, :form, :action],
      examples: [:primary, :secondary, :loading],
      props: [:variant, :size, :disabled, :loading, :full_width]
    },
    
    input: %{
      module: Raxol.UI.Components.Input,
      category: :base, 
      description: "Form input with validation and styling",
      tags: [:form, :validation, :text],
      examples: [:text, :email, :password, :validation],
      props: [:type, :placeholder, :required, :disabled, :error]
    },
    
    # Display Components  
    table: %{
      module: Raxol.UI.Components.Table,
      category: :display,
      description: "Data table with sorting, filtering, and pagination",
      tags: [:data, :sorting, :pagination],
      examples: [:basic, :sortable, :filterable, :paginated],
      props: [:data, :columns, :sortable, :filterable, :page_size]
    },
    
    # Specialized Components
    code_editor: %{
      module: Raxol.UI.Components.CodeEditor,
      category: :specialized,
      description: "Syntax-highlighted code editor with vim bindings",
      tags: [:code, :editor, :syntax, :vim],
      examples: [:basic, :vim_mode, :syntax_highlighting],
      props: [:language, :theme, :vim_mode, :line_numbers, :readonly]
    }
  }
  
  @doc "Get all registered components"
  def all_components, do: @components
  
  @doc "Get components by category"
  def by_category(category) do
    Enum.filter(@components, fn {_key, meta} ->
      meta.category == category
    end)
  end
  
  @doc "Search components by tag"
  def by_tag(tag) do
    Enum.filter(@components, fn {_key, meta} ->
      tag in meta.tags
    end)
  end
  
  @doc "Get component metadata"
  def get_component(component_name) do
    Map.get(@components, component_name)
  end
end
```

## Performance Optimization

### Component Performance Patterns

```elixir
defmodule Raxol.UI.Components.OptimizedList do
  @moduledoc """
  High-performance list component with virtualization and memoization.
  """
  
  use Raxol.UI, framework: :react
  
  def mount(_params, _session, socket) do
    socket = 
      socket
      |> assign(:virtual_items, %{})
      |> assign(:visible_range, {0, 20})
      |> assign(:item_height, 40)
      |> assign(:container_height, 800)
      |> assign(:memoized_renders, %{})
      
    {:ok, socket}
  end
  
  def optimized_list(assigns) do
    assigns = 
      assigns
      |> assign_new(:items, fn -> [] end)
      |> assign_new(:item_height, fn -> 40 end)
      |> assign_new(:container_height, fn -> 800 end)
      |> assign(:visible_items, calculate_visible_items(assigns))
    
    ~H"""
    <div 
      class="virtual-list-container"
      style={"height: #{@container_height}px; overflow-y: auto;"}
      phx-hook="VirtualScroll"
      phx-target={@myself}
    >
      <div 
        class="virtual-list-spacer"
        style={"height: #{total_height(@items, @item_height)}px; position: relative;"}
      >
        <%= for {item, index} <- @visible_items do %>
          <div 
            class="virtual-list-item"
            style={"position: absolute; top: #{index * @item_height}px; height: #{@item_height}px; width: 100%;"}
          >
            <%= render_memoized_item(item, index, @memoized_renders, @item_renderer) %>
          </div>
        <% end %>
      </div>
    </div>
    """
  end
  
  # Memoize item rendering for performance
  defp render_memoized_item(item, index, memoized_renders, renderer) do
    item_key = generate_item_key(item, index)
    
    case Map.get(memoized_renders, item_key) do
      nil ->
        rendered = renderer.(item, index)
        # Cache the rendered output
        Process.put({:memo, item_key}, rendered)
        rendered
        
      cached ->
        cached
    end
  end
  
  defp calculate_visible_items(assigns) do
    {start_index, end_index} = assigns.visible_range
    
    assigns.items
    |> Enum.with_index()
    |> Enum.slice(start_index, end_index - start_index)
  end
  
  defp total_height(items, item_height) do
    length(items) * item_height
  end
  
  defp generate_item_key(item, index) do
    # Create stable key based on item content and position
    :crypto.hash(:md5, "#{inspect(item)}_#{index}")
    |> Base.encode16()
  end
end
```

## Best Practices Checklist

### Component Quality Standards

- [ ] **Functionality**
  - [ ] Component renders correctly in all frameworks
  - [ ] All props work as documented
  - [ ] Error states are handled gracefully
  - [ ] Edge cases are covered

- [ ] **Performance**
  - [ ] No unnecessary re-renders
  - [ ] Expensive operations are memoized
  - [ ] Large datasets use virtualization
  - [ ] Memory usage is optimized

- [ ] **Accessibility**
  - [ ] Proper ARIA attributes
  - [ ] Keyboard navigation support
  - [ ] Screen reader compatibility
  - [ ] Color contrast meets standards

- [ ] **Testing**
  - [ ] Unit tests for all props
  - [ ] Integration tests for complex interactions
  - [ ] Accessibility tests
  - [ ] Performance benchmarks

- [ ] **Documentation**
  - [ ] Clear API documentation
  - [ ] Interactive examples
  - [ ] Usage guidelines
  - [ ] Migration notes for breaking changes

- [ ] **Code Quality**
  - [ ] Consistent naming conventions
  - [ ] Proper error handling
  - [ ] Clean separation of concerns
  - [ ] Follows project style guide

## Further Resources

- [Raxol Component Generator](../../lib/mix/tasks/raxol.gen.component.ex)
- [Component Test Helpers](../../test/support/component_test_helpers.ex)
- [Performance Testing Guide](./performance_testing.md)
- [Accessibility Guidelines](./accessibility_implementation_guide.md)
- [Framework Migration Guide](./multi_framework_migration_guide.md)

---

*This guide evolves with the Raxol ecosystem. Contribute improvements by submitting component patterns and best practices.*