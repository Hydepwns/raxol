require Raxol.Core.Renderer.View

defmodule Raxol.Components.Modal do
  @moduledoc """
  A modal component for displaying overlay dialogs like alerts, prompts, confirmations.
  """

  # Use standard component behaviour
  use Raxol.UI.Components.Base.Component
  require Logger

  # Require view macros and components
  require Raxol.View.Elements
  # Remove Button alias, use macro instead
  # alias Raxol.UI.Components.Button

  # Define state struct
  defstruct id: nil,
            visible: false,
            title: "",
            content: nil, # Can be text or other view elements
            buttons: [], # List of {label, message} tuples
            type: :alert, # :alert, :confirm, :prompt, :form
            width: 50, # Example default
            style: %{},
            # State for prompt/form
            input_value: nil,
            form_state: nil

  # --- Component Behaviour Callbacks ---

  @impl Raxol.UI.Components.Base.Component
  def init(props) do
    # Initialize state based on props, likely called by a helper function
    # like alert/4, confirm/5 etc.
    %__MODULE__{
      id: props[:id],
      visible: Map.get(props, :visible, false),
      title: Map.get(props, :title, "Modal"),
      content: Map.get(props, :content),
      buttons: Map.get(props, :buttons, []),
      type: Map.get(props, :type, :alert),
      width: Map.get(props, :width, 50),
      style: Map.get(props, :style, %{})
      # Initialize input_value/form_state if needed
    }
  end

  @impl Raxol.UI.Components.Base.Component
  def update(msg, state) do
    # Handle messages to show/hide, button clicks
    Logger.debug("Modal #{state.id} received message: #{inspect msg}")
    case msg do
      :show -> {%{state | visible: true}, []} # Add command to grab focus?
      :hide -> {%{state | visible: false}, []}
      {:button_click, btn_msg} ->
         # Hide modal and send the button's message
         {%{state | visible: false}, [btn_msg]}
      {:input_changed, value} ->
        {%{state | input_value: value}, []}
      _ -> {state, []}
    end
  end

  @impl Raxol.UI.Components.Base.Component
  def handle_event(event, %{} = _props, state) do
    # Handle Escape key to close, Enter in prompt/form
    Logger.debug("Modal #{state.id} received event: #{inspect event}")
    if state.visible do
      case event do
        %{type: :key, data: %{key: "Escape"}} -> update(:hide, state)
        # TODO: Handle Enter/Tab in prompts/forms
        _ -> {state, []} # Replace `else` with `_` for catch-all
      end
    else
      {state, []} # Ignore events if not visible
    end
  end

  # --- Render Logic ---

  @impl Raxol.UI.Components.Base.Component
  def render(state, %{} = _props) do
    if state.visible do
      # Render modal content (title, body, buttons)
      # Use View Elements macros

      title_element = Raxol.View.Elements.label(content: state.title, style: %{bold: true})

      content_element =
        case state.content do
          # Render based on content type (text, custom elements, form)
          text when is_binary(text) -> Raxol.View.Elements.label(content: text)
          # Handle prompt/form input rendering
          _ when state.type in [:prompt, :form] -> render_form_content(state)
          # Assume it's already a view element/list if not text
          other -> other
        end

      button_elements = Enum.map(state.buttons, fn {label, msg} ->
        # Use button macro instead of calling Button.render
        Raxol.View.Elements.button(label: label, on_click: {:button_click, msg})
      end)

      Raxol.View.Elements.box id: state.id, style: Map.merge(%{border: :double, width: state.width, align: :center}, state.style) do
        Raxol.View.Elements.column style: %{width: :fill, padding: 1} do
          [ title_element,
            Raxol.View.Elements.label(content: ""), # Use empty label for space
            content_element,
            Raxol.View.Elements.label(content: ""), # Use empty label for space
            Raxol.View.Elements.row style: %{justify: :center, width: :fill, gap: 2} do
              button_elements
            end
          ] |> Enum.reject(&is_nil(&1))
        end
      end
      # Modal needs to be wrapped in something that centers it or overlays it.
      # This simple render just returns the box structure.
      # The runtime/layout needs to handle overlay placement.
    else
      nil # Render nothing if not visible
    end
  end

  # --- Internal Render Helpers ---

  defp render_form_content(state) do
    # Render specific inputs for prompt/form types
    case state.type do
      :prompt ->
        # TODO: Revisit architecture. Modal should not call child render directly.
        # Replace with placeholder for now.
        Raxol.View.Elements.label(content: "[Prompt Input Placeholder: #{state.input_value}]")
        # TextInput.render(%{id: "#{state.id}-input", value: state.input_value || "", on_change: {:input_changed}})
      :form ->
        # TODO: Render form elements based on state.form_state
        Raxol.View.Elements.label(content: "Form content placeholder")
      _ -> nil
    end
  end

  # --- Public Helper Functions (Constructors) ---

  @doc "Creates props for an alert modal." # Simplified
  def alert(id, title, content, opts \\ []) do
    props = Keyword.merge(opts, [id: id, title: title, content: content, type: :alert, buttons: [{"OK", :ok}], visible: true])
    # Returns props map, caller uses Component.new(Modal, props)
    props
  end

  @doc "Creates props for a confirmation modal." # Simplified
  def confirm(id, title, content, on_confirm \\ :confirm, on_cancel \\ :cancel, opts \\ []) do
    buttons = [{"Yes", on_confirm}, {"No", on_cancel}]
    props = Keyword.merge(opts, [id: id, title: title, content: content, type: :confirm, buttons: buttons, visible: true])
    props
  end

  @doc "Creates props for a prompt modal." # Simplified
  def prompt(id, title, content, on_submit \\ :submit, on_cancel \\ :cancel, opts \\ []) do
     buttons = [{"Submit", {on_submit, :get_input_value}}, {"Cancel", on_cancel}] # Need way to get input value
     props = Keyword.merge(opts, [id: id, title: title, content: content, type: :prompt, buttons: buttons, visible: true])
     props
  end

  # TODO: Add form/5 constructor

  # Remove old render/4 function

end
