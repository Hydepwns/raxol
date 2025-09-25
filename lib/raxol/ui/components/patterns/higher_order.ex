defmodule Raxol.UI.Components.Patterns.HigherOrder do
  @moduledoc """
  Higher-Order Components (HOCs) for Raxol UI.

  Higher-Order Components are a pattern for reusing component logic. A HOC is a function
  that takes a component and returns a new component with enhanced functionality.

  ## Common Use Cases

  - Authentication/Authorization
  - Loading states
  - Error boundaries
  - Data fetching
  - Styling/Theming
  - Logging/Analytics
  - Performance optimization

  ## Usage

      # Create a HOC that adds loading state
      with_loading = HigherOrder.with_loading_state()
      
      # Enhance a component
      enhanced_user_list = with_loading.(UserList)
      
      # Use the enhanced component
      %{
        type: enhanced_user_list,
        attrs: %{users: users, loading: loading}
      }
      
      # Chain multiple HOCs
      super_enhanced = HigherOrder.chain([
        HigherOrder.with_loading_state(),
        HigherOrder.with_error_boundary(),
        HigherOrder.with_analytics("user_list_component")
      ]).(UserList)
  """

  alias Raxol.UI.State.{Context, Hooks}

  @doc """
  Creates a HOC that adds loading state management.

  ## Enhanced Props
  - `:loading` - Boolean indicating loading state
  - `:set_loading` - Function to update loading state

  ## Examples

      with_loading = HigherOrder.with_loading_state()
      LoadingUserList = with_loading.(UserList)
      
      # The enhanced component will have access to loading state
  """
  def with_loading_state(options \\ []) do
    initial_loading = Keyword.get(options, :initial_loading, false)

    loading_component =
      Keyword.get(options, :loading_component, &default_loading_component/1)

    fn component_module ->
      fn props, context ->
        # Add loading state using hooks
        {loading, set_loading} = Hooks.use_state(initial_loading)

        # Enhance props with loading utilities
        enhanced_props =
          Map.merge(props, %{
            loading: loading,
            set_loading: set_loading
          })

        # Show loading component if loading
        render_with_loading_state(
          loading,
          loading_component,
          enhanced_props,
          component_module,
          context
        )
      end
    end
  end

  @doc """
  Creates a HOC that adds error boundary functionality.

  ## Enhanced Props
  - `:error` - Current error (nil if no error)
  - `:clear_error` - Function to clear the error
  - `:on_error` - Function to report errors

  ## Examples

      with_error_boundary = HigherOrder.with_error_boundary()
      SafeComponent = with_error_boundary.(RiskyComponent)
  """
  def with_error_boundary(options \\ []) do
    error_component =
      Keyword.get(options, :error_component, &default_error_component/1)

    on_error_callback = Keyword.get(options, :on_error)

    fn component_module ->
      fn props, context ->
        {error, set_error} = Hooks.use_state(nil)

        clear_error =
          Hooks.use_callback(
            fn ->
              set_error.(nil)
            end,
            [set_error]
          )

        report_error =
          Hooks.use_callback(
            fn error_info ->
              set_error.(error_info)
              handle_error_callback(on_error_callback, error_info)
            end,
            [set_error, on_error_callback]
          )

        enhanced_props =
          Map.merge(props, %{
            error: error,
            clear_error: clear_error,
            on_error: report_error
          })

        render_with_error_boundary(
          error,
          error_component,
          enhanced_props,
          component_module,
          context,
          props,
          report_error
        )
      end
    end
  end

  @doc """
  Creates a HOC that provides authentication context and guards.

  ## Enhanced Props
  - `:user` - Current authenticated user (nil if not authenticated)
  - `:authenticated` - Boolean indicating authentication status
  - `:permissions` - List of user permissions
  - `:has_permission` - Function to check permissions

  ## Examples

      with_auth = HigherOrder.with_authentication()
      ProtectedComponent = with_auth.(AdminPanel)
  """
  def with_authentication(options \\ []) do
    login_component =
      Keyword.get(options, :login_component, &default_login_component/1)

    required_permissions = Keyword.get(options, :required_permissions, [])

    unauthorized_component =
      Keyword.get(
        options,
        :unauthorized_component,
        &default_unauthorized_component/1
      )

    fn component_module ->
      fn props, context ->
        # Get user context
        user_context_raw = Hooks.use_context(:user_context)

        user_context =
          case user_context_raw do
            nil -> %{authenticated: false}
            map when is_map(map) -> Map.put_new(map, :authenticated, false)
            _ -> %{authenticated: false}
          end

        has_permission =
          Hooks.use_callback(
            fn permission ->
              user_permissions = Map.get(user_context, :permissions, [])
              Enum.member?(user_permissions, permission)
            end,
            [user_context]
          )

        enhanced_props =
          Map.merge(props, %{
            user: Map.get(user_context, :user),
            authenticated: Map.get(user_context, :authenticated, false),
            permissions: Map.get(user_context, :permissions, []),
            has_permission: has_permission
          })

        render_based_on_auth_state(
          user_context,
          required_permissions,
          has_permission,
          component_module,
          enhanced_props,
          context,
          login_component,
          unauthorized_component
        )
      end
    end
  end

  @doc """
  Creates a HOC that adds data fetching capabilities.

  ## Enhanced Props
  - `:data` - Fetched data (nil while loading)
  - `:loading` - Boolean indicating fetch in progress
  - `:error` - Fetch error (nil if no error)
  - `:refetch` - Function to refetch data

  ## Examples

      with_data = HigherOrder.with_data_fetching(fn props ->
        fetch_users(props.organization_id)
      end)
      
      DataDrivenComponent = with_data.(UserList)
  """
  def with_data_fetching(fetch_fn, options \\ [])
      when is_function(fetch_fn, 1) do
    loading_component =
      Keyword.get(options, :loading_component, &default_loading_component/1)

    error_component =
      Keyword.get(options, :error_component, &default_error_component/1)

    dependencies = Keyword.get(options, :dependencies, [])

    fn component_module ->
      fn props, context ->
        # Extract dependency values from props
        deps = Enum.map(dependencies, &Map.get(props, &1))

        # Use async hook for data fetching
        {data, loading, error, refetch} =
          Hooks.use_async(
            fn ->
              fetch_fn.(props)
            end,
            deps
          )

        enhanced_props =
          Map.merge(props, %{
            data: data,
            loading: loading,
            error: error,
            refetch: refetch
          })

        render_based_on_data_state(
          loading,
          error,
          component_module,
          enhanced_props,
          context,
          loading_component,
          error_component
        )
      end
    end
  end

  @doc """
  Creates a HOC that adds theming capabilities.

  ## Enhanced Props
  - `:theme` - Current theme object
  - `:set_theme` - Function to change theme
  - `:css_vars` - CSS-like variables for styling

  ## Examples

      with_theme = HigherOrder.with_theme()
      ThemedButton = with_theme.(Button)
  """
  def with_theme(options \\ []) do
    theme_context_name = Keyword.get(options, :context_name, :theme_context)

    fn component_module ->
      fn props, context ->
        theme = Hooks.use_context(theme_context_name)

        set_theme =
          Hooks.use_callback(
            fn new_theme ->
              Context.update_context_value(theme_context_name, new_theme)
            end,
            []
          )

        # Generate CSS-like variables from theme
        css_vars = generate_css_variables(theme)

        enhanced_props =
          Map.merge(props, %{
            theme: theme,
            set_theme: set_theme,
            css_vars: css_vars
          })

        component_module.render(enhanced_props, context)
      end
    end
  end

  @doc """
  Creates a HOC that adds analytics tracking.

  ## Enhanced Props
  - `:track_event` - Function to track analytics events
  - `:component_id` - Unique identifier for analytics

  ## Examples

      with_analytics = HigherOrder.with_analytics("user_profile")
      TrackedComponent = with_analytics.(UserProfile)
  """
  def with_analytics(component_name, options \\ []) do
    analytics_provider =
      Keyword.get(options, :provider, &default_analytics_provider/2)

    auto_track_mount = Keyword.get(options, :auto_track_mount, true)

    fn component_module ->
      fn props, context ->
        component_id = System.unique_integer([:positive, :monotonic])

        track_event =
          Hooks.use_callback(
            fn event_name, event_data ->
              final_event_data =
                case event_data do
                  nil ->
                    %{
                      component: component_name,
                      component_id: component_id,
                      timestamp: System.monotonic_time(:millisecond)
                    }

                  data when is_map(data) ->
                    Map.merge(data, %{
                      component: component_name,
                      component_id: component_id,
                      timestamp: System.monotonic_time(:millisecond)
                    })
                end

              analytics_provider.(event_name, final_event_data)
            end,
            [component_id]
          )

        # Auto-track component mount
        Hooks.use_effect(
          fn ->
            track_mount_if_enabled(auto_track_mount, track_event)

            # Track unmount
            fn ->
              track_event.("component_unmount")
            end
          end,
          []
        )

        enhanced_props =
          Map.merge(props, %{
            track_event: track_event,
            component_id: component_id
          })

        component_module.render(enhanced_props, context)
      end
    end
  end

  @doc """
  Creates a HOC that adds performance monitoring.

  ## Enhanced Props
  - `:performance` - Performance metrics
  - `:start_timer` - Function to start timing operations
  - `:end_timer` - Function to end timing operations

  ## Examples

      with_perf = HigherOrder.with_performance_monitoring()
      MonitoredComponent = with_perf.(ExpensiveComponent)
  """
  def with_performance_monitoring(options \\ []) do
    # 60fps
    report_threshold_ms = Keyword.get(options, :report_threshold_ms, 16)

    fn component_module ->
      fn props, context ->
        {performance_data, set_performance_data} =
          Hooks.use_state(%{
            render_times: [],
            average_render_time: 0,
            slow_renders: 0
          })

        start_timer =
          Hooks.use_callback(
            fn timer_name ->
              start_time = System.monotonic_time(:microsecond)
              Map.put(props, :"#{timer_name}_start_time", start_time)
            end,
            []
          )

        end_timer =
          Hooks.use_callback(
            fn timer_name ->
              end_time = System.monotonic_time(:microsecond)
              start_time = Map.get(props, :"#{timer_name}_start_time")

              calculate_timing_if_available(
                start_time,
                end_time,
                set_performance_data,
                report_threshold_ms
              )
            end,
            [set_performance_data, report_threshold_ms]
          )

        enhanced_props =
          Map.merge(props, %{
            performance: performance_data,
            start_timer: start_timer,
            end_timer: end_timer
          })

        # Time the render
        render_start = System.monotonic_time(:microsecond)

        result = component_module.render(enhanced_props, context)

        render_end = System.monotonic_time(:microsecond)
        render_time_ms = (render_end - render_start) / 1000

        # Update render time (async to avoid affecting current render)
        _ =
          Task.start(fn ->
            log_slow_render_if_needed(
              render_time_ms,
              report_threshold_ms,
              component_module
            )
          end)

        result
      end
    end
  end

  @doc """
  Creates a HOC that adds memoization to prevent unnecessary re-renders.

  ## Examples

      with_memo = HigherOrder.with_memoization(fn props -> [props.data, props.config] end)
      MemoizedComponent = with_memo.(ExpensiveComponent)
  """
  def with_memoization(deps_fn) when is_function(deps_fn, 1) do
    fn component_module ->
      fn props, context ->
        deps = deps_fn.(props)

        # Memoize the render result
        Hooks.use_memo(
          fn ->
            component_module.render(props, context)
          end,
          deps
        )
      end
    end
  end

  @doc """
  Chains multiple HOCs together.

  ## Examples

      super_hoc = HigherOrder.chain([
        HigherOrder.with_loading_state(),
        HigherOrder.with_error_boundary(),
        HigherOrder.with_authentication(required_permissions: [:admin]),
        HigherOrder.with_analytics("admin_panel")
      ])
      
      SuperAdminPanel = super_hoc.(AdminPanel)
  """
  def chain(hocs) when is_list(hocs) do
    fn component_module ->
      Enum.reduce(Enum.reverse(hocs), component_module, fn hoc, acc_component ->
        hoc.(acc_component)
      end)
    end
  end

  @doc """
  Creates a conditional HOC that only applies enhancement based on a condition.

  ## Examples

      conditional_auth = HigherOrder.when_condition(
        fn props -> props.require_auth end,
        HigherOrder.with_authentication()
      )
  """
  def when_condition(condition_fn, hoc) when is_function(condition_fn, 1) do
    fn component_module ->
      fn props, context ->
        apply_hoc_conditionally(
          condition_fn.(props),
          hoc,
          component_module,
          props,
          context
        )
      end
    end
  end

  # Default component implementations

  defp default_loading_component(_props) do
    %{
      type: :text,
      attrs: %{
        content: "Loading...",
        style: %{color: :secondary}
      }
    }
  end

  defp default_error_component(props) do
    error_message =
      case Map.get(props, :error) do
        %{reason: reason} -> "Error: #{inspect(reason)}"
        error when is_binary(error) -> "Error: #{error}"
        _ -> "An error occurred"
      end

    %{
      type: :column,
      attrs: %{gap: 5},
      children: [
        %{
          type: :text,
          attrs: %{
            content: error_message,
            style: %{color: :error}
          }
        },
        %{
          type: :button,
          attrs: %{
            label: "Retry",
            on_click: Map.get(props, :clear_error, fn -> :ok end)
          }
        }
      ]
    }
  end

  defp default_login_component(_props) do
    %{
      type: :column,
      attrs: %{gap: 10, align: :center},
      children: [
        %{type: :text, attrs: %{content: "Please log in to continue"}},
        %{type: :button, attrs: %{label: "Login"}}
      ]
    }
  end

  defp default_unauthorized_component(_props) do
    %{
      type: :text,
      attrs: %{
        content: "You don't have permission to view this content",
        style: %{color: :warning}
      }
    }
  end

  defp generate_css_variables(theme) do
    flatten_theme(theme, "", %{})
  end

  defp flatten_theme(%{} = map, prefix, acc) do
    Enum.reduce(map, acc, fn {key, value}, inner_acc ->
      var_name = if prefix == "", do: "--#{key}", else: "#{prefix}-#{key}"

      case value do
        %{} = nested_map ->
          flatten_theme(nested_map, var_name, inner_acc)

        _ ->
          Map.put(inner_acc, var_name, value)
      end
    end)
  end

  defp flatten_theme(value, prefix, acc) do
    Map.put(acc, prefix, value)
  end

  defp default_analytics_provider(event_name, event_data) do
    require Logger
    Logger.info("Analytics: #{event_name} - #{inspect(event_data)}")
  end

  defp render_based_on_auth_state(
         user_context,
         required_permissions,
         has_permission,
         component_module,
         enhanced_props,
         context,
         login_component,
         unauthorized_component
       )

  defp render_based_on_auth_state(
         %{authenticated: false},
         _required_permissions,
         _has_permission,
         _component_module,
         enhanced_props,
         _context,
         login_component,
         _unauthorized_component
       ) do
    login_component.(enhanced_props)
  end

  defp render_based_on_auth_state(
         %{authenticated: true},
         required_permissions,
         has_permission,
         _component_module,
         enhanced_props,
         _context,
         _login_component,
         unauthorized_component
       )
       when required_permissions != [] and
              not is_function(has_permission) do
    unauthorized_component.(enhanced_props)
  end

  defp render_based_on_auth_state(
         %{authenticated: true},
         required_permissions,
         has_permission,
         component_module,
         enhanced_props,
         context,
         _login_component,
         unauthorized_component
       )
       when required_permissions != [] do
    render_based_on_permissions(
      required_permissions,
      has_permission,
      component_module,
      enhanced_props,
      context,
      unauthorized_component
    )
  end

  defp render_based_on_auth_state(
         %{authenticated: true},
         _required_permissions,
         _has_permission,
         component_module,
         enhanced_props,
         context,
         _login_component,
         _unauthorized_component
       ) do
    component_module.render(enhanced_props, context)
  end

  defp render_based_on_data_state(
         false,
         error,
         _component_module,
         enhanced_props,
         _context,
         _loading_component,
         error_component
       )
       when not is_nil(error) do
    error_component.(enhanced_props)
  end

  defp render_based_on_data_state(
         false,
         _error,
         component_module,
         enhanced_props,
         context,
         _loading_component,
         _error_component
       ) do
    component_module.render(enhanced_props, context)
  end

  ## Pattern matching helper functions for if statement elimination

  defp render_with_loading_state(
         true,
         loading_component,
         enhanced_props,
         _component_module,
         _context
       ) do
    loading_component.(enhanced_props)
  end

  defp render_with_loading_state(
         false,
         _loading_component,
         enhanced_props,
         component_module,
         context
       ) do
    component_module.render(enhanced_props, context)
  end

  defp handle_error_callback(nil, _error_info), do: :ok
  defp handle_error_callback(callback, error_info), do: callback.(error_info)

  defp render_with_error_boundary(
         nil,
         error_component,
         enhanced_props,
         component_module,
         context,
         props,
         report_error
       ) do
    case Raxol.Core.ErrorHandling.safe_call(fn ->
           component_module.render(enhanced_props, context)
         end) do
      {:ok, result} ->
        result

      {:error, {reason, stacktrace}} ->
        error_info = %{
          kind: :error,
          reason: reason,
          stacktrace: stacktrace,
          component: component_module,
          props: props,
          timestamp: System.monotonic_time(:millisecond)
        }

        report_error.(error_info)
        error_component.(enhanced_props)
    end
  end

  defp render_with_error_boundary(
         error,
         error_component,
         enhanced_props,
         _component_module,
         _context,
         _props,
         _report_error
       )
       when not is_nil(error) do
    error_component.(enhanced_props)
  end

  defp track_mount_if_enabled(false, _track_event), do: :ok

  defp track_mount_if_enabled(true, track_event),
    do: track_event.("component_mount")

  defp calculate_timing_if_available(
         nil,
         _end_time,
         _set_performance_data,
         _threshold
       ),
       do: :ok

  defp calculate_timing_if_available(
         start_time,
         end_time,
         set_performance_data,
         report_threshold_ms
       ) do
    duration_ms = (end_time - start_time) / 1000

    # Update performance data
    set_performance_data.(fn perf ->
      # Keep last 20
      new_render_times = [
        duration_ms | Enum.take(perf.render_times, 19)
      ]

      avg_time =
        Enum.sum(new_render_times) / length(new_render_times)

      slow_count =
        increment_slow_count_if_needed(
          duration_ms,
          report_threshold_ms,
          perf.slow_renders
        )

      %{
        render_times: new_render_times,
        average_render_time: avg_time,
        slow_renders: slow_count
      }
    end)
  end

  defp increment_slow_count_if_needed(duration_ms, threshold, current_count)
       when duration_ms > threshold do
    current_count + 1
  end

  defp increment_slow_count_if_needed(_duration_ms, _threshold, current_count),
    do: current_count

  defp log_slow_render_if_needed(render_time_ms, threshold, component_module)
       when render_time_ms > threshold do
    require Logger

    Logger.warning(
      "Slow render detected: #{component_module} took #{Float.round(render_time_ms, 2)}ms"
    )
  end

  defp log_slow_render_if_needed(
         _render_time_ms,
         _threshold,
         _component_module
       ),
       do: :ok

  defp apply_hoc_conditionally(true, hoc, component_module, props, context) do
    enhanced_component = hoc.(component_module)
    enhanced_component.(props, context)
  end

  defp apply_hoc_conditionally(false, _hoc, component_module, props, context) do
    component_module.render(props, context)
  end

  defp render_based_on_permissions(
         required_permissions,
         has_permission,
         component_module,
         enhanced_props,
         context,
         unauthorized_component
       ) do
    case Enum.all?(required_permissions, has_permission) do
      true -> component_module.render(enhanced_props, context)
      false -> unauthorized_component.(enhanced_props)
    end
  end
end
