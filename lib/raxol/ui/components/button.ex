defmodule Raxol.UI.Components.Button do
  @moduledoc """
  A customizable button component.

  This module provides a more sophisticated button component than the basic
  button element, with support for various styles and behaviors.

  ## Example

  ```elixir
  alias Raxol.UI.Components.Button

  Button.new("Save Changes", on_click: :save_clicked, style: :primary)
  ```
  """

  alias Raxol.Style
  alias Raxol.Style.Borders

  @type t :: map()

  @doc """
  Creates a new button with the given label and options.

  ## Options

  * `:on_click` - Message to send when the button is clicked
  * `:style` - Button style (:primary, :secondary, :danger, :success, or a custom style map)
  * `:disabled` - Whether the button is disabled
  * `:icon` - Icon to display before the label
  * `:full_width` - Whether the button should take full width
  * `:size` - Button size (:small, :medium, :large)
  * `:tooltip` - Tooltip text to show on hover

  ## Returns

  A button component that can be used in a Raxol view.

  ## Example

  ```elixir
  Button.new("Delete",
    on_click: {:delete, item_id},
    style: :danger,
    icon: :trash
  )
  ```
  """
  @spec new(String.t(), Keyword.t()) :: map()
  def new(label, opts \\ []) do
    # Extract options with defaults
    on_click = Keyword.get(opts, :on_click)
    button_style = Keyword.get(opts, :style, :primary)
    disabled = Keyword.get(opts, :disabled, false)
    icon = Keyword.get(opts, :icon)
    full_width = Keyword.get(opts, :full_width, false)
    size = Keyword.get(opts, :size, :medium)
    tooltip = Keyword.get(opts, :tooltip)

    # Create the button with merged styles
    %{
      type: :component,
      component_type: :button,
      label: label,
      on_click: on_click,
      disabled: disabled,
      icon: icon,
      full_width: full_width,
      size: size,
      tooltip: tooltip,
      style: get_button_style(button_style, size, full_width, disabled),
      focus_key: Keyword.get(opts, :focus_key, generate_focus_key())
    }
  end

  @doc """
  Renders the button as a basic element.

  This is typically called by the renderer, not directly by users.
  """
  @spec render(map()) :: any()
  def render(button) do
    %Raxol.Core.Renderer.Element{
      tag: :button,
      attributes: %{
        disabled: button.disabled,
        # Assuming not pressed by default in render
        pressed: false
      },
      children: [],
      content: get_button_content(button),
      # Add ref if needed
      ref: nil,
      # Use the pre-calculated style
      style: button.style
    }
  end

  # Private functions

  defp get_button_style(style_type, size, full_width, disabled)
       when is_atom(style_type) do
    base_style =
      Style.new(
        padding: get_padding_for_size(size),
        align: :center,
        width: get_width_for_full_width(full_width),
        border: Borders.new(%{style: :rounded})
      )

    color_style = get_color_style(style_type)
    size_style = get_size_style(size)

    combined_style =
      Style.merge(base_style, Style.merge(color_style, size_style))

    apply_disabled_style(combined_style, disabled)
  end

  defp get_button_style(custom_style, size, full_width, disabled)
       when is_map(custom_style) do
    base_style =
      Style.new(
        padding: get_padding_for_size(size),
        align: :center,
        width: get_width_for_full_width(full_width),
        border: Borders.new(%{style: :rounded})
      )

    custom_style_struct = Style.new(custom_style)
    combined_style = Style.merge(base_style, custom_style_struct)

    apply_disabled_style(combined_style, disabled)
  end

  defp get_color_style(:primary) do
    Style.new(%{color: :white, background: :blue})
  end

  defp get_color_style(:secondary) do
    Style.new(%{color: :black, background: :light_gray})
  end

  defp get_color_style(:danger) do
    Style.new(%{color: :white, background: :red})
  end

  defp get_color_style(:success) do
    Style.new(%{color: :white, background: :green})
  end

  defp get_color_style(_) do
    Style.new(%{color: :white, background: :blue})
  end

  defp get_size_style(:small) do
    Style.new(%{padding: [0, 1]})
  end

  defp get_size_style(:medium) do
    Style.new(%{padding: [1, 2]})
  end

  defp get_size_style(:large) do
    Style.new(%{padding: [1, 3]})
  end

  defp get_padding_for_size(:small), do: [0, 1]
  defp get_padding_for_size(:medium), do: [1, 2]
  defp get_padding_for_size(:large), do: [1, 3]

  defp generate_focus_key do
    :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)
  end

  defp get_width_for_full_width(true), do: :fill
  defp get_width_for_full_width(false), do: :auto

  defp apply_disabled_style(style, true) do
    Style.merge(
      style,
      Style.new(%{color: :gray, background: :dark_gray})
    )
  end

  defp apply_disabled_style(style, false), do: style

  defp get_button_content(%{icon: nil, label: label}), do: label

  defp get_button_content(%{icon: icon, label: label}) do
    # Assuming icon is an atom representing the icon character/name
    # You might need a helper to convert icon atom to string/char
    "#{Atom.to_string(icon)} #{label}"
  end

  @doc """
  Handles a click event on the button.

  Executes the on_click callback if the button is not disabled.
  """
  @spec handle_click(map()) :: :ok | {:error, :disabled}
  def handle_click(%{disabled: true}), do: {:error, :disabled}

  def handle_click(%{on_click: nil}), do: :ok

  def handle_click(%{on_click: on_click}) when is_function(on_click, 0) do
    on_click.()
    :ok
  end

  def handle_click(%{on_click: on_click}) when is_function(on_click, 1) do
    on_click.(:clicked)
    :ok
  end

  def handle_click(%{on_click: {module, function, args}}) do
    apply(module, function, args)
    :ok
  end

  def handle_click(%{on_click: _}), do: :ok
end
