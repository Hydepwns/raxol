defmodule Raxol.Examples.Form do
  @moduledoc """
  A sample form component that demonstrates parent-child interactions.

  This component includes:
  - Child component management
  - Event bubbling
  - State synchronization
  - Error boundaries
  """

  use GenServer
  use Raxol.App

  @impl true
  def init(_opts) do
    {:ok,
     %{
       # Initial state for the form example
       username: "",
       password: "",
       remember_me: false,
       submit_label: "Login",
       title: "Login Form",
       error: nil
     }}
  end

  @impl true
  def update({:field_changed, field, value}, state) do
    # Update the specific field
    new_state = Map.put(state, field, value)
    {:noreply, new_state}
  end

  @impl true
  def update(:button_clicked, state) do
    # Simulate login attempt
    if state.username == "admin" and state.password == "password" do
      IO.puts("Login successful!")
      {:noreply, %{state | error: nil, title: "Welcome Admin!"}}
    else
      {:noreply, %{state | error: "Invalid credentials"}}
    end
  end

  # Catch-all update
  @impl true
  def update(_msg, state), do: {:noreply, state}

  @impl true
  @spec render(map()) :: Raxol.Core.Renderer.Element.t() | nil
  @dialyzer {:nowarn_function, render: 1}
  def render(state) do
    # Render the form using Raxol.View elements
    # We need to require Raxol.View and alias Layout/Components
    require Raxol.View
    alias Raxol.View.Layout
    alias Raxol.View.Components

    # Use Layout.column, Components.text, etc.
    Layout.column style: %{border: :single, padding: 1} do
      # Wrap children in a list
      [
        Components.text(state.title, style: %{bold: true, align: :center}),
        # Display error message if present
        if state.error do
          Components.text(state.error, style: %{color: :red})
        else
          nil
        end,
        # Input fields (assuming text_input component exists)
        # render_field(:username, state.username),
        # render_field(:password, state.password, type: :password),
        # Checkbox (assuming checkbox component exists)
        # render_field(:remember_me, state.remember_me, type: :checkbox),
        Components.button(
          state.submit_label,
          on_click: {:button_clicked},
          style: %{marginTop: 1}
        )
      ]
      # Filter out nil error message
      |> Enum.reject(&is_nil(&1))
    end
  end

  # Helper function to render a field (needs actual component implementation)
  # defp render_field(id, value, opts \\ []) do
  #   label = Atom.to_string(id) |> String.capitalize()
  #   type = Keyword.get(opts, :type, :text)
  #
  #   Components.text(label, style: %{bold: true})
  #   # Placeholder for actual input component call
  #   # case type do
  #   #   :password -> Raxol.Components.TextInput.new(id: id, value: value, type: :password, on_change: {:field_changed, id})
  #   #   :checkbox -> Raxol.Components.Checkbox.new(id: id, checked: value, label: "", on_change: {:field_changed, id})
  #   #   _ -> Raxol.Components.TextInput.new(id: id, value: value, on_change: {:field_changed, id})
  #   # end
  # end
end
