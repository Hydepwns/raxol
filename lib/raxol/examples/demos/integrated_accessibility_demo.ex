defmodule Raxol.Examples.Demos.IntegratedAccessibilityDemo do
  @moduledoc """
  A demo showcasing integrated accessibility features.
  """
  
  @behaviour Raxol.Core.Runtime.Application

  alias Raxol.Core.Renderer.View
  require Raxol.Core.Renderer.View
  # If this demo uses Accessibility features directly:
  # alias Raxol.Core.Accessibility

  @impl true
  def init(_opts) do
    model = %{
      message: "Welcome to the Accessibility Demo",
      button_clicks: 0,
      checkbox_checked: false
    }

    {:ok, {model, []}}
  end

  @impl true
  def update(model, {:button_clicked}) do
    {:ok, %{model | button_clicks: model.button_clicks + 1}}
  end

  @impl true
  def update(model, {:checkbox_toggled}) do
    {:ok, %{model | checkbox_checked: !model.checkbox_checked}}
  end

  @impl true
  def update(model, _event), do: {:ok, model}

  @impl true
  def handle_event(event) do
    {:ok, event}
  end

  @impl Raxol.Core.Runtime.Application
  def handle_message(_message, model), do: {:noreply, model}

  @impl Raxol.Core.Runtime.Application
  def handle_tick(model), do: {:noreply, model}

  @impl Raxol.Core.Runtime.Application
  def subscriptions(_model), do: []

  @impl Raxol.Core.Runtime.Application
  def terminate(_reason, _model), do: :ok

  @impl Raxol.Core.Runtime.Application
  def view(model), do: demo_view(model)

  @doc """
  Renders the accessibility demo view.

  ## Parameters
    - model: The model to render

  ## Returns
    - The rendered view
  """
  def demo_view(model) do
    View.column(
      do: [
        View.text(model.message, style: [[:bold]]),
        View.button(
          "Click Me (#{model.button_clicks})",
          on_click: {:button_clicked},
          aria_label: "Increment click counter button",
          aria_description:
            "Press to increment the number of times this button has been clicked."
        ),
        View.checkbox(
          "Enable Feature",
          checked: model.checkbox_checked,
          on_toggle: {:checkbox_toggled},
          aria_label: "Enable or disable the example feature",
          aria_description: "Toggles a conceptual feature on or off."
        ),
        View.text(
          "Checkbox is: #{if model.checkbox_checked, do: "Checked", else: "Unchecked"}",
          aria_live: :polite
        ),
        View.text_input(
          placeholder: "Enter your name...",
          value: "",
          aria_label: "Name input field",
          aria_description: "Enter your first and last name here."
        )
      ]
    )
  end

  @doc """
  Gets the accessibility settings.

  ## Parameters
    - user_preferences_pid_or_name: The user preferences process ID or name

  ## Returns
    - A map containing the accessibility settings
  """
  def get_settings(user_preferences_pid_or_name) do
    alias Raxol.Core.Accessibility.Preferences

    %{
      enabled:
        Preferences.get_option(:enabled, user_preferences_pid_or_name, true),
      screen_reader:
        Preferences.get_option(
          :screen_reader,
          user_preferences_pid_or_name,
          true
        ),
      high_contrast:
        Preferences.get_option(
          :high_contrast,
          user_preferences_pid_or_name,
          false
        ),
      reduced_motion:
        Preferences.get_option(
          :reduced_motion,
          user_preferences_pid_or_name,
          false
        ),
      keyboard_focus:
        Preferences.get_option(
          :keyboard_focus,
          user_preferences_pid_or_name,
          true
        ),
      large_text:
        Preferences.get_option(:large_text, user_preferences_pid_or_name, false),
      silence_announcements:
        Preferences.get_option(
          :silence_announcements,
          user_preferences_pid_or_name,
          false
        )
    }
  end

  # Optional: If this demo needs to be run directly
  # def main(args \\ []) do
  #   Raxol.run(__MODULE__, args)
  # end
end
