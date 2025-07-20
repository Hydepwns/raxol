defmodule Raxol.UI.Components.Modal.Events do
  @moduledoc """
  Event handling and keyboard navigation for the Modal component.
  """

  require Raxol.Core.Runtime.Log

  @doc "Handles visible events with keyboard navigation."
  @spec handle_visible_event(any(), map()) :: {map(), list()}
  def handle_visible_event(event, state) do
    type = Map.get(event, :type)
    data = Map.get(event, :data)
    key = data && Map.get(data, :key)
    shift = data && Map.get(data, :shift)

    Raxol.Core.Runtime.Log.debug(
      "[DEBUG] handle_visible_event: type=#{inspect(type)}, key=#{inspect(key)}, shift=#{inspect(shift)}"
    )

    Raxol.Core.Runtime.Log.debug(
      "[DEBUG] handle_visible_event: state.type=#{inspect(state.type)}"
    )

    cond do
      type == :key and key == "Escape" ->
        Raxol.Core.Runtime.Log.debug(
          "[DEBUG] handle_visible_event: Escape pattern matched"
        )

        # Delegate to update function
        {:button_click, find_cancel_message(state.buttons)}

      type == :key and key == "Enter" and state.type in [:prompt, :form] ->
        Raxol.Core.Runtime.Log.debug(
          "[DEBUG] handle_visible_event: Enter pattern matched"
        )

        case find_submit_message(state.buttons) do
          {_label, submit_msg} ->
            Raxol.Core.Runtime.Log.debug(
              "[DEBUG] handle_visible_event: found submit message: #{inspect(submit_msg)}"
            )

            {:button_click, submit_msg}

          nil ->
            Raxol.Core.Runtime.Log.debug(
              "[DEBUG] handle_visible_event: no submit message found"
            )

            nil
        end

      type == :key and key == "Tab" and shift == false and
          state.type in [:prompt, :form] ->
        Raxol.Core.Runtime.Log.debug(
          "[DEBUG] handle_visible_event: Tab (next) pattern matched"
        )

        :focus_next_field

      type == :key and key == "Tab" and shift == true and
          state.type in [:prompt, :form] ->
        Raxol.Core.Runtime.Log.debug(
          "[DEBUG] handle_visible_event: Tab (prev) pattern matched"
        )

        :focus_prev_field

      true ->
        Raxol.Core.Runtime.Log.debug(
          "[DEBUG] handle_visible_event: no pattern matched, falling through to catch-all"
        )

        handle_visible_event_dispatch(event, state)
    end
  end

  @doc "Handles visible event dispatch for different event types."
  @spec handle_visible_event_dispatch(any(), map()) :: {map(), list()}
    def handle_visible_event_dispatch(
         %{type: :key, data: %{key: "Escape"}},
         state
       ) do
    {:button_click, find_cancel_message(state.buttons)}
  end

  def handle_visible_event_dispatch(
         %Raxol.Core.Events.Event{type: :key, data: %{key: "Escape"}},
         state
       ) do
    {:button_click, find_cancel_message(state.buttons)}
  end

    def handle_visible_event_dispatch(
         %{type: :key, data: %{key: "Enter"}},
         state
       )
       when state.type in [:prompt, :form] do
    case find_submit_message(state.buttons) do
      {_label, submit_msg} ->
        {:button_click, submit_msg}

      nil ->
        nil
    end
  end

  def handle_visible_event_dispatch(
         %Raxol.Core.Events.Event{type: :key, data: %{key: "Enter"}},
         state
       )
       when state.type in [:prompt, :form] do
    case find_submit_message(state.buttons) do
      {_label, submit_msg} ->
        {:button_click, submit_msg}

      nil ->
        nil
    end
  end

  def handle_visible_event_dispatch(
        %{type: :key, data: %{key: "Tab", shift: false}},
        state
      )
      when state.type in [:prompt, :form] do
    :focus_next_field
  end

  def handle_visible_event_dispatch(
        %Raxol.Core.Events.Event{
          type: :key,
          data: %{key: "Tab", shift: false}
        },
        state
      )
      when state.type in [:prompt, :form] do
    :focus_next_field
  end

  def handle_visible_event_dispatch(
        %{type: :key, data: %{key: "Tab", shift: true}},
        state
      )
      when state.type in [:prompt, :form] do
    :focus_prev_field
  end

  def handle_visible_event_dispatch(
        %Raxol.Core.Events.Event{type: :key, data: %{key: "Tab", shift: true}},
        state
      )
      when state.type in [:prompt, :form] do
    :focus_prev_field
  end

  def handle_visible_event_dispatch({:input_changed, value}, state)
      when state.type == :prompt do
    {:input_changed, value}
  end

  def handle_visible_event_dispatch(_event, _state) do
    nil
  end

  @doc "Finds cancel message from button list."
  @spec find_cancel_message(list()) :: any()
  def find_cancel_message(buttons) do
    Raxol.Core.Runtime.Log.debug(
      "find_cancel_message called with buttons: #{inspect(buttons)}"
    )

    result =
      Enum.find_value(buttons, nil, fn {_label, msg} ->
        cond do
          msg == :cancel ->
            msg

          msg == :form_canceled ->
            msg

          match?({:cancel, _}, msg) ->
            msg

          is_atom(msg) and String.ends_with?(Atom.to_string(msg), "cancel") ->
            msg

          # Handle the case where cancel is just an atom (not a tuple)
          is_atom(msg) ->
            msg

          true ->
            nil
        end
      end)

    Raxol.Core.Runtime.Log.debug(
      "find_cancel_message result: #{inspect(result)}"
    )

    result
  end

  @doc "Finds submit message from button list."
  @spec find_submit_message(list()) :: {any(), any()} | nil
  def find_submit_message(buttons) do
    Raxol.Core.Runtime.Log.debug(
      "find_submit_message called with buttons: #{inspect(buttons)}"
    )

    result =
      Enum.find(buttons, fn {_, msg} ->
        case msg do
          {:submit, _} -> true
          _ -> false
        end
      end)

    Raxol.Core.Runtime.Log.debug(
      "find_submit_message result: #{inspect(result)}"
    )

    result
  end
end
