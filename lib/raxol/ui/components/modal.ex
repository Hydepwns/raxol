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

  # Alias the new modules
  alias Raxol.UI.Components.Modal.{Core, Events, Rendering, State}

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
    Core.init(props)
  end

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
        Core.handle_show(state)

      :hide ->
        Core.handle_hide(state)

      {:button_click, button_msg} ->
        handle_button_click_msg(button_msg, state)

      {:field_update, field_id, new_value} ->
        State.update_field_value(state, field_id, new_value)

      :focus_next_field ->
        State.change_focus(state, 1)

      :focus_prev_field ->
        State.change_focus(state, -1)

      {:input_changed, value} when state.type == :prompt ->
        State.handle_prompt_input(state, value)

      _ ->
        Core.handle_unknown_message(state, msg)
    end
  end

  defp handle_button_click_msg({:submit, original_msg}, state) do
    Raxol.Core.Runtime.Log.debug(
      "[DEBUG] handle_button_click_msg called with submit message: #{inspect(original_msg)} and state.visible=#{inspect(state.visible)}"
    )

    if state.type == :prompt do
      State.handle_prompt_submission(state, original_msg)
    else
      State.handle_form_submission(state, original_msg)
    end
  end

  defp handle_button_click_msg({:cancel, original_msg}, state),
    do: Core.handle_cancel(state, original_msg)

  defp handle_button_click_msg(btn_msg, state),
    do: Core.handle_button_click(state, btn_msg)

  defp handle_hidden_update(msg, state) do
    case msg do
      :show ->
        Core.handle_show(state)

      _ ->
        {state, []}
    end
  end

  @impl Raxol.UI.Components.Base.Component
  @spec handle_event(term(), map(), map()) :: {map(), list()}
  def handle_event(event, %{} = _props, state) do
    Raxol.Core.Runtime.Log.debug(
      "Modal #{Map.get(state, :id, nil)} received event: #{inspect(event)} with state.type: #{inspect(state.type)}"
    )

    if state.visible do
      case Events.handle_visible_event(event, state) do
        {:button_click, msg} ->
          update({:button_click, msg}, state)

        :focus_next_field ->
          update(:focus_next_field, state)

        :focus_prev_field ->
          update(:focus_prev_field, state)

        {:input_changed, value} ->
          update({:input_changed, value}, state)

        nil ->
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
      Rendering.render_modal_content(state)
    else
      nil
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
