require Raxol.Core.Renderer.View

defmodule Raxol.UI.Components.Modal do
  @moduledoc """
  A modal component for displaying overlay dialogs like alerts, prompts, confirmations, and forms.
  """

  @typedoc """
  State for the Modal component.

  - :id - unique identifier
  - :visible - whether the modal is visible
  - :title - modal title
  - :content - modal content (text or view elements)
  - :buttons - list of {label, message} tuples
  - :type - modal type (:alert, :confirm, :prompt, :form)
  - :width - modal width
  - :style - style map
  - :form_state - state for prompt/form fields
  """
  @type t :: %__MODULE__{
          id: any(),
          visible: boolean(),
          title: String.t(),
          content: any(),
          buttons: list(),
          type: atom(),
          width: non_neg_integer(),
          style: map(),
          form_state: map()
        }

  # Use standard component behaviour
  use Raxol.UI.Components.Base.Component
  require Raxol.Core.Runtime.Log

  # Require view macros and components
  require Raxol.View.Elements
  # We will use elements directly: text_input, checkbox, dropdown
  # alias Raxol.UI.Components.Input.TextInput # Example, avoid direct component usage in render
  alias Raxol.UI.Components.Selection.Dropdown

  # Define state struct
  defstruct id: nil,
            visible: false,
            title: "",
            # Can be text or other view elements
            content: nil,
            # List of {label, message} tuples
            buttons: [],
            # :alert, :confirm, :prompt, :form
            type: :alert,
            # Example default
            width: 50,
            style: %{},
            # State for prompt/form
            # input_value: nil, # Removed: Merged into form_state for prompt
            form_state: %{fields: [], focus_index: 0}

  # Example field: %{id: :my_input, type: :text_input, label: "Name:", value: "", props: %{}, validate: ~r/.+/, error: nil}

  # --- Component Behaviour Callbacks ---

  @doc "Initializes the Modal component state from props."
  @impl Raxol.UI.Components.Base.Component
  @spec init(map()) :: map()
  def init(props) do
    # Initialize state based on props, likely called by a helper function
    # like alert/4, confirm/5 etc.
    state = %__MODULE__{
      id: Map.get(props, :id, nil),
      visible: Map.get(props, :visible, false),
      title: Map.get(props, :title, "Modal"),
      content: Map.get(props, :content),
      buttons: Map.get(props, :buttons, []),
      type: Map.get(props, :type, :alert),
      width: Map.get(props, :width, 50),
      style: Map.get(props, :style, %{}) || %{}
      # input_value: Map.get(props, :input_value, nil) # Removed
    }

    Raxol.Core.Runtime.Log.debug(
      "Modal init with props type: #{inspect(Map.get(props, :type, :alert))}, state type: #{inspect(state.type)}"
    )

    initialize_form_state(state, props)
  end

  # Helper to initialize form state based on props
  defp initialize_form_state(state, props) do
    cond do
      state.type == :prompt ->
        # Get initial value for prompt
        initial_value = Map.get(props, :input_value, "")
        # Treat prompt as a single-field form
        field = %{
          id: :prompt_input,
          type: :text_input,
          label: state.content || "Value:",
          value: initial_value,
          props: %{},
          validate: Map.get(props, :validate)
        }

        %{
          state
          | form_state: %{fields: [normalize_field(field)], focus_index: 0},
            content: nil
        }

      state.type == :form ->
        fields = Map.get(props, :fields, []) |> Enum.map(&normalize_field/1)
        %{state | form_state: %{fields: fields, focus_index: 0}}

      true ->
        state
    end
  end

  # Ensure basic field structure including :error
  defp normalize_field(field) when is_map(field) do
    Map.merge(
      %{
        id: nil,
        type: nil,
        label: "",
        value: nil,
        props: %{},
        validate: nil,
        error: nil
      },
      field
    )
  end

  # Ignore invalid field defs
  defp normalize_field(_), do: nil

  @doc "Updates the Modal component state in response to messages. Handles show/hide, button clicks, and form updates."
  @impl Raxol.UI.Components.Base.Component
  @spec update(term(), map()) :: {map(), list()}
  def update(msg, state) do
    Raxol.Core.Runtime.Log.debug(
      "Modal #{Map.get(state, :id, nil)} received message: #{inspect(msg)}"
    )

    if state.visible do
      Raxol.Core.Runtime.Log.debug(
        "Modal is visible, calling handle_visible_update with msg: #{inspect(msg)}"
      )

      handle_visible_update(msg, state)
    else
      handle_hidden_update(msg, state)
    end
  end

  defp handle_visible_update(msg, state) do
    case msg do
      :show ->
        handle_show(state)

      :hide ->
        handle_hide(state)

      {:button_click, button_msg} ->
        handle_button_click_msg(button_msg, state)

      {:field_update, field_id, new_value} ->
        update_field_value(state, field_id, new_value)

      :focus_next_field ->
        change_focus(state, 1)

      :focus_prev_field ->
        change_focus(state, -1)

      {:input_changed, value} when state.type == :prompt ->
        handle_prompt_input(state, value)

      _ ->
        handle_unknown_message(state, msg)
    end
  end

  defp handle_button_click_msg({:submit, original_msg}, state) do
    Raxol.Core.Runtime.Log.debug(
      "[DEBUG] handle_button_click_msg called with submit message: #{inspect(original_msg)} and state.visible=#{inspect(state.visible)}"
    )

    if state.type == :prompt do
      handle_prompt_submission(state, original_msg)
    else
      handle_form_submission(state, original_msg)
    end
  end

  defp handle_button_click_msg({:cancel, original_msg}, state),
    do: handle_cancel(state, original_msg)

  defp handle_button_click_msg(btn_msg, state),
    do: handle_button_click(state, btn_msg)

  defp handle_hidden_update(msg, state) do
    case msg do
      :show ->
        handle_show(state)

      _ ->
        {state, []}
    end
  end

  defp handle_show(state) do
    cmd = set_focus_command(state)
    new_state = %__MODULE__{state | visible: true}

    send(
      self(),
      {:modal_state_changed, Map.get(state, :id, nil), :visible, true}
    )

    {new_state, [cmd]}
  end

  defp handle_hide(state) do
    new_state = %__MODULE__{state | visible: false}

    send(
      self(),
      {:modal_state_changed, Map.get(state, :id, nil), :visible, false}
    )

    {new_state, []}
  end

  defp handle_cancel(state, original_msg) do
    new_state = %__MODULE__{state | visible: false}

    send(
      self(),
      {:modal_state_changed, Map.get(state, :id, nil), :visible, false}
    )

    {new_state, [original_msg]}
  end

  defp handle_button_click(state, btn_msg) do
    new_state = %__MODULE__{state | visible: false}

    send(
      self(),
      {:modal_state_changed, Map.get(state, :id, nil), :visible, false}
    )

    {new_state, [btn_msg]}
  end

  defp handle_prompt_input(state, value) do
    update_field_value(
      state,
      state.form_state.fields |> hd() |> Map.get(:id),
      value
    )
  end

  defp handle_unknown_message(state, msg) do
    Raxol.Core.Runtime.Log.warning(
      "Modal #{Map.get(state, :id, nil)} received unknown message: #{inspect(msg)}"
    )

    {state, []}
  end

  # --- Form Specific Update Helpers ---

  defp handle_form_submission(state, original_msg) do
    Raxol.Core.Runtime.Log.debug(
      "[DEBUG] handle_form_submission called with state.visible=#{inspect(state.visible)} and fields=#{inspect(state.form_state.fields)}"
    )

    validated_fields = Enum.map(state.form_state.fields, &validate_field/1)
    has_errors = Enum.any?(validated_fields, &(&1.error != nil))

    if has_errors do
      Raxol.Core.Runtime.Log.debug(
        "[DEBUG] handle_form_submission found errors: #{inspect(validated_fields)}"
      )

      new_form_state = %{state.form_state | fields: validated_fields}

      result =
        {%__MODULE__{state | form_state: new_form_state, visible: true}, []}

      Raxol.Core.Runtime.Log.debug(
        "[DEBUG] handle_form_submission returning (errors): #{inspect(result)}"
      )

      result
    else
      form_values = extract_form_values(validated_fields)
      cleared_fields = Enum.map(validated_fields, &Map.put(&1, :error, nil))
      new_form_state = %{state.form_state | fields: cleared_fields}

      new_state = %__MODULE__{
        state
        | visible: false,
          form_state: new_form_state
      }

      send(
        self(),
        {:modal_state_changed, Map.get(state, :id, nil), :visible, false}
      )

      result = {new_state, [{original_msg, form_values}]}

      Raxol.Core.Runtime.Log.debug(
        "[DEBUG] handle_form_submission returning (success): #{inspect(result)}"
      )

      result
    end
  end

  defp handle_prompt_submission(state, original_msg) do
    # If there are fields, validate as form
    if length(state.form_state.fields) > 0 do
      handle_form_submission(state, original_msg)
    else
      # No fields: just hide and send command
      new_state = %__MODULE__{state | visible: false}

      send(
        self(),
        {:modal_state_changed, Map.get(state, :id, nil), :visible, false}
      )

      {new_state, [{original_msg, %{}}]}
    end
  end

  # Validate a single field based on its :validate rule
  defp validate_field(field) do
    validator = field.validate
    value = field.value

    valid? =
      case validator do
        # No validation rule
        nil ->
          true

        regex when is_struct(regex) ->
          Regex.match?(regex, to_string(value))

        fun when is_function(fun, 1) ->
          fun.(value)

        _ ->
          Raxol.Core.Runtime.Log.warning(
            "Invalid validator for field #{field.id}: #{inspect(validator)}"
          )

          # Treat invalid validator as passing
          true
      end

    if valid? do
      # Clear any previous error
      %{field | error: nil}
    else
      # Basic error message, could be configurable
      %{field | error: "Invalid input"}
    end
  end

  # Helper to extract values from form fields
  defp extract_form_values(fields) do
    Enum.reduce(fields, %{}, fn field, acc ->
      Map.put(acc, field.id, field.value)
    end)
  end

  defp update_field_value(state, field_id, new_value) do
    updated_fields =
      Enum.map(state.form_state.fields, fn field ->
        if field.id == field_id do
          # Clear error on update
          %{field | value: new_value, error: nil}
        else
          field
        end
      end)

    new_form_state = %{state.form_state | fields: updated_fields}
    {%__MODULE__{state | form_state: new_form_state}, []}
  end

  defp change_focus(state, direction) do
    field_count = length(state.form_state.fields)

    Raxol.Core.Runtime.Log.debug(
      "[DEBUG] change_focus called with direction=#{inspect(direction)}, field_count=#{inspect(field_count)}, current_index=#{inspect(state.form_state.focus_index)}"
    )

    if field_count > 0 do
      new_index =
        rem(state.form_state.focus_index + direction + field_count, field_count)

      new_form_state = %{state.form_state | focus_index: new_index}
      new_state = %__MODULE__{state | form_state: new_form_state}

      Raxol.Core.Runtime.Log.debug(
        "[DEBUG] change_focus returning new_index=#{inspect(new_index)}, new_state.form_state.focus_index=#{inspect(new_state.form_state.focus_index)}"
      )

      {new_state, [set_focus_command(new_state)]}
    else
      {state, []}
    end
  end

  # Helper to generate set_focus command
  defp set_focus_command(state) do
    field_count = length(state.form_state.fields)

    if field_count > 0 do
      current_field =
        Enum.at(state.form_state.fields, state.form_state.focus_index)

      field_id = get_field_full_id(current_field, state)
      {:set_focus, field_id}
    else
      {:set_focus, state.id}
    end
  end

  # Helper to get field full ID (with modal prefix if modal has ID)
  defp get_field_full_id(field, state) do
    if Map.get(state, :id, nil),
      do: "#{Map.get(state, :id, nil)}.#{field.id}",
      else: field.id
  end

  defp handle_visible_event(:show, state) do
    new_state = %{state | visible: true}

    send(
      self(),
      {:modal_state_changed, Map.get(state, :id, nil), :visible, true}
    )

    {new_state, [set_focus_command(new_state)]}
  end

  defp handle_visible_event(:hide, state) do
    new_state = %{state | visible: false}

    send(
      self(),
      {:modal_state_changed, Map.get(state, :id, nil), :visible, false}
    )

    {new_state, []}
  end

  defp handle_escape_key(state) do
    cancel_msg = find_cancel_message(state.buttons)

    if cancel_msg do
      new_state = %{state | visible: false}

      send(
        self(),
        {:modal_state_changed, Map.get(state, :id, nil), :visible, false}
      )

      {new_state, [cancel_msg]}
    else
      handle_hide(state)
    end
  end

  defp handle_enter_key(state) do
    case find_submit_message(state.buttons) do
      {_label, submit_msg} ->
        # Instead of calling handle_form_submission directly, forward as update message
        update({:button_click, submit_msg}, state)

      nil ->
        {state, []}
    end
  end

  defp find_cancel_message(buttons) do
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

  defp find_submit_message(buttons) do
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

  @impl Raxol.UI.Components.Base.Component
  @spec handle_event(term(), map(), map()) :: {map(), list()}
  def handle_event(event, %{} = _props, state) do
    Raxol.Core.Runtime.Log.debug(
      "Modal #{Map.get(state, :id, nil)} received event: #{inspect(event)} with state.type: #{inspect(state.type)}"
    )

    IO.inspect(state.visible, label: "Modal visible state in handle_event")

    if state.visible do
      IO.inspect("Modal is visible, calling handle_visible_event")

      IO.inspect(
        "About to call handle_visible_event with event=#{inspect(event)}, state.id=#{inspect(Map.get(state, :id, nil))}"
      )

      result = handle_visible_event(event, state)
      IO.inspect("handle_visible_event returned: #{inspect(result)}")
      result
    else
      IO.inspect("Modal is not visible, returning unchanged state")
      {state, []}
    end
  end

  defp handle_visible_event(event, state) do
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

        update({:button_click, find_cancel_message(state.buttons)}, state)

      type == :key and key == "Enter" and state.type in [:prompt, :form] ->
        Raxol.Core.Runtime.Log.debug(
          "[DEBUG] handle_visible_event: Enter pattern matched"
        )

        case find_submit_message(state.buttons) do
          {_label, submit_msg} ->
            Raxol.Core.Runtime.Log.debug(
              "[DEBUG] handle_visible_event: found submit message: #{inspect(submit_msg)}"
            )

            update({:button_click, submit_msg}, state)

          nil ->
            Raxol.Core.Runtime.Log.debug(
              "[DEBUG] handle_visible_event: no submit message found"
            )

            {state, []}
        end

      type == :key and key == "Tab" and shift == false and
          state.type in [:prompt, :form] ->
        Raxol.Core.Runtime.Log.debug(
          "[DEBUG] handle_visible_event: Tab (next) pattern matched"
        )

        update(:focus_next_field, state)

      type == :key and key == "Tab" and shift == true and
          state.type in [:prompt, :form] ->
        Raxol.Core.Runtime.Log.debug(
          "[DEBUG] handle_visible_event: Tab (prev) pattern matched"
        )

        update(:focus_prev_field, state)

      true ->
        Raxol.Core.Runtime.Log.debug(
          "[DEBUG] handle_visible_event: no pattern matched, falling through to catch-all"
        )

        handle_visible_event_dispatch(event, state)
    end
  end

  defp handle_visible_event_dispatch(
         %{type: :key, data: %{key: "Escape"}},
         state
       ) do
    update({:button_click, find_cancel_message(state.buttons)}, state)
  end

  defp handle_visible_event_dispatch(
         %Raxol.Core.Events.Event{type: :key, data: %{key: "Escape"}},
         state
       ) do
    update({:button_click, find_cancel_message(state.buttons)}, state)
  end

  defp handle_visible_event_dispatch(
         %{type: :key, data: %{key: "Enter"}},
         state
       )
       when state.type in [:prompt, :form] do
    case find_submit_message(state.buttons) do
      {_label, submit_msg} ->
        update({:button_click, submit_msg}, state)

      nil ->
        {state, []}
    end
  end

  defp handle_visible_event_dispatch(
         %Raxol.Core.Events.Event{type: :key, data: %{key: "Enter"}},
         state
       )
       when state.type in [:prompt, :form] do
    case find_submit_message(state.buttons) do
      {_label, submit_msg} ->
        update({:button_click, submit_msg}, state)

      nil ->
        {state, []}
    end
  end

  defp handle_visible_event_dispatch(
         %{type: :key, data: %{key: "Tab", shift: false}},
         state
       )
       when state.type in [:prompt, :form] do
    update(:focus_next_field, state)
  end

  defp handle_visible_event_dispatch(
         %Raxol.Core.Events.Event{
           type: :key,
           data: %{key: "Tab", shift: false}
         },
         state
       )
       when state.type in [:prompt, :form] do
    update(:focus_next_field, state)
  end

  defp handle_visible_event_dispatch(
         %{type: :key, data: %{key: "Tab", shift: true}},
         state
       )
       when state.type in [:prompt, :form] do
    update(:focus_prev_field, state)
  end

  defp handle_visible_event_dispatch(
         %Raxol.Core.Events.Event{type: :key, data: %{key: "Tab", shift: true}},
         state
       )
       when state.type in [:prompt, :form] do
    update(:focus_prev_field, state)
  end

  defp handle_visible_event_dispatch({:input_changed, value}, state)
       when state.type == :prompt do
    handle_prompt_input(state, value)
  end

  defp handle_visible_event_dispatch(event, state) do
    {state, []}
  end

  # --- Render Logic ---

  @impl Raxol.UI.Components.Base.Component
  @spec render(map(), map()) :: any()
  def render(state, %{} = _props) do
    if state.visible do
      render_modal_content(state)
    else
      nil
    end
  end

  defp render_modal_content(state) do
    Raxol.View.Elements.box id: get_modal_box_id(state),
                            style: get_modal_style(state) do
      Raxol.View.Elements.column style: %{width: :fill, padding: 1} do
        build_modal_elements(
          render_title(state.title),
          render_content(state),
          render_buttons(state.buttons)
        )
      end
    end
  end

  defp render_title(title) do
    Raxol.View.Elements.label(content: title, style: %{bold: true})
  end

  defp render_content(state) do
    cond do
      is_binary(state.content) ->
        Raxol.View.Elements.label(content: state.content)

      state.type in [:prompt, :form] ->
        render_form_content(state)

      state.content != nil ->
        state.content

      true ->
        nil
    end
  end

  defp render_buttons(buttons) do
    Enum.map(buttons, fn {label, msg} ->
      Raxol.View.Elements.button(
        label: label,
        on_click: {:button_click, msg}
      )
    end)
  end

  defp get_modal_box_id(state) do
    if Map.get(state, :id, nil),
      do: "#{Map.get(state, :id, nil)}-box",
      else: nil
  end

  defp get_modal_style(state) do
    Map.merge(
      %{border: :double, width: state.width, align: :center},
      state.style
    )
  end

  defp build_modal_elements(title_element, content_element, button_elements) do
    [
      title_element,
      render_spacer(title_element && content_element),
      content_element,
      render_spacer(content_element && button_elements != []),
      render_button_row(button_elements)
    ]
    |> Enum.reject(&is_nil/1)
  end

  defp render_spacer(condition) do
    if condition, do: Raxol.View.Elements.label(content: "")
  end

  defp render_button_row(button_elements) do
    Raxol.View.Elements.row style: %{justify: :center, width: :fill, gap: 2} do
      button_elements
    end
  end

  # --- Internal Render Helpers ---

  defp render_form_content(state) do
    field_elements =
      Enum.with_index(state.form_state.fields)
      |> Enum.map(&render_field(&1, state))
      |> Enum.reject(&is_nil/1)

    Raxol.View.Elements.column style: %{width: :fill, gap: 1} do
      field_elements
    end
  end

  defp render_field({field, index}, state) do
    field_full_id = get_field_full_id(field, state)
    focused? = index == state.form_state.focus_index
    common_props = get_common_props(field, field_full_id, focused?)

    input_element = render_input_element(field, common_props)
    render_field_container(field, input_element)
  end

  defp get_field_full_id(field, state) do
    if Map.get(state, :id, nil),
      do: "#{Map.get(state, :id, nil)}.#{field.id}",
      else: field.id
  end

  defp get_common_props(field, field_full_id, focused?) do
    Map.merge(field.props || %{}, %{
      id: field_full_id,
      focused: focused?
    })
  end

  defp render_input_element(field, common_props) do
    case field.type do
      :text_input -> render_text_input(field, common_props)
      :checkbox -> render_checkbox(field, common_props)
      :dropdown -> render_dropdown(field, common_props)
      _ -> render_unsupported_field(field)
    end
  end

  defp render_text_input(field, common_props) do
    text_input_props =
      Map.merge(common_props, %{
        "value" => field.value || "",
        "on_change" => {:field_update, field.id}
      })

    Raxol.View.Elements.text_input(text_input_props)
  end

  defp render_checkbox(field, common_props) do
    checkbox_props =
      Map.merge(common_props, %{
        "checked" => !!field.value,
        "label" => "",
        "on_toggle" => {:field_update, field.id}
      })

    Raxol.View.Elements.checkbox(checkbox_props)
  end

  defp render_dropdown(field, common_props) do
    dropdown_props =
      Map.merge(common_props, %{
        "options" => field.options || [],
        "initial_value" => field.value,
        "width" => :fill,
        "on_change" => {:field_update, field.id}
      })

    %{type: Dropdown, attrs: dropdown_props}
  end

  defp render_unsupported_field(field) do
    Raxol.Core.Runtime.Log.warning(
      "Unsupported form field type in Modal: #{inspect(field.type)}"
    )

    Raxol.View.Elements.label(content: "[Unsupported Field: #{field.id}]")
  end

  defp render_field_container(field, input_element) do
    Raxol.View.Elements.column style: %{width: :fill, gap: 0} do
      [
        render_field_row(field, input_element),
        render_field_error(field)
      ]
      |> Enum.reject(&is_nil/1)
    end
  end

  defp render_field_row(field, input_element) do
    Raxol.View.Elements.row style: %{width: :fill, gap: 1} do
      [
        if(field.label,
          do:
            Raxol.View.Elements.label(content: field.label, style: %{width: 15})
        ),
        input_element
      ]
      |> Enum.reject(&is_nil/1)
    end
  end

  defp render_field_error(field) do
    if field.error do
      Raxol.View.Elements.row style: %{width: :fill} do
        Raxol.View.Elements.label(
          content: field.error,
          style: %{color: :red, padding_left: 16}
        )
      end
    end
  end

  # --- Public Helper Functions (Constructors) ---

  # Simplified
  @doc "Creates props for an alert modal."
  @spec alert(any(), any(), any(), Keyword.t()) :: map()
  def alert(id, title, content, opts \\ []) do
    props =
      Keyword.merge(
        [
          id: id,
          title: title,
          content: content,
          type: :alert,
          buttons: [{"OK", :ok}],
          visible: true
        ],
        opts
      )

    # Returns props map, caller uses Component.new(Modal, props)
    props
  end

  # Simplified
  @doc "Creates props for a confirmation modal."
  @spec confirm(any(), any(), any(), any(), any(), Keyword.t()) :: map()
  def confirm(
        id,
        title,
        content,
        on_confirm \\ :confirm,
        on_cancel \\ :cancel,
        opts \\ []
      ) do
    buttons = [{"Yes", on_confirm}, {"No", on_cancel}]

    props =
      Keyword.merge(opts,
        id: id,
        title: title,
        content: content,
        type: :confirm,
        buttons: buttons,
        visible: true
      )

    props
  end

  # Simplified
  @doc "Creates props for a prompt modal."
  @spec prompt(any(), any(), any(), any(), any(), Keyword.t()) :: map()
  def prompt(
        id,
        title,
        content,
        on_submit \\ :submit,
        on_cancel \\ :cancel,
        opts \\ []
      ) do
    # Prompt is now treated as a single-field form internally
    # The 'submit' message will carry the input value in the payload
    buttons = [{"Submit", {:submit, on_submit}}, {"Cancel", on_cancel}]

    props =
      Keyword.merge(opts,
        id: id,
        title: title,
        # Used for label if no field def provided
        content: content,
        type: :prompt,
        buttons: buttons,
        visible: true,
        # Initial value
        input_value: Keyword.get(opts, :default_value, ""),
        # Pass validation rule
        validate: Keyword.get(opts, :validate)
      )

    props
  end

  @doc """
  Creates props for a form modal.

  `fields` should be a list of maps, each defining a form field:
  `%{id: :atom, type: :text_input | :checkbox | :dropdown, label: "string", value: initial_value, props: keyword_list, options: list, validate: regex | function}`
  (options only for dropdown)
  """
  @spec form(any(), any(), list(), any(), any(), Keyword.t()) :: map()
  def form(
        id,
        title,
        fields,
        on_submit \\ :submit,
        on_cancel \\ :cancel,
        opts \\ []
      ) do
    buttons = [{"Submit", {:submit, on_submit}}, {"Cancel", on_cancel}]

    props =
      Keyword.merge(opts,
        id: id,
        title: title,
        fields: fields,
        type: :form,
        buttons: buttons,
        visible: true
      )

    props
  end
end
