defmodule Raxol.Components.Modal do
  use Raxol.Component

  require Raxol.View
  alias Raxol.View.Layout
  alias Raxol.View.Components

  @moduledoc """
  Modal dialog component for Raxol applications.

  This module provides components for displaying modal dialogs that overlay
  the main application content. Modals can be used for confirmations, data entry,
  alerts, or any scenario where user attention needs to be focused on a specific task.

  ## Examples

  ```elixir
  alias Raxol.Components.Modal

  # In your view function
  def view(model) do
    view do
      # Main application content
      text("Main application content")

      # Conditionally render modal if it's active
      if model.show_confirmation_modal do
        Modal.confirmation(
          "Delete Item",
          "Are you sure you want to delete this item?",
          fn -> {:confirm_delete} end,
          fn -> {:cancel_delete} end
        )
      end
    end
  end
  """

  @doc """
  Initializes the component state.

  This is a default implementation that can be overridden by components.
  """
  @impl true
  def init(props) when is_map(props), do: props
  def init(_props), do: %{}

  @doc """
  Updates the component state in response to a message.

  This is a default implementation that can be overridden by components.
  """
  @impl true
  def update(_msg, state), do: state

  @doc """
  Renders the component based on its current state.

  This function should be overridden by actual component implementations.
  """
  @impl true
  def render(state) do
    if state[:component], do: state.component, else: nil
  end

  @doc """
  Handles external events sent to this component.

  This is a default implementation that can be overridden by components.
  """
  @impl true
  def handle_event(_event, state), do: {state, []}

  @doc """
  Called when the component is mounted to the view tree.

  This is a default implementation that can be overridden by components.
  """
  @impl true
  def mount(state), do: {state, []}

  @doc """
  Called when the component is removed from the view tree.

  This is a default implementation that can be overridden by components.
  """
  @impl true
  def unmount(state), do: state

  @doc """
  Renders a modal dialog.

  This is the base function for creating modals. It renders a modal with
  a title, content, and optional buttons/actions.

  ## Parameters

  * `title` - The modal title
  * `content_fn` - Function that returns the modal content
  * `actions_fn` - Function that returns the modal actions/buttons
  * `opts` - Options for customizing the modal appearance

  ## Options

  * `:id` - Modal identifier (default: "modal")
  * `:width` - Modal width in characters (default: 50)
  * `:height` - Modal height in characters (integer). :auto not yet supported reliably.
  * `:style` - Style for the modal container
  * `:title_style` - Style for the modal title
  * `:content_style` - Style for the modal content area
  * `:actions_style` - Style for the modal action buttons area
  * `:on_escape` - Optional callback function to execute when Escape key is pressed

  ## Returns

  A view element representing the modal dialog.

  ## Example

  ```elixir
  Modal.render(
    "User Settings",
    fn -> text("Settings form content") end,
    fn ->
      row do
        button("Save", on_click: &save_settings/0)
        button("Cancel", on_click: &cancel_settings/0)
      end
    end,
    width: 60,
    centered: true
  )```
  """
  @dialyzer {:nowarn_function, [render: 3, render: 4]}
  def render(title, content_fn, actions_fn, opts \\ []) do
    # Extract options with defaults
    id = Keyword.get(opts, :id, "modal")
    width = Keyword.get(opts, :width, 50)
    height = Keyword.get(opts, :height)
    style = Keyword.get(opts, :style, %{border: :double})
    title_style = Keyword.get(opts, :title_style, %{align: :center})
    content_style = Keyword.get(opts, :content_style, %{padding: 1})
    actions_style = Keyword.get(opts, :actions_style, %{padding_top: 1})
    # Extract the callback
    on_escape_callback = Keyword.get(opts, :on_escape)
    # centered = Keyword.get(opts, :centered, true) # Centering deferred

    # --- Define Key Handler ---
    # NOTE: This assumes Layout.box supports :on_key and the event format.
    # The return value (:handled/:passthrough) might need adjustment based on the event system.
    key_handler =
      if on_escape_callback do
        fn key_event ->
          case key_event do
            # Match common key event structures for Escape
            {:key_press, :escape, _modifiers} ->
              on_escape_callback.()
              # Indicate event was handled
              :handled

            %{type: :keypress, key: :escape} ->
              on_escape_callback.()
              # Indicate event was handled
              :handled

            _ ->
              # Ignore other keys
              :passthrough
          end
        end
      else
        nil
      end

    # Build props for the main panel
    container_props = [id: id, style: style]

    container_props =
      if key_handler,
        do: Keyword.put(container_props, :on_key, key_handler),
        else: container_props

    container_props =
      if not is_nil(width),
        do: Keyword.put(container_props, :style, Map.put(style, :width, width)),
        else: container_props

    container_props =
      if not is_nil(height),
        do:
          Keyword.put(
            container_props,
            :style,
            Map.put(Keyword.get(container_props, :style), :height, height)
          ),
        else: container_props

    # TODO: Verify Layout.box supports :on_key and handles focus correctly for this.

    # Build children content first, capturing results
    title_content =
      if title do
        Layout.box id: "#{id}_title", style: title_style do
          Components.text(title)
        end
      else
        nil
      end

    content_result =
      if content_fn do
        content_value = content_fn.()

        Layout.box id: "#{id}_content", style: content_style do
          content_value
        end
      else
        nil
      end

    actions_result =
      if actions_fn do
        actions_value = actions_fn.()

        Layout.box id: "#{id}_actions", style: actions_style do
          actions_value
        end
      else
        nil
      end

    children_result =
      [title_content, content_result, actions_result]
      |> Enum.reject(&is_nil(&1))
      |> List.flatten()

    # Use box with prepared children, passing container_props which now includes :on_key
    Layout.box container_props do
      children_result
    end
  end

  @doc """
  Renders a confirmation dialog with Yes and No buttons.

  ## Parameters

  * `title` - The modal title
  * `message` - The confirmation message text
  * `on_confirm` - Function to call when user confirms
  * `on_cancel` - Function to call when user cancels
  * `opts` - Options for customizing the modal (same as `render/4`)

  ## Options (in addition to `render/4` options)

  * `:yes_text` - Text for the confirmation button (default: "Yes")
  * `:no_text` - Text for the cancellation button (default: "No")
  * `:yes_style` - Style for the confirmation button (default: `{fg: :white, bg: :blue}`)
  * `:no_style` - Style for the cancellation button (default: `{}`)
  * `:default` - Which button is activated by default on Enter (`:confirm` or `:cancel`, default: `:confirm`)

  ## Returns

  A view element representing the confirmation dialog.

  ## Example

  ```elixir
  Modal.confirmation(
    "Confirm Delete",
    "Are you sure you want to delete this item? This action cannot be undone.",
    fn -> send(self(), {:delete_confirmed}) end,
    fn -> send(self(), {:delete_cancelled}) end,
    width: 40,
    default: :cancel
  )
  ```
  """
  @dialyzer {:nowarn_function, [confirmation: 4, confirmation: 5]}
  def confirmation(title, message, on_confirm, on_cancel, opts \\ []) do
    # Get customization options
    yes_text = Keyword.get(opts, :yes_text, "Yes")
    no_text = Keyword.get(opts, :no_text, "No")
    yes_style = Keyword.get(opts, :yes_style, %{fg: :white, bg: :blue})
    no_style = Keyword.get(opts, :no_style, %{})
    # Default to confirm
    default_action = Keyword.get(opts, :default, :confirm)

    # Create content function that returns the message text
    message_fn = fn -> Components.text(message) end

    # Determine focus based on default
    # NOTE: This assumes focus can be set via props, which might need adjustment
    # in the Button component or Layout system.
    yes_focused = default_action == :confirm
    no_focused = default_action == :cancel

    # Create confirmation modal
    render(
      title,
      message_fn,
      fn ->
        row_result =
          Layout.row([style: %{justify: :flex_end, gap: 1}],
            do: fn ->
              no_button =
                Components.button(no_text,
                  id: "#{title}_no",
                  style: no_style,
                  # Pass focus state
                  focused: no_focused,
                  on_click: on_cancel
                )

              yes_button =
                Components.button(yes_text,
                  id: "#{title}_yes",
                  style: yes_style,
                  # Pass focus state
                  focused: yes_focused,
                  on_click: on_confirm
                )

              # Return the buttons rather than just assigning them
              # Order might matter for tab navigation if implemented
              if default_action == :confirm do
                [no_button, yes_button]
              else
                [yes_button, no_button]
              end
            end
          )

        # Return the row component
        row_result
      end,
      Keyword.merge(
        [
          id: "confirm_#{String.downcase(title) |> String.replace(" ", "_")}",
          width: 40,
          # Attempt to handle escape key via on_escape, assuming render/4 supports it
          on_escape: on_cancel
        ],
        opts
      )
    )
  end

  @doc """
  Renders an alert dialog with a title, content, and an OK button.

  ## Parameters

  * `title` - The modal title
  * `content_fn` - Function that returns the content of the modal
  * `on_ok` - Function to call when user clicks the OK button
  * `opts` - Options for customizing the modal (same as `render/4`)

  ## Returns

  A view element representing the alert dialog.

  ## Example

  ```elixir
  Modal.alert("Success", fn -> "Item saved successfully." end, fn -> send(self(), {:alert_ok}) end)
  ```
  """
  @dialyzer {:nowarn_function, [alert: 3, alert: 4]}
  def alert(title, content_fn, on_ok, opts \\ []) do
    # Get customization options
    ok_text = Keyword.get(opts, :ok_text, "OK")
    ok_style = Keyword.get(opts, :ok_style, %{fg: :white, bg: :blue})

    # Create actions function
    actions_fn = fn ->
      row_result =
        Layout.row([style: %{justify: :center}],
          do: fn ->
            ok_button =
              Components.button(ok_text,
                id: "#{title}_ok",
                style: ok_style,
                on_click: on_ok
              )

            # Return the button rather than just assigning it
            [ok_button]
          end
        )

      # Return the row component
      row_result
    end

    # Create alert modal
    render(
      title,
      content_fn,
      actions_fn,
      Keyword.merge(
        [
          id: "alert_#{String.downcase(title) |> String.replace(" ", "_")}",
          width: 40,
          on_escape: on_ok
        ],
        opts
      )
    )
  end

  @doc """
  Renders a form dialog with input fields and Submit/Cancel buttons.

  ## Parameters

  * `title` - The modal title
  * `form_fn` - Function that returns the form fields
  * `on_submit` - Function to call when user submits the form
  * `on_cancel` - Function to call when user cancels the form
  * `opts` - Options for customizing the modal (same as `render/4`)

  ## Returns

  A view element representing the form dialog.

  ## Example

  ```elixir
  Modal.form(
    "Edit User",
    fn ->
      # Render form fields
    end,
    fn -> send(self(), {:submit_form}) end,
    fn -> send(self(), {:cancel_form}) end
  )
  ```
  """
  @dialyzer {:nowarn_function, [form: 4, form: 5]}
  def form(title, form_fn, on_submit, on_cancel, opts \\ []) do
    # Get customization options
    submit_text = Keyword.get(opts, :submit_text, "Submit")
    cancel_text = Keyword.get(opts, :cancel_text, "Cancel")
    submit_style = Keyword.get(opts, :submit_style, %{fg: :white, bg: :blue})
    cancel_style = Keyword.get(opts, :cancel_style, %{})

    # Create actions function with explicit return value handling
    actions_fn = fn ->
      row_result =
        Layout.row([style: %{justify: :flex_end, gap: 1}],
          do: fn ->
            cancel_button =
              Components.button(cancel_text,
                id: "#{title}_cancel",
                style: cancel_style,
                on_click: on_cancel
              )

            submit_button =
              Components.button(submit_text,
                id: "#{title}_submit",
                style: submit_style,
                on_click: on_submit
              )

            # Return the buttons rather than just assigning them
            [cancel_button, submit_button]
          end
        )

      # Return the row component
      row_result
    end

    # Create form modal with submit/cancel buttons
    render(
      title,
      form_fn,
      actions_fn,
      Keyword.merge(
        [
          id: "form_#{String.downcase(title) |> String.replace(" ", "_")}",
          width: 50,
          on_escape: on_cancel
        ],
        opts
      )
    )
  end
end
