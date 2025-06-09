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
          form_state: map(),
          mounted: boolean(),
          render_count: non_neg_integer(),
          focused: boolean(),
          disabled: boolean()
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
            form_state: %{fields: [], focus_index: 0},
            mounted: false,
            render_count: 0,
            focused: false,
            disabled: false

  # Example field: %{id: :my_input, type: :text_input, label: "Name:", value: "", props: %{}, validate: ~r/.+/, error: nil}

  # --- Component Behaviour Callbacks ---

  @doc "Initializes the Modal component state from props."
  @impl Raxol.UI.Components.Base.Component
  @spec init(map()) :: map()
  def init(props) when is_map(props) do
    # If visible is not set in props, default to true for alert, confirm, prompt, form
    visible =
      case Map.get(props, :visible, :unset) do
        :unset ->
          type = Map.get(props, :type, :alert)
          if type in [:alert, :confirm, :prompt, :form], do: true, else: false

        v ->
          v
      end

    state = %__MODULE__{
      id: Map.get(props, :id, nil),
      visible: visible,
      title: Map.get(props, :title, "Modal"),
      content: Map.get(props, :content),
      buttons: Map.get(props, :buttons, []),
      type: Map.get(props, :type, :alert),
      width:
        if(is_map(props),
          do: Map.get(props, :width, 50),
          else: if(is_tuple(props), do: elem(props, 0), else: 50)
        ),
      style: Map.get(props, :style, %{}) || %{},
      mounted: Map.get(props, :mounted, false),
      render_count: Map.get(props, :render_count, 0),
      focused: Map.get(props, :focused, false),
      disabled: Map.get(props, :disabled, false)
    }

    # Always set test_pid if present in props
    state =
      if Map.has_key?(props, :test_pid),
        do: Map.put(state, :test_pid, props.test_pid),
        else: state

    initialize_form_state(state, props)
  end

  def init(_), do: %__MODULE__{type: :alert, mounted: false, render_count: 0}

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
        raw_fields = Map.get(props, :fields, [])

        fields =
          cond do
            is_list(raw_fields) ->
              Enum.map(raw_fields, &normalize_field/1)

            is_map(raw_fields) ->
              raw_fields |> Map.values() |> Enum.map(&normalize_field/1)

            true ->
              []
          end

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
    # Always set test_pid if present in state or props
    test_pid = Map.get(state, :test_pid, nil)
    state = if test_pid, do: Map.put(state, :test_pid, test_pid), else: state

    Raxol.Core.Runtime.Log.debug(
      "Modal #{Map.get(state, :id, nil)} received message: #{inspect(msg)}"
    )

    case msg do
      :focus_next_field ->
        do_change_focus(state, 1)

      :focus_prev_field ->
        do_change_focus(state, -1)

      :show ->
        cmds = set_focus_command(%{state | visible: true})
        new_state = %{state | visible: true}

        send(
          test_pid || self(),
          {:modal_state_changed, Map.get(state, :id, nil), :visible, true}
        )

        {new_state, List.flatten(cmds)}

      :hide ->
        new_state = %{state | visible: false}

        send(
          test_pid || self(),
          {:modal_state_changed, Map.get(state, :id, nil), :visible, false}
        )

        {new_state, []}

      {:button_click, {:submit, original_msg}} ->
        handle_form_submission(state, original_msg)

      {:button_click, {:cancel, original_msg}} ->
        new_state = %{state | visible: false}

        send(
          test_pid || self(),
          {:modal_state_changed, Map.get(state, :id, nil), :visible, false}
        )

        {new_state, List.wrap(original_msg)}

      {:button_click, btn_msg} ->
        new_state = %{state | visible: false}

        send(
          test_pid || self(),
          {:modal_state_changed, Map.get(state, :id, nil), :visible, false}
        )

        {new_state, List.wrap(btn_msg)}

      {:field_update, field_id, new_value} ->
        update_field_value(state, field_id, new_value)

      {:input_changed, value} when state.type == :prompt ->
        update_field_value(
          state,
          state.form_state.fields |> hd() |> Map.get(:id),
          value
        )

      _ ->
        Raxol.Core.Runtime.Log.warning(
          "Modal #{Map.get(state, :id, nil)} received unknown message: #{inspect(msg)}"
        )

        {state, []}
    end
  end

  # Refactored focus change logic
  defp do_change_focus(state, direction) do
    field_count = length(state.form_state.fields)

    if field_count > 0 do
      new_index =
        rem(state.form_state.focus_index + direction + field_count, field_count)

      new_form_state = %{state.form_state | focus_index: new_index}
      new_state = %{state | form_state: new_form_state}
      cmds = set_focus_command(new_state)
      {new_state, List.flatten(cmds)}
    else
      # If no fields, still return a focus command for the modal id (if present)
      cmds = set_focus_command(state)
      {state, List.flatten(cmds)}
    end
  end

  # --- Form Specific Update Helpers ---

  # Handle form submission: validate fields, update state, return commands
  defp handle_form_submission(state, original_msg) do
    validated_fields = Enum.map(state.form_state.fields, &validate_field/1)
    has_errors = Enum.any?(validated_fields, &(&1.error != nil))

    if has_errors do
      # Update state with validation errors, don't submit
      new_form_state = %{state.form_state | fields: validated_fields}
      {%{state | form_state: new_form_state}, []}
    else
      # All valid: extract values, clear errors, hide modal, send submit command
      form_values = extract_form_values(validated_fields)
      cleared_fields = Enum.map(validated_fields, &Map.put(&1, :error, nil))
      new_form_state = %{state.form_state | fields: cleared_fields}

      {%{state | visible: false, form_state: new_form_state},
       [{original_msg, form_values}]}
    end
  end

  # Validate a single field based on its :validate rule
  defp validate_field(field) do
    validator = field.validate
    value = field.value

    is_valid =
      case validator do
        # No validation rule
        nil ->
          true

        regex when is_struct(regex, Regex) ->
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

    if is_valid do
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

  # Helper to update a specific field's value and clear its error
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
    {%{state | form_state: new_form_state}, []}
  end

  # Helper to generate focus command for the focused field
  defp set_focus_command(state) do
    focused_field =
      Enum.at(state.form_state.fields, state.form_state.focus_index)

    command =
      if focused_field do
        field_full_id =
          case Map.get(state, :id, nil) do
            nil -> focused_field.id
            id -> "#{id}.#{focused_field.id}"
          end

        {:set_focus, field_full_id}
      else
        {:set_focus, Map.get(state, :id, nil)}
      end

    [command]
  end

  @impl Raxol.UI.Components.Base.Component
  @spec handle_event(term(), map(), map()) :: {map(), list()}
  def handle_event(event, %{} = props, state) do
    # Always preserve test_pid in state
    state =
      if Map.has_key?(state, :test_pid),
        do: state,
        else: Map.put(state, :test_pid, Map.get(props, :test_pid, nil))

    Raxol.Core.Runtime.Log.debug(
      "Modal #{Map.get(state, :id, nil)} received event: #{inspect(event)}"
    )

    if state.visible do
      case event do
        %{type: :key, data: %{key: "Escape"}} ->
          # Restore: if a cancel button is found, return {new_state, [cancel_msg]} and send modal_state_changed
          cancel_tuple =
            Enum.find_value(state.buttons, nil, fn {label, msg} ->
              label_str = to_string(label) |> String.downcase()

              msg_is_cancel =
                cond do
                  is_atom(msg) ->
                    String.contains?(Atom.to_string(msg), "cancel")

                  is_binary(msg) ->
                    String.contains?(String.downcase(msg), "cancel")

                  is_tuple(msg) ->
                    Enum.any?(Tuple.to_list(msg), fn part ->
                      (is_atom(part) and
                         String.contains?(Atom.to_string(part), "cancel")) or
                        (is_binary(part) and
                           String.contains?(String.downcase(part), "cancel"))
                    end)

                  true ->
                    false
                end

              if String.contains?(label_str, "cancel") or msg_is_cancel,
                do: msg,
                else: nil
            end)

          if cancel_tuple do
            test_pid = Map.get(state, :test_pid, nil)
            new_state = %{state | visible: false}

            send(
              test_pid || self(),
              {:modal_state_changed, Map.get(state, :id, nil), :visible, false}
            )

            {new_state, List.wrap(cancel_tuple)}
          else
            update(:hide, state)
          end

        %{type: :key, data: %{key: "Enter"}}
        when state.type in [:prompt, :form] ->
          submit_msg_tuple =
            Enum.find(state.buttons, fn {_, msg_tuple} ->
              elem(msg_tuple, 0) == :submit
            end)

          if submit_msg_tuple do
            {_label, submit_msg} = submit_msg_tuple
            update({:button_click, submit_msg}, state)
          else
            {state, []}
          end

        %{type: :key, data: %{key: "Tab", shift: false}}
        when state.type in [:prompt, :form] ->
          do_change_focus(state, 1)

        %{type: :key, data: %{key: "Tab", shift: true}}
        when state.type in [:prompt, :form] ->
          do_change_focus(state, -1)

        _ ->
          {state, []}
      end
    else
      {state, []}
    end
  end

  # --- Render Logic ---

  @impl Raxol.UI.Components.Base.Component
  @spec render(map(), map()) :: any()
  def render(state, %{} = _props) do
    if state.visible do
      # Render modal content (title, body, buttons)
      # Use View Elements macros

      title_element =
        Raxol.View.Elements.label(content: state.title, style: %{bold: true})

      content_element =
        cond do
          # Render based on content type (text, custom elements, form)
          is_binary(state.content) ->
            Raxol.View.Elements.label(content: state.content)

          # Handle prompt/form input rendering
          state.type in [:prompt, :form] ->
            render_form_content(state)

          # Assume it's already a view element/list if not text
          state.content != nil ->
            state.content

          true ->
            # No content
            nil
        end

      button_elements =
        Enum.map(state.buttons, fn {label, msg} ->
          # Pass the original message tuple to the button
          Raxol.View.Elements.button(
            label: label,
            on_click: {:button_click, msg}
          )
        end)

      # Use a unique ID for the modal box itself if the state has an ID
      modal_box_id =
        if Map.get(state, :id, nil),
          do: "#{Map.get(state, :id, nil)}-box",
          else: nil

      Raxol.View.Elements.box id: modal_box_id,
                              style:
                                Map.merge(
                                  %{
                                    border: :double,
                                    width: state.width,
                                    align: :center
                                  },
                                  state.style
                                ) do
        Raxol.View.Elements.column style: %{width: :fill, padding: 1} do
          [
            title_element,
            # Spacer
            if(title_element && content_element,
              do: Raxol.View.Elements.label(content: "")
            ),
            content_element,
            # Spacer
            if(content_element && button_elements != [],
              do: Raxol.View.Elements.label(content: "")
            ),
            Raxol.View.Elements.row style: %{
                                      justify: :center,
                                      width: :fill,
                                      gap: 2
                                    } do
              button_elements
            end
          ]
          |> Enum.reject(&is_nil(&1))
        end
      end

      # Modal needs to be wrapped in something that centers it or overlays it.
      # This simple render just returns the box structure.
      # The runtime/layout needs to handle overlay placement.
    else
      # Render nothing if not visible
      nil
    end
  end

  # --- Internal Render Helpers ---

  defp render_form_content(state) do
    # Render specific inputs for prompt/form types
    # Raxol.Core.Runtime.Log.debug("[Render Form] Processing #{length(state.form_state.fields)} fields.")
    field_elements =
      Enum.with_index(state.form_state.fields)
      |> Enum.map(fn {field, index} ->
        # Raxol.Core.Runtime.Log.debug("[Render Form] Processing field ##{index}: #{inspect field.id}")
        # Construct the full ID path for focus management if modal has ID
        field_full_id =
          if Map.get(state, :id, nil),
            do: "#{Map.get(state, :id, nil)}.#{field.id}",
            else: field.id

        is_focused = index == state.form_state.focus_index

        # Common props: merge field-specific props with focus and ID
        common_props =
          Map.merge(field.props || %{}, %{
            id: field_full_id,
            focused: is_focused
          })

        input_element =
          case field.type do
            :text_input ->
              text_input_props =
                Map.merge(common_props, %{
                  "value" => field.value || "",
                  "on_change" => {:field_update, field.id}
                  # Add placeholder etc. if needed from field.props
                })

              Raxol.View.Elements.text_input(text_input_props)

            :checkbox ->
              # Ensure boolean
              checkbox_props =
                Map.merge(common_props, %{
                  "checked" => !!field.value,
                  # Label is rendered separately
                  "label" => "",
                  "on_toggle" => {:field_update, field.id}
                })

              Raxol.View.Elements.checkbox(checkbox_props)

            :dropdown ->
              dropdown_props =
                Map.merge(common_props, %{
                  # Expecting [{label, value}]
                  "options" => field.options || [],
                  # Use initial_value for Dropdown init
                  "initial_value" => field.value,
                  # Example width, might need adjustment
                  "width" => :fill,
                  "on_change" => {:field_update, field.id}
                })

              # Represent the component as a map for the renderer
              %{type: Dropdown, attrs: dropdown_props}

            _ ->
              Raxol.Core.Runtime.Log.warning(
                "Unsupported form field type in Modal: #{inspect(field.type)}"
              )

              Raxol.View.Elements.label(
                content: "[Unsupported Field: #{field.id}]"
              )
          end

        # Render label, field, and error message in a column
        Raxol.View.Elements.column style: %{width: :fill, gap: 0} do
          [
            Raxol.View.Elements.row style: %{width: :fill, gap: 1} do
              [
                if field.label do
                  # Fixed width for label?
                  Raxol.View.Elements.label(
                    content: field.label,
                    style: %{width: 15}
                  )
                else
                  nil
                end,
                input_element
              ]
              |> Enum.reject(&is_nil(&1))
            end,
            # Render error message if present
            if field.error do
              # Row to allow padding/alignment
              Raxol.View.Elements.row style: %{width: :fill} do
                # Indent error
                Raxol.View.Elements.label(
                  content: field.error,
                  style: %{color: :red, padding_left: 16}
                )
              end
            else
              nil
            end
          ]
          |> Enum.reject(&is_nil(&1))
        end
      end)

    # Return a column containing all field columns (label+input+error)
    Raxol.View.Elements.column style: %{width: :fill, gap: 1} do
      field_elements
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
      Keyword.merge(
        [
          id: id,
          title: title,
          content: content,
          type: :confirm,
          buttons: buttons,
          visible: true
        ],
        opts
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
    buttons = [{"Submit", {:submit, on_submit}}, {"Cancel", on_cancel}]

    props =
      Keyword.merge(
        [
          id: id,
          title: title,
          content: content,
          type: :prompt,
          buttons: buttons,
          input_value: Keyword.get(opts, :default_value, ""),
          validate: Keyword.get(opts, :validate),
          visible: true
        ],
        opts
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
      Keyword.merge(
        [
          id: id,
          title: title,
          fields: fields,
          type: :form,
          buttons: buttons,
          visible: true
        ],
        opts
      )

    props
  end
end
