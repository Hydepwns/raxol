defmodule RaxolWeb.PageLive do
  use RaxolWeb, :live_view

  def mount(_params, _session, socket) do
    theme = get_connect_params(socket)["theme"] || "light"
    high_contrast = get_connect_params(socket)["high_contrast"] || "false"
    reduced_motion = get_connect_params(socket)["reduced_motion"] || "false"
    font_size = get_connect_params(socket)["font_size"] || "normal"

    {:ok,
     socket
     |> assign(:theme, theme)
     |> assign(:high_contrast, high_contrast)
     |> assign(:reduced_motion, reduced_motion)
     |> assign(:font_size, font_size)}
  end

  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  def handle_event("toggle_high_contrast", _params, socket) do
    new_value =
      if socket.assigns.high_contrast == "true", do: "false", else: "true"

    {:noreply,
     socket
     |> assign(:high_contrast, new_value)
     |> push_event("high_contrast_changed", %{value: new_value})}
  end

  def handle_event("toggle_reduced_motion", _params, socket) do
    new_value =
      if socket.assigns.reduced_motion == "true", do: "false", else: "true"

    {:noreply,
     socket
     |> assign(:reduced_motion, new_value)
     |> push_event("reduced_motion_changed", %{value: new_value})}
  end

  def handle_event("toggle_font_size", _params, socket) do
    new_value =
      case socket.assigns.font_size do
        "normal" -> "large"
        "large" -> "larger"
        "larger" -> "normal"
      end

    {:noreply,
     socket
     |> assign(:font_size, new_value)
     |> push_event("font_size_changed", %{value: new_value})}
  end
end
