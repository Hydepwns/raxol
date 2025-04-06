defmodule Raxol.Components.Modal do
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

  alias Raxol.View

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
  * `:height` - Modal height in characters or :auto (default: :auto)
  * `:style` - Style for the modal container
  * `:title_style` - Style for the modal title
  * `:content_style` - Style for the modal content area
  * `:actions_style` - Style for the modal action buttons area
  * `:backdrop` - Boolean to show a backdrop behind the modal (default: true)
  * `:backdrop_style` - Style for the backdrop
  * `:centered` - Boolean to center the modal (default: true)
  * `:on_escape` - Function to call when Escape key is pressed (default: nil)

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
  )
  ```
  """
  def render(_title, _content_fn, _actions_fn, _opts \\ []) do
    # Create a combined component with backdrop and modal
    # TODO: Raxol.View.overlay is undefined. Modal needs refactoring to use
    # Raxol.Core.Renderer.View with appropriate z-index and positioning for overlay effect.
    # Commenting out for now to allow compilation.
    # View.overlay([id: "#{id}_overlay"], fn ->
    #   # Optional backdrop
    #   if show_backdrop do
    #     View.panel([id: "#{id}_backdrop", style: backdrop_style], fn ->
    #       View.text("")  # Empty text to satisfy the function body requirement
    #     end)
    #   end
    #
    #   # Modal container with optional centering
    #   container_props = [id: id, style: style]
    #
    #   # Add size constraints
    #   container_props =
    #     if width do
    #       Keyword.put(container_props, :style, Map.put(style, :width, width))
    #     else
    #       container_props
    #     end
    #
    #   container_props =
    #     if height != :auto do
    #       Keyword.put(container_props, :style, Map.put(Keyword.get(container_props, :style), :height, height))
    #     else
    #       container_props
    #     end
    #
    #   # Add centering if requested
    #   container_props =
    #     if centered do
    #       Keyword.put(container_props, :style, Map.put(Keyword.get(container_props, :style), :align, :center))
    #     else
    #       container_props
    #     end
    #
    #   # Add escape handler if provided
    #   container_props =
    #     if on_escape do
    #       Keyword.put(container_props, :on_key, fn key ->
    #         case key do
    #           {:escape, _} ->
    #             on_escape.()
    #             true
    #           _ -> false
    #         end
    #       end)
    #     else
    #       container_props
    #     end
    #
    #   # Render the modal
    #   View.panel(container_props, fn ->
    #     View.column([], fn ->
    #       # Title area
    #       View.panel([id: "#{id}_title", style: title_style], fn ->
    #         View.text(title)
    #       end)
    #
    #       # Content area
    #       View.panel(
    #         [
    #           id: "#{id}_content",
    #           style: Map.merge(content_style, if(content_height, do: %{height: content_height}, else: %{}))
    #         ],
    #         content_fn
    #       )
    #
    #       # Actions area
    #       View.panel([id: "#{id}_actions", style: actions_style], actions_fn)
    #     end)
    #   end)
    # end)

    # Placeholder return until refactoring
    View.text("Modal placeholder (overlay broken)")

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
      fn -> View.text(message) end,
      fn ->
        View.row([style: %{justify: :flex_end, gap: 1}], fn ->
          View.button([id: "#{title}_no", style: no_style, on_click: on_cancel], no_text)
          View.button([id: "#{title}_yes", style: yes_style, on_click: on_confirm], yes_text)
        end)
      end,
      Keyword.merge(
        [id: "confirm_#{String.downcase(title) |> String.replace(" ", "_")}", width: 40, on_escape: on_cancel],
        opts
      )
    )
  end

  @doc """
  Renders an alert dialog with a message and an OK button.

  ## Parameters

  * `title` - The modal title
  * `message` - The alert message text
  * `on_ok` - Function to call when user clicks OK
  * `opts` - Options for customizing the modal (same as `render/4`)

  ## Returns

  A view element representing the alert dialog.

  ## Example

  ```elixir
  Modal.alert(
    "Information",
    "Your changes have been saved successfully.",
    fn -> send(self(), :close_alert) end
  )
  ```
  """
  def alert(title, message, on_ok, opts \\ []) do
    # Get customization options
    ok_text = Keyword.get(opts, :ok_text, "OK")
    ok_style = Keyword.get(opts, :ok_style, %{fg: :white, bg: :blue})

    # Create alert modal
    render(
      title,
      fn -> View.text(message) end,
      fn ->
        View.row([style: %{justify: :center}], fn ->
          View.button([id: "#{title}_ok", style: ok_style, on_click: on_ok], ok_text)
        end)
      end,
      Keyword.merge(
        [id: "alert_#{String.downcase(title) |> String.replace(" ", "_")}", width: 40, on_escape: on_ok],
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
  * `on_cancel` - Function to call when user cancels
  * `opts` - Options for customizing the modal (same as `render/4`)

  ## Returns

  A view element representing the form dialog.

  ## Example

  ```elixir
  Modal.form(
    "Add User",
    fn ->
      column do
        text_input(placeholder: "Name", value: model.user_name, on_change: &handle_name_change/1)
        text_input(placeholder: "Email", value: model.user_email, on_change: &handle_email_change/1)
      end
    end,
    fn -> send(self(), {:submit_user_form}) end,
    fn -> send(self(), {:cancel_user_form}) end,
    width: 50
  )
  ```
  """
  def form(title, form_fn, on_submit, on_cancel, opts \\ []) do
    # Get customization options
    submit_text = Keyword.get(opts, :submit_text, "Submit")
    cancel_text = Keyword.get(opts, :cancel_text, "Cancel")
    submit_style = Keyword.get(opts, :submit_style, %{fg: :white, bg: :blue})
    cancel_style = Keyword.get(opts, :cancel_style, %{})

    # Create form modal
    render(
      title,
      form_fn,
      fn ->
        View.row([style: %{justify: :flex_end, gap: 1}], fn ->
          View.button([id: "#{title}_cancel", style: cancel_style, on_click: on_cancel], cancel_text)
          View.button([id: "#{title}_submit", style: submit_style, on_click: on_submit], submit_text)
        end)
      end,
      Keyword.merge(
        [id: "form_#{String.downcase(title) |> String.replace(" ", "_")}", width: 50, on_escape: on_cancel],
        opts
      )
    )
  end
end
