defmodule FormValidationExample do
  # use Raxol.App, otp_app: :raxol
  use Raxol.Component
  import Raxol.LiveView, only: [assign: 2, assign: 3]

  # alias Raxol.View.Components.TextInput
  # alias Raxol.View.Components.Button
  alias Raxol.View.Elements

  @impl Raxol.Component
  # def init(_flags) do
  #   state = %{
  #     name: "",
  #     email: "",
  #     errors: %{}
  #   }
  #
  #   {:ok, state}
  # end
  def mount(_params, _session, socket) do
    socket =
      assign(socket,
        name: "",
        email: "",
        errors: %{}
      )

    {:ok, socket}
  end

  @impl Raxol.Component
  def handle_event(
        "input_changed",
        %{"field" => field_str, "value" => value},
        socket
      ) do
    field = String.to_existing_atom(field_str)
    socket = assign(socket, [{field, value}])
    new_errors = Map.delete(socket.assigns.errors, field)
    {:noreply, assign(socket, :errors, new_errors)}
  end

  @impl Raxol.Component
  def handle_event("submit", _params, socket) do
    errors = validate(socket.assigns)
    {:noreply, assign(socket, :errors, errors)}
  end

  # --- Helper Functions --- #

  defp validate(assigns) do
    errors = %{}

    errors =
      if String.trim(assigns.name) == "" do
        Map.put(errors, :name, "Name cannot be blank")
      else
        errors
      end

    errors =
      if String.trim(assigns.email) == "" do
        Map.put(errors, :email, "Email cannot be blank")
      else
        # Basic email format check
        if !String.contains?(assigns.email, "@") do
          Map.put(errors, :email, "Email must contain @")
        else
          errors
        end
      end

    errors
  end

  @impl Raxol.Component
  # def render(state) do
  #   use Raxol.View
  #
  #   panel title: "Interactive Form", padding: 1, border: :rounded do
  #     column gap: 1 do
  #       # --- Name Field --- #
  #       row gap: 1, align: :center do
  #         # Label
  #         text("Name: ")
  #
  #         TextInput.text_input(
  #           # Unique ID for focus/state
  #           id: :name_input,
  #           # Bind value to state
  #           value: state.name,
  #           placeholder: "Enter your name",
  #           # Send message on change: {:input_changed, field_atom, new_value}
  #           on_change: fn new_value -> {:input_changed, :name, new_value} end
  #         )
  #
  #         # Error message placeholder
  #         text(Map.get(state.errors, :name, ""),
  #           id: :name_error,
  #           fg: :red,
  #           flex: 1
  #         )
  #       end
  #
  #       # --- Email Field --- #
  #       row gap: 1, align: :center do
  #         # Label
  #         text("Email:")
  #
  #         TextInput.text_input(
  #           id: :email_input,
  #           value: state.email,
  #           placeholder: "Enter your email",
  #           on_change: fn new_value -> {:input_changed, :email, new_value} end
  #         )
  #
  #         # Error message placeholder
  #         text(Map.get(state.errors, :email, ""),
  #           id: :email_error,
  #           fg: :red,
  #           flex: 1
  #         )
  #       end
  #
  #       # --- Submit Button --- #
  #       # Center the button
  #       row justify: :center do
  #         Button.button("Submit", id: :submit_button, on_click: :submit)
  #       end
  #     end
  #   end
  # end
  def render(assigns) do
    ~V"""
    <.panel title="Interactive Form" padding=1 border=:rounded>
      <.column gap=1 rax-change="input_changed"> # Use rax-change on container
        # --- Name Field --- #
        <.row gap=1 align=:center>
          <.text>Name: </.text>
          <.text_input
            id="name_input"
            name="name" # Corresponds to field name in event
            value={assigns.name}
            placeholder="Enter your name"
            rax-value-field="name" # Send "name" in event params
          />
          <.text id="name_error" fg=:red flex=1>
            {Map.get(assigns.errors, :name, "")}
          </.text>
        </.row>

        # --- Email Field --- #
        <.row gap=1 align=:center>
          <.text>Email:</.text>
          <.text_input
            id="email_input"
            name="email" # Corresponds to field name in event
            value={assigns.email}
            placeholder="Enter your email"
            rax-value-field="email" # Send "email" in event params
          />
          <.text id="email_error" fg=:red flex=1>
            {Map.get(assigns.errors, :email, "")}
          </.text>
        </.row>

        # --- Submit Button --- #
        <.row justify=:center>
          <.button id="submit_button" rax-click="submit">Submit</.button>
        </.row>
      </.column>
    </.panel>
    """
  end
end
