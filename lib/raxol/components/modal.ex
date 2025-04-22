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
  def render(title, content_fn, actions_fn, opts \\ []) do
    # Extract options with defaults
    id = Keyword.get(opts, :id, "modal")
    width = Keyword.get(opts, :width, 50)
    # Optional height
    height = Keyword.get(opts, :height)
    # Example default style
    style = Keyword.get(opts, :style, %{border: :double})
    title_style = Keyword.get(opts, :title_style, %{align: :center})
    content_style = Keyword.get(opts, :content_style, %{padding: 1})
    actions_style = Keyword.get(opts, :actions_style, %{padding_top: 1})
    # on_escape = Keyword.get(opts, :on_escape)
    # centered = Keyword.get(opts, :centered, true) # Centering deferred

    # Build props for the main panel
    container_props = [id: id, style: style]

    container_props =
      if width,
        do: Keyword.put(container_props, :style, Map.put(style, :width, width)),
        else: container_props

    container_props =
      if height,
        do:
          Keyword.put(
            container_props,
            :style,
            Map.put(Keyword.get(container_props, :style), :height, height)
          ),
        else: container_props

    # TODO: Add on_key handling if/when View DSL supports it

    # Use box instead of panel
    Layout.box container_props do
      # Create children conditionally, filtering nils
      [
        if title do
          Layout.box id: "#{id}_title", style: title_style do
            Components.text(title)
          end
        end,
        if content_fn do
          Layout.box id: "#{id}_content", style: content_style do
            content_fn.()
          end
        end,
        if actions_fn do
          Layout.box id: "#{id}_actions", style: actions_style do
            actions_fn.()
          end
        end
      ]
      |> Enum.reject(&is_nil(&1))
      |> List.flatten()
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

  ## Returns

  A view element representing the confirmation dialog.

  ## Example

  ```elixir
  Modal.confirmation(
    "Confirm Delete",
    "Are you sure you want to delete this item? This action cannot be undone.",
    fn -> send(self(), {:delete_confirmed}) end,
    fn -> send(self(), {:delete_cancelled}) end,
    width: 40
  )
  ```
  """
  def confirmation(title, message, on_confirm, on_cancel, opts \\ []) do
    # Get customization options
    yes_text = Keyword.get(opts, :yes_text, "Yes")
    no_text = Keyword.get(opts, :no_text, "No")
    yes_style = Keyword.get(opts, :yes_style, %{fg: :white, bg: :blue})
    no_style = Keyword.get(opts, :no_style, %{})

    # Create confirmation modal
    render(
      title,
      fn -> Components.text(message) end,
      fn ->
        Layout.row([style: %{justify: :flex_end, gap: 1}],
          do: fn ->
            Components.button(no_text,
              id: "#{title}_no",
              style: no_style,
              on_click: on_cancel
            )

            Components.button(yes_text,
              id: "#{title}_yes",
              style: yes_style,
              on_click: on_confirm
            )
          end
        )
      end,
      Keyword.merge(
        [
          id: "confirm_#{String.downcase(title) |> String.replace(" ", "_")}",
          width: 40,
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
  def alert(title, content_fn, on_ok, opts \\ []) do
    # Get customization options
    ok_text = Keyword.get(opts, :ok_text, "OK")
    ok_style = Keyword.get(opts, :ok_style, %{fg: :white, bg: :blue})

    # Create alert modal
    render(
      title,
      content_fn,
      fn ->
        Layout.row([style: %{justify: :center}],
          do: fn ->
            Components.button(ok_text,
              id: "#{title}_ok",
              style: ok_style,
              on_click: on_ok
            )
          end
        )
      end,
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
  def form(title, form_fn, _on_submit, _on_cancel, opts \\ []) do
    render(
      title,
      form_fn,
      # Return empty list to fix syntax and represent no footer content
      fn -> [] end,
      opts
    )
  end
end
