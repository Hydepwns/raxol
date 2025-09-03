defmodule RaxolWeb.Settings.PreferencesComponent do
  use RaxolWeb, :live_component
  alias Raxol.Core.UserPreferences

  def render(assigns) do
    ~H"""
    <div class="settings-section">
      <h2 class="settings-section-title">Terminal Preferences</h2>
      <.form
        for={@preferences_changeset}
        id="preferences-form"
        phx-submit="update_preferences"
        phx-change="validate_preferences"
        phx-target={@myself}
        class="settings-form"
      >
        <.form_group
          name="font_size"
          label="Font Size"
          type="number"
          value={@preferences["terminal"]["font_size"]}
          min="8"
          max="24"
        />
        <.form_group
          name="font_family"
          label="Font Family"
          type="text"
          value={@preferences["terminal"]["font_family"]}
        />
        <.form_group
          name="scrollback_size"
          label="Scrollback Size"
          type="number"
          value={@preferences["terminal"]["scrollback_size"]}
          min="100"
          max="10000"
        />

        <div class="mt-4">
          <.button type="submit" class="settings-button">
            Update Preferences
          </.button>
        </div>
      </.form>
    </div>
    """
  end

  def handle_event("update_preferences", params, socket) do
    preferences = socket.assigns.preferences

    # Sanitize and validate input
    case sanitize_preferences_params(params) do
      {:ok, sanitized_params} ->
        updated_preferences =
          Map.merge(preferences, %{
            "terminal" => %{
              "font_size" => sanitized_params["font_size"],
              "font_family" => sanitized_params["font_family"],
              "scrollback_size" => sanitized_params["scrollback_size"]
            }
          })

        UserPreferences.set_preferences(updated_preferences)
        send(self(), {:preferences_updated, updated_preferences})

        {:noreply,
         socket
         |> put_flash(:info, "Preferences updated successfully.")
         |> assign(:preferences, updated_preferences)}

      {:error, reason} ->
        {:noreply,
         socket
         |> put_flash(:error, "Invalid preferences: #{reason}")
         |> assign(:preferences_changeset, %{
           errors: [{"preferences", {"Invalid input", []}}]
         })}
    end
  end

  def handle_event("validate_preferences", _params, socket) do
    {:noreply, socket}
  end

  defp sanitize_preferences_params(params) do
    case Raxol.Core.ErrorHandling.safe_call(fn ->
           font_size = String.to_integer(params["font_size"])
           scrollback_size = String.to_integer(params["scrollback_size"])

           with :ok <- validate_font_size(font_size),
                :ok <- validate_scrollback_size(scrollback_size) do
             {:ok,
              %{
                "font_size" => font_size,
                "font_family" => String.trim(params["font_family"]),
                "scrollback_size" => scrollback_size
              }}
           end
         end) do
      {:ok, result} -> result
      {:error, _reason} -> {:error, "Invalid numeric values"}
    end
  end

  defp validate_font_size(size) when size < 8 or size > 24 do
    {:error, "Font size must be between 8 and 24"}
  end

  defp validate_font_size(_size), do: :ok

  defp validate_scrollback_size(size) when size < 100 or size > 10_000 do
    {:error, "Scrollback size must be between 100 and 10_000"}
  end

  defp validate_scrollback_size(_size), do: :ok
end
