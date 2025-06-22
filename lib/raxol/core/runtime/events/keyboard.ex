defmodule Raxol.Core.Runtime.Events.Keyboard do
  @moduledoc """
  Handles keyboard event processing in the Raxol system.

  This module is responsible for:
  * Processing keyboard events
  * Handling special key combinations
  * Converting keyboard events to application messages
  """

  require Raxol.Core.Runtime.Log
  import Raxol.Guards
  alias Raxol.Core.Events.Event

  @doc """
  Processes a keyboard event and determines if it should be handled by the application
  or if it's a system-level command.

  ## Parameters
  - `event`: The keyboard event to process
  - `state`: The current application state

  ## Returns
  `{:system, command, state}` if it's a system command,
  `{:application, event, state}` if it should be handled by the application,
  `{:ignore, state}` if the event should be ignored.
  """
  def process_keyboard_event(%Event{type: :key, data: key_data} = event, state) do
    key = key_data.key
    modifiers = key_data.modifiers || []

    cond do
      # Check for quit key combination
      quit_key?(key, modifiers, state.quit_keys) ->
        {:system, :quit, state}

      # Check for debug toggle key combination
      debug_toggle_key?(key, modifiers) ->
        new_debug_mode = not state.debug_mode

        Raxol.Core.Runtime.Log.info(
          "Debug mode #{if new_debug_mode, do: "enabled", else: "disabled"}"
        )

        {:system, {:set_debug_mode, new_debug_mode},
         %{state | debug_mode: new_debug_mode}}

      # Other keyboard handling logic
      true ->
        {:application, event, state}
    end
  end

  @doc """
  Converts a keyboard event to an application message.

  ## Parameters
  - `event`: The keyboard event to convert

  ## Returns
  A message that can be understood by the application's update function.
  """
  def convert_to_message(%Event{type: :key, data: key_data} = _event) do
    key = key_data.key
    modifiers = key_data.modifiers || []

    # Convert key to a more user-friendly format
    key_name = get_key_name(key)

    # Format modifiers
    mod_list = format_modifiers(modifiers)

    # Combine into a message
    if Enum.empty?(mod_list) do
      {:key_press, key_name}
    else
      {:key_press, key_name, mod_list}
    end
  end

  @doc """
  Checks if a key combination matches any of the application's registered shortcuts.

  ## Parameters
  - `event`: The keyboard event to check
  - `shortcuts`: Map of registered shortcuts

  ## Returns
  `{:ok, action}` if a match is found, `:none` otherwise.
  """
  def check_shortcuts(%Event{type: :key, data: key_data} = _event, shortcuts)
      when map?(shortcuts) do
    key = key_data.key
    modifiers = key_data.modifiers || []

    # Check each shortcut for a match
    shortcuts
    |> Enum.find(fn {_action, shortcut} ->
      shortcut_match?(key, modifiers, shortcut)
    end)
    |> case do
      {action, _shortcut} -> {:ok, action}
      nil -> :none
    end
  end

  # Private functions

  defp quit_key?(key, modifiers, quit_keys) do
    Enum.any?(quit_keys, &matches_quit_key(&1, key, modifiers))
  end

  defp matches_quit_key(quit_key, key, modifiers) do
    case quit_key do
      key_val when atom?(key_val) or integer?(key_val) -> key == key_val
      {key_val, mods} when list?(mods) -> key == key_val and modifiers_match?(modifiers, mods)
      :ctrl_c -> key == ?c and Keyword.get(modifiers, :ctrl, false)
      :ctrl_q -> key == ?q and Keyword.get(modifiers, :ctrl, false)
      {:unrecognized, other} -> log_unknown_quit_key(other)
      _ -> false
    end
  end

  defp log_unknown_quit_key(other) do
    Raxol.Core.Runtime.Log.warning_with_context(
      "Unknown quit key format: #{inspect(other)}",
      %{}
    )
    false
  end

  defp debug_toggle_key?(key, modifiers) do
    # Default debug toggle is Ctrl+D
    key == ?d and Keyword.get(modifiers, :ctrl, false)
  end

  defp shortcut_match?(key, modifiers, shortcut) do
    case shortcut do
      key_val when atom?(key_val) or integer?(key_val) ->
        key == key_val and
          Enum.all?(modifiers, fn {_, active} -> not active end)

      {key_val, mods} when list?(mods) ->
        key == key_val and modifiers_match?(modifiers, mods)

      _ ->
        false
    end
  end

  defp modifiers_match?(actual_mods, expected_mods) do
    Enum.all?(expected_mods, fn expected_mod ->
      Keyword.get(actual_mods, expected_mod, false)
    end)
  end

  @key_name_map %{
    1 => :ctrl_a,
    2 => :ctrl_b,
    3 => :ctrl_c,
    4 => :ctrl_d,
    5 => :ctrl_e,
    13 => :enter,
    27 => :escape,
    9 => :tab,
    32 => :space,
    127 => :backspace
  }

  defp get_key_name(key) when integer?(key) and key >= 32 and key <= 126 do
    <<key::utf8>>
  end

  defp get_key_name(key) when atom?(key) do
    key
  end

  defp get_key_name(key) do
    Map.get(@key_name_map, key, key)
  end

  defp format_modifiers(modifiers) do
    modifiers
    |> Enum.filter(fn {_, active} -> active end)
    |> Enum.map(fn {mod, _} -> mod end)
  end
end
