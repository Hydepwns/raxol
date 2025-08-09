defmodule Raxol.UI.Components.Selection.List do
  @moduledoc """
  A component for displaying a selectable list of items.
  """

  @typedoc """
  State for the Selection.List component.

  - :id - unique identifier
  - :items - list of items
  - :selected_index - index of selected item
  - :scroll_offset - scroll offset
  - :width - component width
  - :height - component height
  - :style - style map
  - :focused - whether the list is focused
  - :on_select - callback for selection
  - :item_renderer - function to render items
  """
  @type t :: %__MODULE__{
          id: any(),
          items: list(),
          selected_index: non_neg_integer(),
          scroll_offset: non_neg_integer(),
          width: non_neg_integer(),
          height: non_neg_integer(),
          style: map(),
          focused: boolean(),
          on_select: (any() -> any()) | nil,
          item_renderer: (any() -> any()) | nil
        }

  # Use standard component behaviour
  use Raxol.UI.Components.Base.Component
  require Raxol.Core.Runtime.Log
  # Require view macros
  require Raxol.View.Elements

  @default_height 10

  # Define state struct
  defstruct id: nil,
            items: [],
            selected_index: 0,
            scroll_offset: 0,
            # Example default
            width: 30,
            height: @default_height,
            style: %{},
            focused: false,
            on_select: nil,
            # Remove default function capture
            item_renderer: nil

  # --- Component Behaviour Callbacks ---

  @doc "Initializes the List component state from props."
  @spec init(map()) :: __MODULE__.t()
  @impl Raxol.UI.Components.Base.Component
  def init(props) do
    # Initialize state
    %__MODULE__{
      id: props[:id],
      items: props[:items] || [],
      selected_index: props[:initial_index] || 0,
      width: props[:width] || 30,
      height: props[:height] || @default_height,
      style: props[:style] || %{},
      focused: props[:focused] || false,
      on_select: props[:on_select],
      # Set default renderer here if not provided
      item_renderer: props[:item_renderer] || (&default_item_renderer/1)
    }
  end

  @doc "Updates the List component state in response to messages."
  @spec update(term(), __MODULE__.t()) :: {__MODULE__.t(), list()}
  @impl Raxol.UI.Components.Base.Component
  def update(msg, state) do
    # Handle internal messages (selection, scrolling)
    Raxol.Core.Runtime.Log.debug(
      "List #{state.id} received message: #{inspect(msg)}"
    )

    case msg do
      :select_next -> select_item(state.selected_index + 1, state)
      :select_prev -> select_item(state.selected_index - 1, state)
      :focus -> {%{state | focused: true}, []}
      :blur -> {%{state | focused: false}, []}
      {:select_index, index} -> select_item(index, state)
      _ -> {state, []}
    end
  end

  @doc "Handles events for the List component, such as keyboard and mouse input."
  @spec handle_event(term(), map(), __MODULE__.t()) :: {__MODULE__.t(), list()}
  @impl Raxol.UI.Components.Base.Component
  # Correct arity
  def handle_event(event, %{} = _props, state) do
    # Handle keyboard (up/down/enter), mouse clicks
    Raxol.Core.Runtime.Log.debug(
      "List #{state.id} received event: #{inspect(event)}"
    )

    case event do
      %{type: :key, data: %{key: "Up"}} ->
        update(:select_prev, state)

      %{type: :key, data: %{key: "Down"}} ->
        update(:select_next, state)

      %{type: :key, data: %{key: "Enter"}} ->
        confirm_selection(state)

      %{type: :mouse, data: %{button: :left, action: :press, y: y_pos}} ->
        handle_click(y_pos, state)

      _ ->
        {state, []}
    end
  end

  # --- Render Logic ---

  @doc "Renders the List component, displaying visible items."
  @spec render(__MODULE__.t(), map()) :: any()
  @impl Raxol.UI.Components.Base.Component
  # Correct arity
  def render(state, %{} = _props) do
    # Determine visible items based on scroll offset and height
    visible_items = Enum.slice(state.items, state.scroll_offset, state.height)

    # Render each visible item
    item_elements =
      Enum.with_index(visible_items, state.scroll_offset)
      |> Enum.map(fn {item, index} ->
        selected? = index == state.selected_index
        render_item(item, selected?, state)
      end)

    dsl_result =
      Raxol.View.Elements.box id: state.id,
                              style: %{width: state.width, height: state.height} do
        Raxol.View.Elements.column do
          item_elements
        end
      end

    # Return the element structure directly
    dsl_result
  end

  # --- Internal Render Helpers ---

  defp render_item(item_data, selected?, state) do
    # Ensure item fills width
    base_style = %{width: :fill}
    selected_style = %{bg: :blue, fg: :white}

    style =
      if selected? and state.focused,
        do: Map.merge(base_style, selected_style),
        else: base_style

    # Use the custom renderer or default
    content = state.item_renderer.(item_data)

    # Ensure display_content is always a valid element or list of elements
    display_content =
      cond do
        is_binary(content) -> Raxol.View.Elements.label(content: content)
        is_map(content) and Map.has_key?(content, :type) -> content
        # Default fallback
        true -> Raxol.View.Elements.label(content: to_string(content))
      end

    # Pass as list
    Raxol.View.Elements.box style: style do
      [display_content]
    end
  end

  # --- Internal Logic Helpers ---

  defp select_item(index, state) do
    new_index = clamp(index, 0, length(state.items) - 1)
    new_offset = adjust_scroll(new_index, state.scroll_offset, state.height)
    {%{state | selected_index: new_index, scroll_offset: new_offset}, []}
  end

  defp confirm_selection(state) do
    selected_item = Enum.at(state.items, state.selected_index)

    commands =
      if state.on_select && selected_item,
        do: [{state.on_select, selected_item}],
        else: []

    {state, commands}
  end

  defp handle_click(y_pos, state) do
    # Calculate index based on click position relative to component top
    clicked_index = state.scroll_offset + y_pos
    # Select the clicked item and confirm it
    {new_state, _} = select_item(clicked_index, state)
    confirm_selection(new_state)
  end

  defp clamp(value, min_val, max_val) do
    value |> max(min_val) |> min(max_val)
  end

  defp adjust_scroll(index, offset, height) do
    cond do
      index < offset -> index
      index >= offset + height -> index - height + 1
      true -> offset
    end
  end

  # Default item renderer just converts to string
  defp default_item_renderer(item), do: to_string(item)

  # Access behaviour for struct (for list[:key] and Access.fetch/2)
  def fetch(struct, key) when is_atom(key), do: Map.fetch(struct, key)

  def get_and_update(struct, key, fun) when is_atom(key),
    do: Map.get_and_update(struct, key, fun)

  def pop(struct, key) when is_atom(key), do: Map.pop(struct, key)

  @doc """
  Mount hook - called when component is mounted.
  No special setup needed for List.
  """
  @impl true
  @spec mount(map()) :: {map(), list()}
  def mount(state), do: {state, []}

  @doc """
  Unmount hook - called when component is unmounted.
  No cleanup needed for List.
  """
  @impl true
  @spec unmount(map()) :: map()
  def unmount(state), do: state
end
