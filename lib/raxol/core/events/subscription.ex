defmodule Raxol.Core.Events.Subscription do
  @moduledoc """
  Provides helpers for managing event subscriptions.

  This module makes it easy to:
  * Subscribe to specific event types
  * Filter events based on criteria
  * Handle event cleanup
  * Manage multiple subscriptions
  """

  alias Raxol.Core.Events.{Manager}

  @type subscription_ref :: reference()
  @type subscription_opts :: keyword()

  @doc """
  Subscribes to keyboard events with optional key filters.

  ## Options
  * `:keys` - List of specific keys to match
  * `:exclude_keys` - List of keys to ignore

  ## Example
      subscribe_keyboard(keys: [:enter, :esc])
      subscribe_keyboard(exclude_keys: [:tab])
  """
  def subscribe_keyboard(opts \\ []) do
    keys = Keyword.get(opts, :keys)
    _exclude_keys = Keyword.get(opts, :exclude_keys, [])

    filter_opts =
      if keys do
        [key: keys]
      else
        []
      end

    Manager.subscribe(:key, filter_opts)
  end

  @doc """
  Subscribes to mouse events with optional button and position filters.

  ## Options
  * `:buttons` - List of mouse buttons to match
  * `:drag_only` - Only match drag events
  * `:click_only` - Only match click events
  * `:area` - Tuple of {x, y, width, height} to match position

  ## Example
      subscribe_mouse(buttons: [:left, :right])
      subscribe_mouse(area: {0, 0, 10, 10})
  """
  def subscribe_mouse(opts \\ []) do
    buttons = Keyword.get(opts, :buttons)
    drag_only = Keyword.get(opts, :drag_only, false)
    click_only = Keyword.get(opts, :click_only, false)
    area = Keyword.get(opts, :area)

    filter_opts =
      []
      |> add_filter(:mouse_button, buttons)
      |> add_filter(:drag, if(drag_only, do: true))
      |> add_filter(:click, if(click_only, do: true))
      |> add_filter(:area, area)

    Manager.subscribe(:mouse, filter_opts)
  end

  @doc """
  Subscribes to window events with optional action filters.

  ## Options
  * `:actions` - List of window actions to match (:resize, :focus, :blur)

  ## Example
      subscribe_window(actions: [:resize])
  """
  def subscribe_window(opts \\ []) do
    actions = Keyword.get(opts, :actions)

    filter_opts =
      if actions do
        [window_action: actions]
      else
        []
      end

    Manager.subscribe(:window, filter_opts)
  end

  @doc """
  Subscribes to timer events with optional data matching.

  ## Options
  * `:match` - Pattern to match against timer data

  ## Example
      subscribe_timer(match: :tick)
  """
  def subscribe_timer(opts \\ []) do
    match = Keyword.get(opts, :match)

    filter_opts =
      if match do
        [data: match]
      else
        []
      end

    Manager.subscribe(:timer, filter_opts)
  end

  @doc """
  Subscribes to custom events with data matching.

  ## Options
  * `:match` - Pattern to match against custom event data

  ## Example
      subscribe_custom(match: {:user_action, _})
  """
  def subscribe_custom(opts \\ []) do
    match = Keyword.get(opts, :match)

    filter_opts =
      if match do
        [data: match]
      else
        []
      end

    Manager.subscribe(:custom, filter_opts)
  end

  @doc """
  Unsubscribes from events using the subscription reference.
  """
  def unsubscribe(ref) when is_reference(ref) do
    Manager.unsubscribe(ref)
  end

  @doc """
  Unsubscribes from multiple subscriptions.
  """
  def unsubscribe_all(refs) when is_list(refs) do
    Enum.each(refs, &unsubscribe/1)
  end

  # Private Helpers

  defp add_filter(opts, _key, nil), do: opts
  defp add_filter(opts, key, value), do: Keyword.put(opts, key, value)
end 