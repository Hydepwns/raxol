defmodule Raxol.UI.Components.Patterns.RenderProps do
  @moduledoc """
  Render Props pattern implementation for Raxol UI.

  Render Props is a technique for sharing code between components using a prop whose
  value is a function. A component with a render prop takes a function that returns
  an element and calls it instead of implementing its own render logic.

  This pattern is particularly useful for:
  - Data fetching components
  - Mouse/keyboard event handling
  - Scroll position tracking
  - Animation state management
  - Form state management

  ## Usage

      # Data fetcher with render prop
      %{
        type: :data_provider,
        attrs: %{
          fetch_fn: fn -> fetch_users() end,
          render: fn
            %{loading: true} ->
              text("Loading users...")
            %{error: error} when not is_nil(error) ->
              text("Error: \#{error}")
            %{data: users} ->
              render_user_list(users)
          end
        }
      }
      
      # Mouse tracker with render prop
      %{
        type: :mouse_tracker,
        attrs: %{
          render: fn %{mouse_x: x, mouse_y: y} ->
            text("Mouse position: (\#{x}, \#{y})")
          end
        }
      }
  """

  alias Raxol.UI.State.Hooks, as: Hooks

  @doc """
  Data provider component that fetches data and provides it via render prop.

  ## Props
  - `:fetch_fn` - Function that returns data (can be async)
  - `:render` - Function that receives `%{data, loading, error, refetch}`
  - `:dependencies` - List of values that trigger refetch when changed
  - `:cache_key` - Optional cache key for memoization

  ## Examples

      %{
        type: :data_provider,
        attrs: %{
          fetch_fn: fn -> HTTPoison.get("/api/users") end,
          dependencies: [user_id],
          render: fn state ->
            case state do
              %{loading: true} -> loading_spinner()
              %{error: error} -> error_message(error)
              %{data: data} -> user_list(data)
            end
          end
        }
      }
  """
  def data_provider do
    %{
      type: :render_prop_component,
      render_fn: fn props, _context ->
        fetch_fn = Map.get(props, :fetch_fn)
        render_fn = Map.get(props, :render)
        dependencies = Map.get(props, :dependencies, [])
        cache_key = Map.get(props, :cache_key)

        case {fetch_fn, render_fn} do
          {nil, _} ->
            %{
              type: :text,
              attrs: %{content: "Error: Missing fetch_fn"}
            }

          {_, nil} ->
            %{
              type: :text,
              attrs: %{content: "Error: Missing render prop"}
            }

          {fetch_fn, render_fn} ->
            # Use async hook for data fetching
            {data, loading, error, refetch} =
              Hooks.use_async(fetch_fn, dependencies)

            # Memoize if cache key provided
            render_state = %{
              data: data,
              loading: loading,
              error: error,
              refetch: refetch
            }

            render_with_optional_cache(render_fn, render_state, cache_key)
        end
      end
    }
  end

  @doc """
  Mouse tracker component that tracks mouse position and provides it via render prop.

  ## Props
  - `:render` - Function that receives `%{mouse_x, mouse_y, is_over}`
  - `:track_outside` - Whether to track mouse when outside component (default: false)

  ## Examples

      %{
        type: :mouse_tracker,
        attrs: %{
          render: fn %{mouse_x: x, mouse_y: y, is_over: over} ->
            column([
              text("Mouse: (\#{x}, \#{y})"),
              text("Over component: \#{over}")
            ])
          end
        }
      }
  """
  def mouse_tracker do
    %{
      type: :render_prop_component,
      render_fn: fn props, _context ->
        render_fn = Map.get(props, :render)
        track_outside = Map.get(props, :track_outside, false)

        render_mouse_tracker(render_fn, track_outside)
      end
    }
  end

  @doc """
  Keyboard handler component that tracks key states and provides them via render prop.

  ## Props
  - `:render` - Function that receives `%{pressed_keys, key_combinations}`
  - `:track_combinations` - List of key combinations to track (e.g., [:ctrl_c, :alt_tab])

  ## Examples

      %{
        type: :keyboard_handler,
        attrs: %{
          track_combinations: [:ctrl_c, :ctrl_v, :escape],
          render: fn %{pressed_keys: keys, key_combinations: combos} ->
            column([
              text("Pressed keys: \#{Enum.join(keys, \", \")}"),
              text("Active combinations: \#{Enum.join(combos, \", \")}")
            ])
          end
        }
      }
  """
  def keyboard_handler do
    %{
      type: :render_prop_component,
      render_fn: fn props, _context ->
        render_fn = Map.get(props, :render)
        track_combinations = Map.get(props, :track_combinations, [])

        render_keyboard_handler(render_fn, track_combinations)
      end
    }
  end

  @doc """
  Scroll tracker component that monitors scroll position and provides it via render prop.

  ## Props
  - `:render` - Function that receives `%{scroll_x, scroll_y, scroll_direction, is_scrolling}`
  - `:throttle_ms` - Throttle scroll events (default: 16ms for 60fps)

  ## Examples

      %{
        type: :scroll_tracker,
        attrs: %{
          throttle_ms: 50,
          render: fn %{scroll_y: y, scroll_direction: dir, is_scrolling: scrolling} ->
            column([
              text("Scroll Y: \#{y}"),
              text("Direction: \#{dir}"),
              text("Scrolling: \#{scrolling}")
            ])
          end
        }
      }
  """
  def scroll_tracker do
    %{
      type: :render_prop_component,
      render_fn: fn props, _context ->
        render_fn = Map.get(props, :render)
        throttle_ms = Map.get(props, :throttle_ms, 16)

        render_scroll_tracker(render_fn, throttle_ms)
      end
    }
  end

  @doc """
  Form state manager component that handles form state and validation via render prop.

  ## Props
  - `:render` - Function that receives form state and handlers
  - `:initial_values` - Initial form values
  - `:validation_schema` - Validation rules
  - `:on_submit` - Submit handler function

  ## Examples

      %{
        type: :form_provider,
        attrs: %{
          initial_values: %{name: "", email: ""},
          validation_schema: %{
            name: [{:required, "Name is required"}],
            email: [{:required, "Email is required"}, {:email, "Invalid email"}]
          },
          render: fn %{values: values, errors: errors, handle_change: change, handle_submit: submit} ->
            form([
              text_input(value: values.name, on_change: change.(:name)),
              case errors.name do
                nil -> []
                error -> error_text(error)
              end,
              text_input(value: values.email, on_change: change.(:email)),
              case errors.email do
                nil -> []
                error -> error_text(error)
              end,
              button(label: "Submit", on_click: submit)
            ])
          end
        }
      }
  """
  def form_provider do
    %{
      type: :render_prop_component,
      render_fn: fn props, _context ->
        render_fn = Map.get(props, :render)
        initial_values = Map.get(props, :initial_values, %{})
        validation_schema = Map.get(props, :validation_schema, %{})
        on_submit = Map.get(props, :on_submit)

        render_form_provider(
          render_fn,
          initial_values,
          validation_schema,
          on_submit
        )
      end
    }
  end

  @doc """
  Timer component that provides time-based state via render prop.

  ## Props
  - `:render` - Function that receives timer state
  - `:interval` - Update interval in milliseconds
  - `:duration` - Total duration (optional)
  - `:auto_start` - Whether to start automatically (default: true)

  ## Examples

      %{
        type: :timer,
        attrs: %{
          interval: 1000,
          duration: 60_000,  # 1 minute
          render: fn %{elapsed: elapsed, remaining: remaining, percentage: pct} ->
            column([
              text("Elapsed: \#{elapsed}ms"),
              text("Remaining: \#{remaining}ms"),
              progress_bar(percentage: pct)
            ])
          end
        }
      }
  """
  def timer do
    %{
      type: :render_prop_component,
      render_fn: fn props, _context ->
        render_fn = Map.get(props, :render)
        interval = Map.get(props, :interval, 1000)
        duration = Map.get(props, :duration)
        auto_start = Map.get(props, :auto_start, true)

        render_timer(render_fn, interval, duration, auto_start)
      end
    }
  end

  # Helper functions (placeholders for actual implementations)

  defp render_mouse_tracker(nil, _track_outside) do
    %{type: :text, attrs: %{content: "Error: Missing render prop"}}
  end

  defp render_mouse_tracker(render_fn, track_outside) do
    {mouse_pos, set_mouse_pos} = Hooks.use_state(%{x: 0, y: 0})
    {is_over, set_is_over} = Hooks.use_state(false)

    # Set up mouse event listeners
    Hooks.use_effect(
      fn ->
        # This would integrate with actual event system
        mouse_listener = fn event ->
          set_mouse_pos.(%{x: event.x, y: event.y})
        end

        enter_listener = fn _event ->
          set_is_over.(true)
        end

        leave_listener = fn _event ->
          set_is_over.(false)
        end

        # Register listeners (placeholder)
        register_mouse_events(
          mouse_listener,
          enter_listener,
          leave_listener,
          track_outside
        )

        # Cleanup function
        fn ->
          unregister_mouse_events(
            mouse_listener,
            enter_listener,
            leave_listener
          )
        end
      end,
      [track_outside]
    )

    render_state = %{
      mouse_x: mouse_pos.x,
      mouse_y: mouse_pos.y,
      is_over: is_over
    }

    render_fn.(render_state)
  end

  defp render_keyboard_handler(nil, _track_combinations) do
    %{type: :text, attrs: %{content: "Error: Missing render prop"}}
  end

  defp render_keyboard_handler(render_fn, track_combinations) do
    {pressed_keys, set_pressed_keys} = Hooks.use_state([])
    {active_combinations, set_active_combinations} = Hooks.use_state([])

    # Set up keyboard event listeners
    Hooks.use_effect(
      fn ->
        keydown_listener = fn event ->
          key = event.key
          set_pressed_keys.(make_add_key_fn(key))

          # Check for key combinations
          new_combinations =
            check_key_combinations(
              [key | pressed_keys],
              track_combinations
            )

          set_active_combinations.(new_combinations)
        end

        keyup_listener = fn event ->
          key = event.key
          set_pressed_keys.(make_delete_key_fn(key))
        end

        # Register listeners (placeholder)
        register_keyboard_events(keydown_listener, keyup_listener)

        # Cleanup function
        fn ->
          unregister_keyboard_events(keydown_listener, keyup_listener)
        end
      end,
      [track_combinations]
    )

    render_state = %{
      pressed_keys: pressed_keys,
      key_combinations: active_combinations
    }

    render_fn.(render_state)
  end

  defp render_scroll_tracker(nil, _throttle_ms) do
    %{type: :text, attrs: %{content: "Error: Missing render prop"}}
  end

  defp render_scroll_tracker(render_fn, throttle_ms) do
    {scroll_pos, set_scroll_pos} = Hooks.use_state(%{x: 0, y: 0})
    {scroll_direction, set_scroll_direction} = Hooks.use_state(:none)
    {is_scrolling, set_is_scrolling} = Hooks.use_state(false)

    # Throttled scroll handler
    throttled_scroll_handler =
      Hooks.use_callback(
        fn event ->
          new_x = event.scroll_x
          new_y = event.scroll_y

          # Determine scroll direction
          direction = determine_scroll_direction(new_x, new_y, scroll_pos)

          set_scroll_pos.(%{x: new_x, y: new_y})
          set_scroll_direction.(direction)
          set_is_scrolling.(true)

          # Clear scrolling state after a delay
          Process.send_after(self(), :clear_scrolling, throttle_ms * 3)
        end,
        [scroll_pos, throttle_ms]
      )

    # Set up scroll event listeners
    Hooks.use_effect(
      fn ->
        # Register throttled scroll listener (placeholder)
        register_scroll_events(throttled_scroll_handler, throttle_ms)

        # Cleanup function
        fn ->
          unregister_scroll_events(throttled_scroll_handler)
        end
      end,
      [throttled_scroll_handler]
    )

    # Handle clearing scrolling state
    Hooks.use_effect(fn ->
      receive do
        :clear_scrolling ->
          set_is_scrolling.(false)
      after
        0 -> :ok
      end
    end)

    render_state = %{
      scroll_x: scroll_pos.x,
      scroll_y: scroll_pos.y,
      scroll_direction: scroll_direction,
      is_scrolling: is_scrolling
    }

    render_fn.(render_state)
  end

  defp render_form_provider(
         nil,
         _initial_values,
         _validation_schema,
         _on_submit
       ) do
    %{type: :text, attrs: %{content: "Error: Missing render prop"}}
  end

  defp render_form_provider(
         render_fn,
         initial_values,
         validation_schema,
         on_submit
       ) do
    {values, set_values} = Hooks.use_state(initial_values)
    {errors, set_errors} = Hooks.use_state(%{})
    {is_submitting, set_is_submitting} = Hooks.use_state(false)

    # Validation function
    validate_field =
      Hooks.use_callback(
        fn field, value ->
          field_rules = Map.get(validation_schema, field, [])
          check_field_rules(field_rules, value, values)
        end,
        [validation_schema, values]
      )

    # Handle field changes
    handle_change =
      Hooks.use_callback(
        fn field ->
          fn value ->
            set_values.(make_update_field_fn(field, value))

            # Validate field
            error = validate_field.(field, value)
            set_errors.(make_handle_field_error_fn(error, field))
          end
        end,
        [set_values, set_errors, validate_field]
      )

    # Handle form submission
    handle_submit =
      Hooks.use_callback(
        fn ->
          # Validate all fields
          all_errors = validate_all_fields(values, validate_field)
          set_errors.(all_errors)

          submit_if_valid(
            all_errors,
            on_submit,
            values,
            set_is_submitting,
            set_errors
          )
        end,
        [values, errors, on_submit, validate_field]
      )

    render_state = %{
      values: values,
      errors: errors,
      is_submitting: is_submitting,
      handle_change: handle_change,
      handle_submit: handle_submit,
      set_field_value: fn field, value ->
        set_values.(fn current -> Map.put(current, field, value) end)
      end,
      reset_form: fn ->
        set_values.(initial_values)
        set_errors.(%{})
      end
    }

    render_fn.(render_state)
  end

  defp render_timer(nil, _interval, _duration, _auto_start) do
    %{type: :text, attrs: %{content: "Error: Missing render prop"}}
  end

  defp render_timer(render_fn, interval, duration, auto_start) do
    {elapsed, set_elapsed} = Hooks.use_state(0)
    {is_running, set_is_running} = Hooks.use_state(auto_start)
    {start_time, set_start_time} = Hooks.use_state(nil)

    # Timer effect
    Hooks.use_effect(
      fn ->
        handle_timer_effect(is_running, start_time, set_start_time, interval)
      end,
      [is_running, interval]
    )

    # Handle timer ticks
    Hooks.use_effect(fn ->
      receive do
        :timer_tick ->
          handle_timer_tick(start_time, set_elapsed, duration, set_is_running)
      after
        0 -> :ok
      end
    end)

    # Timer controls
    start_timer =
      Hooks.use_callback(
        fn ->
          set_is_running.(true)
          set_start_time.(System.monotonic_time(:millisecond))
          set_elapsed.(0)
        end,
        []
      )

    stop_timer =
      Hooks.use_callback(
        fn ->
          set_is_running.(false)
        end,
        []
      )

    reset_timer =
      Hooks.use_callback(
        fn ->
          set_elapsed.(0)
          set_start_time.(nil)
          set_is_running.(auto_start)
        end,
        [auto_start]
      )

    remaining = calculate_remaining(duration, elapsed)
    percentage = calculate_percentage(duration, elapsed)

    render_state = %{
      elapsed: elapsed,
      remaining: remaining,
      percentage: percentage,
      is_running: is_running,
      start: start_timer,
      stop: stop_timer,
      reset: reset_timer
    }

    render_fn.(render_state)
  end

  defp render_with_optional_cache(render_fn, render_state, nil) do
    render_fn.(render_state)
  end

  defp render_with_optional_cache(render_fn, render_state, cache_key) do
    Hooks.use_memo(
      fn ->
        render_fn.(render_state)
      end,
      [render_state, cache_key]
    )
  end

  defp add_key_if_not_present(key, keys) do
    case key in keys do
      true -> keys
      false -> [key | keys]
    end
  end

  defp handle_field_error(nil, field, current_errors) do
    Map.delete(current_errors, field)
  end

  defp handle_field_error(error, field, current_errors) do
    Map.put(current_errors, field, error)
  end

  defp submit_if_valid(
         all_errors,
         nil,
         _values,
         _set_is_submitting,
         _set_errors
       )
       when map_size(all_errors) == 0 do
    # No submit handler, do nothing
    :ok
  end

  defp submit_if_valid(
         all_errors,
         on_submit,
         values,
         set_is_submitting,
         set_errors
       )
       when map_size(all_errors) == 0 do
    set_is_submitting.(true)

    _ =
      Task.start(fn ->
        handle_form_submission_task(
          on_submit,
          values,
          set_is_submitting,
          set_errors
        )
      end)
  end

  defp submit_if_valid(
         _all_errors,
         _on_submit,
         _values,
         _set_is_submitting,
         _set_errors
       ) do
    # Has errors, don't submit
    :ok
  end

  defp handle_timer_effect(false, _start_time, _set_start_time, _interval) do
    # Timer not running, no effect
    nil
  end

  defp handle_timer_effect(true, nil, set_start_time, interval) do
    set_start_time.(System.monotonic_time(:millisecond))
    timer_ref = :timer.send_interval(interval, self(), :timer_tick)
    fn -> :timer.cancel(timer_ref) end
  end

  defp handle_timer_effect(true, _start_time, _set_start_time, interval) do
    timer_ref = :timer.send_interval(interval, self(), :timer_tick)
    fn -> :timer.cancel(timer_ref) end
  end

  defp handle_timer_tick(nil, _set_elapsed, _duration, _set_is_running) do
    # No start time, do nothing
    :ok
  end

  defp handle_timer_tick(start_time, set_elapsed, duration, set_is_running) do
    current_time = System.monotonic_time(:millisecond)
    new_elapsed = current_time - start_time
    set_elapsed.(new_elapsed)

    check_duration_reached(new_elapsed, duration, set_is_running)
  end

  defp check_duration_reached(_elapsed, nil, _set_is_running) do
    # No duration limit
    :ok
  end

  defp check_duration_reached(elapsed, duration, set_is_running)
       when elapsed >= duration do
    set_is_running.(false)
  end

  defp check_duration_reached(_elapsed, _duration, _set_is_running) do
    # Duration not reached
    :ok
  end

  defp calculate_remaining(nil, _elapsed), do: nil
  defp calculate_remaining(duration, elapsed), do: max(0, duration - elapsed)

  defp calculate_percentage(nil, _elapsed), do: 0

  defp calculate_percentage(duration, elapsed),
    do: min(100, elapsed / duration * 100)

  defp register_mouse_events(
         _mouse_listener,
         _enter_listener,
         _leave_listener,
         _track_outside
       ) do
    # This would integrate with the actual event system
    :ok
  end

  defp unregister_mouse_events(
         _mouse_listener,
         _enter_listener,
         _leave_listener
       ) do
    # This would integrate with the actual event system
    :ok
  end

  defp register_keyboard_events(_keydown_listener, _keyup_listener) do
    # This would integrate with the actual event system
    :ok
  end

  defp unregister_keyboard_events(_keydown_listener, _keyup_listener) do
    # This would integrate with the actual event system
    :ok
  end

  defp register_scroll_events(_scroll_listener, _throttle_ms) do
    # This would integrate with the actual event system
    :ok
  end

  defp unregister_scroll_events(_scroll_listener) do
    # This would integrate with the actual event system
    :ok
  end

  defp check_key_combinations(pressed_keys, track_combinations) do
    Enum.filter(track_combinations, fn combination ->
      case combination do
        :ctrl_c -> :ctrl in pressed_keys and :c in pressed_keys
        :ctrl_v -> :ctrl in pressed_keys and :v in pressed_keys
        :alt_tab -> :alt in pressed_keys and :tab in pressed_keys
        :escape -> :escape in pressed_keys
        _ -> false
      end
    end)
  end

  defp validate_rule(:required, value, _values) do
    value != nil and value != ""
  end

  defp validate_rule(:email, value, _values) do
    String.contains?(value, "@") and String.contains?(value, ".")
  end

  defp validate_rule({:min_length, min}, value, _values) do
    String.length(to_string(value)) >= min
  end

  defp validate_rule({:max_length, max}, value, _values) do
    String.length(to_string(value)) <= max
  end

  defp validate_rule(_rule, _value, _values) do
    # Unknown rule passes by default
    true
  end

  defp determine_scroll_direction(_new_x, new_y, scroll_pos)
       when new_y > scroll_pos.y,
       do: :down

  defp determine_scroll_direction(_new_x, new_y, scroll_pos)
       when new_y < scroll_pos.y,
       do: :up

  defp determine_scroll_direction(new_x, _new_y, scroll_pos)
       when new_x > scroll_pos.x,
       do: :right

  defp determine_scroll_direction(new_x, _new_y, scroll_pos)
       when new_x < scroll_pos.x,
       do: :left

  defp determine_scroll_direction(_new_x, _new_y, _scroll_pos), do: :none

  defp make_delete_key_fn(key) do
    fn keys -> List.delete(keys, key) end
  end

  defp validate_all_fields(values, validate_field) do
    Enum.reduce(values, %{}, fn {field, value}, acc ->
      case validate_field.(field, value) do
        nil -> acc
        error -> Map.put(acc, field, error)
      end
    end)
  end

  defp handle_form_submission_task(
         on_submit,
         values,
         set_is_submitting,
         set_errors
       ) do
    case Raxol.Core.ErrorHandling.safe_call(fn -> on_submit.(values) end) do
      {:ok, _} ->
        set_is_submitting.(false)

      {:error, {kind, reason}} ->
        set_errors.(%{
          _form: "Submit failed: #{inspect({kind, reason})}"
        })

        set_is_submitting.(false)

      {:error, reason} ->
        set_errors.(%{
          _form: "Submit failed: #{inspect(reason)}"
        })

        set_is_submitting.(false)
    end
  end

  defp make_add_key_fn(key) do
    fn keys -> add_key_if_not_present(key, keys) end
  end

  defp make_handle_field_error_fn(error, field) do
    fn current_errors -> handle_field_error(error, field, current_errors) end
  end

  defp make_update_field_fn(field, value) do
    fn current_values -> Map.put(current_values, field, value) end
  end

  defp check_field_rules(field_rules, value, values) do
    Enum.reduce_while(field_rules, nil, fn {rule, message}, _acc ->
      case validate_rule(rule, value, values) do
        true -> {:cont, nil}
        false -> {:halt, message}
      end
    end)
  end
end
