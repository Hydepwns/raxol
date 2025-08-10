defmodule Raxol.Svelte.Slots do
  @moduledoc """
  Svelte-style slot system for component composition.

  Allows parent components to pass content into child components,
  similar to Svelte's slot mechanism or React's children prop.

  ## Example

      defmodule Card do
        use Raxol.Svelte.Component
        use Raxol.Svelte.Slots
        
        def render(assigns) do
          ~H'''
          <Box border="single" padding={2}>
            <slot name="header">
              <Text bold>Default Header</Text>
            </slot>
            
            <Box class="card-content">
              <slot />
            </Box>
            
            <slot name="footer" />
          </Box>
          '''
        end
      end
      
      # Usage:
      defmodule App do
        def render(assigns) do
          ~H'''
          <Card>
            <template slot="header">
              <Text color="blue">Custom Header</Text>
            </template>
            
            <Text>This goes in the default slot</Text>
            
            <template slot="footer">
              <Button>Action</Button>
            </template>
          </Card>
          '''
        end
      end
  """

  defmacro __using__(_opts) do
    quote do
      import Raxol.Svelte.Slots

      @slots %{}
      @slot_props %{}
      @before_compile Raxol.Svelte.Slots
    end
  end

  @doc """
  Define a slot with optional default content and props.
  """
  defmacro slot(name \\ :default, opts \\ []) do
    quote do
      render_slot(unquote(name), unquote(opts))
    end
  end

  @doc """
  Define a scoped slot that passes data to the slot content.
  """
  defmacro scoped_slot(name, data, do: default_content) do
    quote do
      render_scoped_slot(unquote(name), unquote(data), unquote(default_content))
    end
  end

  @doc """
  Check if a slot has been provided by the parent.
  """
  def has_slot?(name \\ :default) do
    {:ok, state} = Agent.get(__MODULE__, & &1)
    get_in(state, [:slots, name]) != nil
  end

  @doc """
  Get the names of all available slots.
  """
  def slot_names do
    {:ok, state} = Agent.get(__MODULE__, & &1)
    get_in(state, [:slots]) |> Map.keys()
  end

  defp get_slots_internal do
    {:ok, state} = Agent.get(__MODULE__, & &1)
    get_in(state, [:slots]) || %{}
  end

  defmacro __before_compile__(_env) do
    quote do
      # Add slot management to component initialization
      def init({terminal, props}) do
        slots = extract_slots_from_props(props)

        state = %{
          terminal: terminal,
          props: props,
          slots: slots,
          state: @state_vars,
          reactive: %{},
          contexts: %{},
          dirty: true,
          subscribers: []
        }

        # Calculate initial reactive values
        state = calculate_reactive(state)

        # Initial render
        send(self(), :render)

        {:ok, state}
      end

      # Render a slot with optional fallback content
      defp render_slot(name, opts \\ []) do
        slots = get_slots()
        fallback = Keyword.get(opts, :fallback)
        props = Keyword.get(opts, :props, %{})

        case Map.get(slots, name) do
          nil ->
            # No slot provided, use fallback
            fallback || []

          slot_content ->
            # Render provided slot content with props
            render_slot_content(slot_content, props)
        end
      end

      # Render a scoped slot that passes data to slot content
      defp render_scoped_slot(name, data, default_content) do
        slots = get_slots()

        case Map.get(slots, name) do
          nil ->
            # No slot provided, use default
            default_content

          slot_content ->
            # Render slot content with scoped data
            render_slot_content(slot_content, data)
        end
      end

      defp get_slots do
        case Process.get(:current_component_slots) do
          nil -> %{}
          slots -> slots
        end
      end

      defp extract_slots_from_props(props) do
        # Extract slot content from component props
        slots = %{}

        # Look for :slots key in props
        case Map.get(props, :slots) do
          nil -> slots
          slot_map when is_map(slot_map) -> slot_map
          _ -> slots
        end
      end

      defp render_slot_content(content, props) when is_function(content) do
        # Slot content is a function - call it with props
        content.(props)
      end

      defp render_slot_content(content, _props) do
        # Slot content is static
        content
      end

      # Override render to set current slots in process dictionary
      defp render_with_slots(assigns) do
        Process.put(:current_component_slots, assigns[:slots] || %{})
        result = render(assigns)
        Process.delete(:current_component_slots)
        result
      end

      defoverridable init: 1
    end
  end

  # Slot content extraction from templates

  @doc """
  Extract slots from component children during template compilation.
  """
  def extract_template_slots(children) when is_list(children) do
    {slots, remaining} =
      Enum.reduce(children, {%{}, []}, fn
        # Named slot template
        {:template, _, attrs = [{:slot, slot_name} | _], content},
        {slots_acc, remaining_acc} ->
          slot_props = extract_slot_props(attrs)
          slot_data = %{content: content, props: slot_props}
          {Map.put(slots_acc, slot_name, slot_data), remaining_acc}

        # Default slot content
        child, {slots_acc, remaining_acc} ->
          {slots_acc, [child | remaining_acc]}
      end)

    # Add remaining content as default slot if any
    final_slots =
      if remaining != [] do
        Map.put(slots, :default, %{content: Enum.reverse(remaining), props: %{}})
      else
        slots
      end

    final_slots
  end

  def extract_template_slots(single_child) do
    extract_template_slots([single_child])
  end

  defp extract_slot_props(attrs) do
    attrs
    |> Enum.filter(fn {key, _} -> key != :slot end)
    |> Enum.into(%{})
  end
end

# Built-in slot components

defmodule Raxol.Svelte.Slots.Modal do
  @moduledoc """
  Example modal component using slots.
  """
  use Raxol.Svelte.Component
  use Phoenix.Component

  state(:visible, false)

  def show, do: set_state(:visible, true)
  def hide, do: set_state(:visible, false)

  def render(assigns) do
    ~S"""
    {#if @visible}
      <Box 
        class="modal-backdrop" 
        position="absolute" 
        x={0} y={0} 
        width="100%" height="100%"
        background="rgba(0,0,0,0.5)"
        on_click={&hide/0}
      >
        <Box 
          class="modal-content"
          position="center"
          border="double"
          padding={2}
          background="white"
          on_click={fn e -> e.stop_propagation() end}
        >
          <!-- Header slot -->
          <Row class="modal-header" justify="between" align="center">
            <slot name="header">
              <Text bold>Modal</Text>
            </slot>
            
            <Button variant="ghost" size="small" on_click={&hide/0}>×</Button>
          </Row>
          
          <!-- Default content slot -->
          <Box class="modal-body" padding={1}>
            <slot />
          </Box>
          
          <!-- Footer slot -->
          {#if has_slot?(:footer)}
            <Row class="modal-footer" justify="end" spacing={1}>
              <slot name="footer" />
            </Row>
          {/if}
        </Box>
      </Box>
    {/if}
    """
  end
end

defmodule Raxol.Svelte.Slots.Tabs do
  @moduledoc """
  Tabs component using scoped slots.
  """
  use Raxol.Svelte.Component
  use Raxol.Svelte.Slots
  use Raxol.Svelte.Reactive

  state(:active_tab, 0)
  state(:tabs, [])

  def set_active_tab(index) do
    set_state(:active_tab, index)
  end

  def add_tab(label, content) do
    update_state(:tabs, fn tabs ->
      tabs ++ [%{label: label, content: content}]
    end)
  end

  reactive :tab_count do
    length(@tabs)
  end

  def render(assigns) do
    ~H"""
    <Box class="tabs">
      <!-- Tab headers -->
      <Row class="tab-headers" border_bottom="single">
        {#each @tabs as {tab, index}}
          <Button
            variant={if @active_tab == index, do: "active", else: "ghost"}
            on_click={fn -> set_active_tab(index) end}
          >
            {tab.label}
          </Button>
        {/each}
        
        <!-- Scoped slot for custom tab header -->
        <scoped_slot name="tab_header" data={%{tabs: @tabs, active: @active_tab}}>
          <!-- Default tab header if no custom one provided -->
        </scoped_slot>
      </Row>
      
      <!-- Tab content -->
      <Box class="tab-content" padding={2}>
        {#if @active_tab < @tab_count}
          {@tabs[@active_tab].content}
        {/if}
        
        <!-- Scoped slot for custom tab content -->
        <scoped_slot name="tab_content" data={%{
          tab: Enum.at(@tabs, @active_tab),
          index: @active_tab,
          switch_tab: &set_active_tab/1
        }}>
          <Text>No content</Text>
        </scoped_slot>
      </Box>
      
      <!-- Footer slot -->
      <slot name="footer" />
    </Box>
    """
  end
end

defmodule Raxol.Svelte.Slots.DataTable do
  @moduledoc """
  Data table component with customizable columns using slots.
  """
  use Raxol.Svelte.Component
  use Raxol.Svelte.Slots

  state(:data, [])
  state(:columns, [])
  state(:sort_by, nil)
  state(:sort_order, :asc)

  def sort_by_column(column) do
    current_sort = get_state(:sort_by)

    if current_sort == column do
      # Toggle sort order
      current_order = get_state(:sort_order)
      new_order = if current_order == :asc, do: :desc, else: :asc
      set_state(:sort_order, new_order)
    else
      # Sort by new column
      set_state(:sort_by, column)
      set_state(:sort_order, :asc)
    end
  end

  def render(assigns) do
    ~H"""
    <Box class="data-table" border="single">
      <!-- Table header -->
      <Row class="table-header" background="gray">
        {#each @columns as column}
          <Button
            variant="ghost"
            on_click={fn -> sort_by_column(column) end}
            class={if @sort_by == column, do: "sorted", else: ""}
          >
            {String.capitalize(Atom.to_string(column))}
            {#if @sort_by == column}
              {if @sort_order == :asc, do: "↑", else: "↓"}
            {/if}
          </Button>
        {/each}
        
        <!-- Custom header slot -->
        <slot name="header" />
      </Row>
      
      <!-- Table rows -->
      {#each sorted_data(@data, @sort_by, @sort_order) as {row, index}}
        <Row class="table-row" background={if rem(index, 2) == 0, do: "light", else: "white"}>
          {#each @columns as column}
            <!-- Scoped slot for custom cell rendering -->
            <scoped_slot name="cell" data={%{
              value: Map.get(row, column),
              row: row,
              column: column,
              index: index
            }}>
              <!-- Default cell content -->
              <Text>{Map.get(row, column, "")}</Text>
            </scoped_slot>
          {/each}
          
          <!-- Actions slot -->
          <scoped_slot name="actions" data={%{row: row, index: index}}>
            <!-- Default actions if any -->
          </scoped_slot>
        </Row>
      {/each}
      
      <!-- Empty state slot -->
      {#if length(@data) == 0}
        <slot name="empty">
          <Text color="gray" italic>No data to display</Text>
        </slot>
      {/if}
      
      <!-- Footer slot -->
      <slot name="footer" />
    </Box>
    """
  end

  defp sorted_data(data, nil, _order), do: Enum.with_index(data)

  defp sorted_data(data, sort_by, sort_order) do
    sorted = Enum.sort_by(data, fn row -> Map.get(row, sort_by) end)

    final_sorted =
      case sort_order do
        :asc -> sorted
        :desc -> Enum.reverse(sorted)
      end

    Enum.with_index(final_sorted)
  end
end
