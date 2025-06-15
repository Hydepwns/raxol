defmodule Raxol.UI.Components.Selection.Dropdown do
  @moduledoc """
  A dropdown component that allows selecting one option from a list.
  """

  @typedoc """
  State for the Selection.Dropdown component.

  - :id - unique identifier
  - :options - list of options
  - :selected_option - currently selected option
  - :expanded - whether dropdown is expanded
  - :width - dropdown width
  - :list_height - height of the dropdown list
  - :style - style map
  - :focused - whether the dropdown is focused
  - :on_change - callback for selection change
  - :list_state - state of the nested list
  """
  @type t :: %__MODULE__{
          id: any(),
          options: list(),
          selected_option: any(),
          expanded: boolean(),
          width: non_neg_integer(),
          list_height: non_neg_integer(),
          style: map(),
          focused: boolean(),
          on_change: (any() -> any()) | nil,
          list_state: any()
        }

  # Use standard component behaviour
  use Raxol.UI.Components.Base.Component
  require Raxol.Core.Runtime.Log

  # Require List component and View macros/helpers
  alias Raxol.UI.Components.Selection.List
  require Raxol.View.Elements

  # Define state struct
  defstruct id: nil,
            options: [],
            selected_option: nil,
            expanded: false,
            # Example default
            width: 20,
            # Example default
            list_height: 5,
            style: %{},
            focused: false,
            on_change: nil,
            # Nested list state
            list_state: nil

  # --- Component Behaviour Callbacks ---

  @doc "Initializes the Dropdown component state from props."
  @spec init(map()) :: __MODULE__.t()
  @impl Raxol.UI.Components.Base.Component
  def init(props) do
    # Initialize state, including nested List state
    # Ensure options is a list
    options = props[:options] || []
    # Use Enum.at for safety
    initial_option = props[:initial_value] || Enum.at(options, 0)
    width = props[:width] || 20

    list_props = %{
      id: "#{props[:id]}-list",
      items: props[:options] || [],
      # Match dropdown width
      width: width,
      height: props[:list_height] || 5,
      # Internal message
      on_select: {:list_item_selected}
      # Pass item_renderer if needed
    }

    %__MODULE__{
      id: props[:id],
      options: props[:options] || [],
      selected_option: initial_option,
      width: width,
      list_height: props[:list_height] || 5,
      style: props[:style] || %{},
      on_change: props[:on_change],
      # Initialize nested list component
      list_state: List.init(list_props)
    }
  end

  @doc "Updates the Dropdown component state in response to messages."
  @spec update(term(), __MODULE__.t()) :: {__MODULE__.t(), list()}
  @impl Raxol.UI.Components.Base.Component
  def update(msg, state) do
    # Handle internal messages and messages from nested list
    Raxol.Core.Runtime.Log.debug(
      "Dropdown #{state.id} received message: #{inspect(msg)}"
    )

    case msg do
      :toggle_expand ->
        new_state = %{state | expanded: !state.expanded}
        # Update focus on nested list when expanding/collapsing
        list_focus_msg = if new_state.expanded, do: :focus, else: :blur

        {list_state, list_cmds} =
          List.update(list_focus_msg, new_state.list_state)

        {%{new_state | list_state: list_state}, list_cmds}

      {:list_item_selected, selected_item} ->
        # Item selected in the list, update dropdown state and collapse
        new_state = %{state | selected_option: selected_item, expanded: false}

        commands =
          if state.on_change, do: [{state.on_change, selected_item}], else: []

        {new_state, commands}

      :focus ->
        {%{state | focused: true}, []}

      # Collapse on blur
      :blur ->
        {%{state | expanded: false, focused: false}, []}

      # Forward other relevant messages to the list component
      {:list_msg, list_message} when state.expanded ->
        {new_list_state, list_cmds} =
          List.update(list_message, state.list_state)

        {%{state | list_state: new_list_state}, list_cmds}

      _ ->
        {state, []}
    end
  end

  @doc "Handles key events for the Dropdown component, including toggling expansion and forwarding to the list."
  @impl Raxol.UI.Components.Base.Component
  def handle_event(%{type: :key, data: key_data} = event, %{} = _props, state) do
    Raxol.Core.Runtime.Log.debug(
      "Dropdown #{state.id} received event: #{inspect(event)}"
    )

    # Handle keys to toggle expansion, or forward to list if expanded
    case key_data.key do
      "Enter" when not state.expanded ->
        update(:toggle_expand, state)

      "Escape" when state.expanded ->
        update(:toggle_expand, state)

      _ ->
        if state.expanded do
          # Forward event to the list component using handle_event/3
          {new_list_state, list_cmds} =
            List.handle_event(event, %{}, state.list_state)

          {%{state | list_state: new_list_state}, list_cmds}
        else
          # Handle other keys for collapsed dropdown if needed
          {state, []}
        end
    end
  end

  @spec handle_event(map(), map(), __MODULE__.t()) :: {__MODULE__.t(), list()}
  @impl Raxol.UI.Components.Base.Component
  def handle_event(event, %{} = _props, state) do
    Raxol.Core.Runtime.Log.debug(
      "Dropdown #{state.id} received event: #{inspect(event.type)}"
    )

    case event do
      %{type: :mouse, data: %{button: :left, action: :press}} ->
        # Toggle expansion on click
        update(:toggle_expand, state)

      _ ->
        {state, []}
    end
  end

  # --- Render Logic ---

  @doc "Renders the Dropdown component, showing either the expanded or collapsed state."
  @spec render(__MODULE__.t(), map()) :: any()
  @impl Raxol.UI.Components.Base.Component
  def render(state, %{} = _props) do
    dsl_result =
      if state.expanded do
        render_expanded(state)
      else
        render_collapsed(state)
      end

    # Return the element structure directly
    dsl_result
  end

  # --- Internal Render Helpers ---

  defp render_collapsed(state) do
    # Display selected option and indicator
    display_text = to_string(state.selected_option || "Select...") <> " ▼"
    # Use View Elements macros
    Raxol.View.Elements.box id: state.id,
                            style: %{border: :single, width: state.width} do
      Raxol.View.Elements.row style: %{width: :fill} do
        Raxol.View.Elements.label(content: display_text)
      end
    end
  end

  defp render_expanded(state) do
    # Display selected option box and the list component below
    display_text = to_string(state.selected_option || "Select...") <> " ▲"
    # Use View Elements macros
    Raxol.View.Elements.column id: state.id do
      # Box for the selected item display
      Raxol.View.Elements.box style: %{border: :single, width: state.width} do
        Raxol.View.Elements.row style: %{width: :fill} do
          Raxol.View.Elements.label(content: display_text)
        end
      end

      # Render the list component (render/2 returns an Element)
      List.render(state.list_state, %{})
    end
  end

  # Remove old handle_dropdown_keys (logic moved to handle_event)
  # Remove old @impl Component annotation
end
