defmodule Examples.SvelteAdvancedDemo do
  @moduledoc """
  Advanced Svelte-style demo showcasing all the new features:
  
  - Actions (use: directive)
  - Transitions and animations
  - Context API
  - Slots and component composition
  - Compile-time optimization
  
  This creates a complete dashboard application with multiple components
  that demonstrate the power of the Svelte-style architecture.
  """
  
  use Raxol.Svelte.Component, optimize: :compile_time
  use Raxol.Svelte.Context
  use Raxol.Svelte.Actions
  use Raxol.Svelte.Slots
  use Raxol.Svelte.Transitions
  use Raxol.Svelte.Reactive
  
  # App state
  state :current_page, :dashboard
  state :sidebar_collapsed, false
  state :modal_visible, false
  state :notifications, []
  
  # Actions
  action :tooltip, fn element, text ->
    Raxol.Svelte.Actions.Builtin.tooltip(element, text)
  end
  
  action :auto_save, fn element, save_fn ->
    element
    |> Map.put(:on_blur, fn -> save_fn.() end)
    |> Map.put(:on_change, fn value ->
      # Debounced auto-save
      Process.send_after(self(), {:auto_save, value, save_fn}, 1000)
    end)
  end
  
  # Transitions
  transition :slide_fade, fn element, params ->
    duration = Map.get(params, :duration, 300)
    
    case Map.get(params, :direction) do
      :enter ->
        [
          {:x, element.x - element.width, element.x, duration, :ease_out, 0},
          {:opacity, 0, 1, duration, :ease_out, 100}
        ]
      :exit ->
        [
          {:x, element.x, element.x + element.width, duration, :ease_in, 0},
          {:opacity, 1, 0, duration, :ease_in, 0}
        ]
    end
  end
  
  # Reactive declarations (using reactive macro instead of $: syntax for valid Elixir)
  reactive :page_title do
    case @current_page do
      :dashboard -> "Dashboard"
      :analytics -> "Analytics"  
      :settings -> "Settings"
      _ -> "App"
    end
  end
  
  reactive :has_notifications do
    length(@notifications) > 0
  end
  
  reactive :notification_count do
    length(@notifications)
  end
  
  # Event handlers
  def navigate_to(page) do
    set_state(:current_page, page)
  end
  
  def toggle_sidebar do
    update_state(:sidebar_collapsed, & !&1)
  end
  
  def show_modal do
    set_state(:modal_visible, true)
  end
  
  def hide_modal do
    set_state(:modal_visible, false)
  end
  
  def add_notification(message, type \\ :info) do
    notification = %{
      id: :crypto.strong_rand_bytes(4) |> Base.encode64(),
      message: message,
      type: type,
      timestamp: DateTime.utc_now()
    }
    
    update_state(:notifications, fn notifications ->
      [notification | notifications]
    end)
    
    # Auto-remove after 5 seconds
    Process.send_after(self(), {:remove_notification, notification.id}, 5000)
  end
  
  def remove_notification(id) do
    update_state(:notifications, fn notifications ->
      Enum.reject(notifications, fn n -> n.id == id end)
    end)
  end
  
  # Message handling for auto-remove
  def handle_info({:remove_notification, id}, state) do
    remove_notification(id)
    {:noreply, state}
  end
  
  def handle_info({:auto_save, value, save_fn}, state) do
    save_fn.(value)
    {:noreply, state}
  end
  
  def handle_info(msg, state) do
    super(msg, state)
  end
  
  # Main render function
  def render(assigns) do
    ~H"""
    <!-- Theme Provider Context -->
    <Raxol.Svelte.Context.ThemeProvider>
      <Box class="app-container" width="100%" height="100%">
        
        <!-- Sidebar -->
        <Box 
          class="sidebar"
          width={if @sidebar_collapsed, do: 3, else: 20}
          height="100%"
          border_right="single"
          in:slide={{duration: 200, axis: :x}}
          out:slide={{duration: 200, axis: :x}}
        >
          <Navigation 
            current_page={@current_page}
            collapsed={@sidebar_collapsed}
            on_navigate={&navigate_to/1}
          />
        </Box>
        
        <!-- Main Content Area -->
        <Box class="main-content" flex={1} height="100%">
          
          <!-- Top Bar -->
          <TopBar 
            title={page_title}
            notification_count={@notification_count}
            on_toggle_sidebar={&toggle_sidebar/0}
            on_show_modal={&show_modal/0}
          />
          
          <!-- Page Content with Transitions -->
          <Box 
            class="page-content" 
            padding={2}
            in:slide_fade={{duration: 300}}
            key={@current_page}
          >
            {#if @current_page == :dashboard}
              <DashboardPage />
            {:else if @current_page == :analytics}
              <AnalyticsPage />
            {:else if @current_page == :settings}
              <SettingsPage />
            {/if}
          </Box>
          
        </Box>
        
        <!-- Notifications -->
        <NotificationContainer notifications={@notifications} />
        
        <!-- Modal -->
        {#if @modal_visible}
          <ExampleModal on_close={&hide_modal/0} />
        {/if}
        
      </Box>
    </Raxol.Svelte.Context.ThemeProvider>
    """
  end
end

# Component definitions using the new features

defmodule Examples.SvelteAdvancedDemo.Navigation do
  use Raxol.Svelte.Component
  use Raxol.Svelte.Context
  use Raxol.Svelte.Transitions
  
  def render(%{current_page: current, collapsed: collapsed, on_navigate: on_navigate}) do
    theme = get_context(:theme)
    
    ~H"""
    <Box class="navigation" padding={1}>
      {#if !collapsed}
        <Text bold color={theme.colors.primary} in:fade={{duration: 200}}>
          My App
        </Text>
      {/if}
      
      <List spacing={1}>
        <NavItem 
          icon="📊" 
          label="Dashboard" 
          page={:dashboard}
          active={current == :dashboard}
          collapsed={collapsed}
          on_click={fn -> on_navigate.(:dashboard) end}
        />
        
        <NavItem 
          icon="📈" 
          label="Analytics" 
          page={:analytics}
          active={current == :analytics}
          collapsed={collapsed}
          on_click={fn -> on_navigate.(:analytics) end}
        />
        
        <NavItem 
          icon="⚙️" 
          label="Settings" 
          page={:settings}
          active={current == :settings}
          collapsed={collapsed}
          on_click={fn -> on_navigate.(:settings) end}
        />
      </List>
    </Box>
    """
  end
end

defmodule Examples.SvelteAdvancedDemo.NavItem do
  use Raxol.Svelte.Component
  use Raxol.Svelte.Context
  use Raxol.Svelte.Actions
  
  action :nav_tooltip, fn element, label ->
    if element.collapsed do
      Raxol.Svelte.Actions.Builtin.tooltip(element, label)
    else
      element
    end
  end
  
  def render(%{icon: icon, label: label, active: active, collapsed: collapsed, on_click: on_click}) do
    theme = get_context(:theme)
    
    ~H"""
    <Button
      variant={if active, do: "primary", else: "ghost"}
      justify={if collapsed, do: "center", else: "start"}
      padding={if collapsed, do: 1, else: 2}
      width="100%"
      on_click={on_click}
      use:nav_tooltip={label}
    >
      <Text>{icon}</Text>
      {#if !collapsed}
        <Text margin_left={2}>{label}</Text>
      {/if}
    </Button>
    """
  end
end

defmodule Examples.SvelteAdvancedDemo.TopBar do
  use Raxol.Svelte.Component
  use Raxol.Svelte.Context
  use Raxol.Svelte.Actions
  
  def render(%{title: title, notification_count: count, on_toggle_sidebar: on_toggle, on_show_modal: on_show_modal}) do
    theme = get_context(:theme)
    
    ~H"""
    <Row 
      class="top-bar" 
      justify="between" 
      align="center"
      padding={2}
      border_bottom="single"
      background={theme.colors.surface}
    >
      <Row align="center" spacing={2}>
        <Button variant="ghost" size="small" on_click={on_toggle}>☰</Button>
        <Text bold size="large">{title}</Text>
      </Row>
      
      <Row align="center" spacing={2}>
        <!-- Notification Bell -->
        <Button 
          variant="ghost"
          size="small"
          use:tooltip={"#{count} notifications"}
        >
          🔔
          {#if count > 0}
            <Badge count={count} color="red" />
          {/if}
        </Button>
        
        <!-- User Menu -->
        <Button variant="ghost" on_click={on_show_modal} use:tooltip="User menu">
          👤
        </Button>
      </Row>
    </Row>
    """
  end
end

defmodule Examples.SvelteAdvancedDemo.DashboardPage do
  use Raxol.Svelte.Component
  use Raxol.Svelte.Context
  use Raxol.Svelte.Slots
  use Raxol.Svelte.Transitions
  
  def render(_assigns) do
    ~H"""
    <Box class="dashboard" spacing={2}>
      <Text size="large" bold>Dashboard</Text>
      
      <!-- Stats Cards -->
      <Row spacing={2}>
        <StatsCard title="Users" value="1,234" change="+5%" />
        <StatsCard title="Revenue" value="$12.3K" change="+12%" />
        <StatsCard title="Orders" value="456" change="-2%" />
      </Row>
      
      <!-- Data Table with Slots -->
      <Raxol.Svelte.Slots.DataTable
        data={sample_data()}
        columns={[:name, :email, :status]}
      >
        <template slot="cell" let:value let:column let:row>
          {#if column == :status}
            <Badge 
              color={if value == "active", do: "green", else: "gray"}
              text={value}
            />
          {:else}
            <Text>{value}</Text>
          {/if}
        </template>
        
        <template slot="actions" let:row>
          <Button size="small" variant="primary">Edit</Button>
          <Button size="small" variant="danger">Delete</Button>
        </template>
        
        <template slot="empty">
          <Text color="gray" italic>No users found</Text>
        </template>
      </Raxol.Svelte.Slots.DataTable>
      
    </Box>
    """
  end
  
  defp sample_data do
    [
      %{name: "John Doe", email: "john@example.com", status: "active"},
      %{name: "Jane Smith", email: "jane@example.com", status: "inactive"},
      %{name: "Bob Johnson", email: "bob@example.com", status: "active"}
    ]
  end
end

defmodule Examples.SvelteAdvancedDemo.StatsCard do
  use Raxol.Svelte.Component
  use Raxol.Svelte.Context
  use Raxol.Svelte.Transitions
  
  def render(%{title: title, value: value, change: change}) do
    theme = get_context(:theme)
    
    change_color = cond do
      String.starts_with?(change, "+") -> "green"
      String.starts_with?(change, "-") -> "red"
      true -> "gray"
    end
    
    ~H"""
    <Box 
      class="stats-card"
      border="single"
      padding={2}
      background={theme.colors.surface}
      in:scale={{duration: 300, start: 0.9}}
      hover:scale={{scale: 1.05}}
    >
      <Text size="small" color={theme.colors.text_secondary}>{title}</Text>
      <Text size="large" bold>{value}</Text>
      <Text size="small" color={change_color}>{change}</Text>
    </Box>
    """
  end
end

defmodule Examples.SvelteAdvancedDemo.ExampleModal do
  use Raxol.Svelte.Slots.Modal
  use Raxol.Svelte.Actions
  
  action :click_outside, fn element, callback ->
    Raxol.Svelte.Actions.Builtin.click_outside(element, callback)
  end
  
  def render(%{on_close: on_close}) do
    ~H"""
    <Modal visible={true} use:click_outside={on_close}>
      
      <template slot="header">
        <Text bold>User Profile</Text>
      </template>
      
      <Box spacing={2}>
        <Text>Edit your profile information:</Text>
        
        <TextInput 
          label="Name" 
          value="John Doe"
          use:auto_save={fn value -> IO.puts("Saving name: #{value}") end}
        />
        
        <TextInput 
          label="Email" 
          value="john@example.com"
          use:auto_save={fn value -> IO.puts("Saving email: #{value}") end}
        />
      </Box>
      
      <template slot="footer">
        <Button variant="secondary" on_click={on_close}>Cancel</Button>
        <Button variant="primary" on_click={on_close}>Save</Button>
      </template>
      
    </Modal>
    """
  end
end

defmodule Examples.SvelteAdvancedDemo.NotificationContainer do
  use Raxol.Svelte.Component
  use Raxol.Svelte.Transitions
  
  def render(%{notifications: notifications}) do
    ~H"""
    <Box class="notifications" position="fixed" top={2} right={2} spacing={1}>
      {#each notifications as notification}
        <Box 
          class="notification"
          key={notification.id}
          border="single"
          padding={2}
          background={notification_bg_color(notification.type)}
          in:fly={{x: 300, duration: 300}}
          out:fly={{x: 300, duration: 200}}
        >
          <Text>{notification.message}</Text>
        </Box>
      {/each}
    </Box>
    """
  end
  
  defp notification_bg_color(:info), do: "blue"
  defp notification_bg_color(:success), do: "green"  
  defp notification_bg_color(:warning), do: "yellow"
  defp notification_bg_color(:error), do: "red"
  defp notification_bg_color(_), do: "gray"
end