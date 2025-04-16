defmodule Raxol.Components do
  @moduledoc """
  Components for building rich terminal UI applications.

  This module provides a consistent API for accessing all Raxol components.
  Components are organized into categories:

  - Input: Components for user input (TextInput, Dropdown, etc.)
  - Display: Components for displaying data (Table, Progress, etc.)
  - Navigation: Components for navigation (TabBar, Breadcrumbs, etc.)
  - Feedback: Components for user feedback (Modal, Alert, etc.)
  - Layout: Components for layout (Panel, Splitter, etc.)

  ## Example

  ```elixir
  alias Raxol.Components, as: C

  def view(model) do
    view do
      column do
        C.text_input(value: model.name, on_change: &handle_name_change/1)
        C.button(label: "Submit", on_click: &handle_submit/0)

        if model.loading do
          C.spinner("Loading...")
        end
      end
    end
  end
  ```
  """

  # Delegate to component modules

  # Button
  defdelegate button(opts \\ [], label), to: Raxol.Components.Button, as: :new

  # Text Input
  defdelegate text_input(opts \\ []),
    to: Raxol.Components.TextInput,
    as: :render

  defdelegate multi_line_input(opts \\ []),
    to: Raxol.Components.Input.MultiLineInput,
    as: :render

  defdelegate single_line_input(opts \\ []),
    to: Raxol.Components.Input.SingleLineInput,
    as: :render

  # Modal Components
  defdelegate modal(title, content_fn, actions_fn, opts \\ []),
    to: Raxol.Components.Modal,
    as: :render

  defdelegate alert(title, message, on_ok, opts \\ []),
    to: Raxol.Components.Modal,
    as: :alert

  defdelegate confirmation(title, message, on_confirm, on_cancel, opts \\ []),
    to: Raxol.Components.Modal,
    as: :confirmation

  defdelegate form_modal(title, form_fn, on_submit, on_cancel, opts \\ []),
    to: Raxol.Components.Modal,
    as: :form

  # Tab Bar
  defdelegate tab_bar(tabs, active_tab, on_change, opts \\ []),
    to: Raxol.Components.TabBar,
    as: :render

  defdelegate tabbed_view(tabs, active_tab, on_change, opts \\ []),
    to: Raxol.Components.TabBar,
    as: :tabbed_view

  # Progress Indicators
  defdelegate progress_bar(value, opts \\ []),
    to: Raxol.Components.Progress,
    as: :bar

  defdelegate progress_bar_with_label(value, label, opts \\ []),
    to: Raxol.Components.Progress,
    as: :bar_with_label

  defdelegate spinner(message \\ nil, frame, opts \\ []),
    to: Raxol.Components.Progress,
    as: :spinner

  defdelegate indeterminate_progress(frame, opts \\ []),
    to: Raxol.Components.Progress,
    as: :indeterminate

  defdelegate circular_progress(value, opts \\ []),
    to: Raxol.Components.Progress,
    as: :circular

  # Table
  defdelegate table(data, columns, opts \\ []),
    to: Raxol.Components.Table,
    as: :render

  defdelegate paginated_table(
                data,
                columns,
                page,
                total_pages,
                on_page_change,
                opts \\ []
              ),
              to: Raxol.Components.Table,
              as: :paginated

  # Focus Ring - Delegates to init/1 as render/1 takes only state
  defdelegate focus_ring(opts \\ []),
    to: Raxol.Components.FocusRing,
    as: :init

  # Hint Display - Delegates to init/1 as render/1 takes only state
  defdelegate hint_display(opts \\ []),
    to: Raxol.Components.HintDisplay,
    as: :init

  # Accessibility
  defdelegate accessibility_new(opts \\ []), to: Raxol.Accessibility, as: :new

  defdelegate announce(accessibility, message, priority \\ :normal),
    to: Raxol.Accessibility

  defdelegate set_high_contrast(accessibility, enabled), to: Raxol.Accessibility

  defdelegate set_reduced_motion(accessibility, enabled),
    to: Raxol.Accessibility

  defdelegate set_large_text(accessibility, enabled), to: Raxol.Accessibility
  defdelegate get_color_scheme(accessibility), to: Raxol.Accessibility

  @doc """
  Helper function to create a simple modal that displays a message.

  ## Parameters

  * `message` - The message to display
  * `on_ok` - Function to call when OK is clicked
  * `opts` - Options for customizing the modal

  ## Options

  * `:title` - Modal title (default: "Message")
  * `:ok_text` - Text for the OK button (default: "OK")
  * All other options are passed to `Modal.alert/4`

  ## Returns

  A view element representing the message modal.

  ## Example

  ```elixir
  Components.message(
    "Your changes have been saved successfully.",
    fn -> send(self(), :close_message) end,
    title: "Success"
  )
  ```
  """
  def message(message, on_ok, opts \\ []) do
    title = Keyword.get(opts, :title, "Message")
    ok_text = Keyword.get(opts, :ok_text, "OK")

    alert(title, message, on_ok, Keyword.merge([ok_text: ok_text], opts))
  end

  @doc """
  Helper function to create a simple toast notification.

  This is a non-modal notification that appears briefly and then disappears.

  ## Parameters

  * `message` - The message to display
  * `type` - The type of notification (:info, :success, :warning, :error)
  * `opts` - Options for customizing the toast

  ## Options

  * `:duration` - How long to show the toast in milliseconds (default: 3000)
  * `:position` - Where to display the toast (:top, :bottom, default: :bottom)
  * `:style` - Additional style for the toast

  ## Returns

  A view element representing the toast notification.

  ## Example

  ```elixir
  Components.toast(
    "File saved successfully!",
    :success,
    duration: 5000,
    position: :top
  )
  ```
  """
  def toast(message, type, opts \\ []) do
    alias Raxol.View

    # Extract options with defaults
    duration = Keyword.get(opts, :duration, 3000)
    position = Keyword.get(opts, :position, :bottom)
    style = Keyword.get(opts, :style, %{})

    # Get type-specific style
    type_style =
      case type do
        :success -> %{backgroundColor: "#4caf50", color: "white"}
        :error -> %{backgroundColor: "#f44336", color: "white"}
        :warning -> %{backgroundColor: "#ff9800", color: "white"}
        :info -> %{backgroundColor: "#2196f3", color: "white"}
        _ -> %{backgroundColor: "#757575", color: "white"}
      end

    # Combine styles
    final_style = Map.merge(style, type_style)

    # Create toast component
    View.toast(
      message,
      Map.merge(final_style, %{
        position: position,
        duration: duration
      })
    )
  end
end
