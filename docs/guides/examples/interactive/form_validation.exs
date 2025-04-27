defmodule FormValidationExample do
  use Raxol.App, otp_app: :raxol

  alias Raxol.View.Components.TextInput
  alias Raxol.View.Components.Button

  @impl Raxol.App
  def init(_flags) do
    state = %{
      name: "",
      email: "",
      errors: %{}
    }

    {:ok, state}
  end

  @impl Raxol.App
  def update(msg, state) do
    case msg do
      # Update state when input changes and clear the specific error
      {:input_changed, field, value} when field in [:name, :email] ->
        new_state = Map.put(state, field, value)
        new_errors = Map.delete(state.errors, field)
        {:ok, %{new_state | errors: new_errors}}

      # Validate and update errors on submit
      :submit ->
        errors = validate(state)
        IO.inspect(errors, label: "Validation Errors")
        # If no errors, maybe show success or clear form (TBD)
        # For now, just update the errors map
        {:ok, %{state | errors: errors}}

      # Default case (ignore other messages)
      _ ->
        {:ok, state}
    end
  end

  # --- Helper Functions --- #

  defp validate(state) do
    errors = %{}

    errors =
      if String.trim(state.name) == "" do
        Map.put(errors, :name, "Name cannot be blank")
      else
        errors
      end

    errors =
      if String.trim(state.email) == "" do
        Map.put(errors, :email, "Email cannot be blank")
      else
        # Basic email format check
        if !String.contains?(state.email, "@") do
          Map.put(errors, :email, "Email must contain @")
        else
          errors
        end
      end

    errors
  end

  @impl Raxol.App
  def render(state) do
    use Raxol.View

    panel title: "Interactive Form", padding: 1, border: :rounded do
      column gap: 1 do
        # --- Name Field --- #
        row gap: 1, align: :center do
          # Label
          text("Name: ")

          TextInput.text_input(
            # Unique ID for focus/state
            id: :name_input,
            # Bind value to state
            value: state.name,
            placeholder: "Enter your name",
            # Send message on change: {:input_changed, field_atom, new_value}
            on_change: fn new_value -> {:input_changed, :name, new_value} end
          )

          # Error message placeholder
          text(Map.get(state.errors, :name, ""),
            id: :name_error,
            fg: :red,
            flex: 1
          )
        end

        # --- Email Field --- #
        row gap: 1, align: :center do
          # Label
          text("Email:")

          TextInput.text_input(
            id: :email_input,
            value: state.email,
            placeholder: "Enter your email",
            on_change: fn new_value -> {:input_changed, :email, new_value} end
          )

          # Error message placeholder
          text(Map.get(state.errors, :email, ""),
            id: :email_error,
            fg: :red,
            flex: 1
          )
        end

        # --- Submit Button --- #
        # Center the button
        row justify: :center do
          Button.button("Submit", id: :submit_button, on_click: :submit)
        end
      end
    end
  end
end
