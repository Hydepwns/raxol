defmodule Raxol.UI.Components.Input.TextInput.Validation do
  @moduledoc """
  Handles input validation for the TextInput component.
  This includes length validation, pattern matching, and error message generation.
  """

  @doc """
  Validates the input value against the component's constraints.
  Returns a new state with any validation errors.
  """
  def validate_input(state) do
    error =
      cond do
        # Check max length
        state.max_length && String.length(state.value) > state.max_length ->
          "Maximum length is #{state.max_length} characters"

        # Check pattern if specified
        state.pattern && not Regex.match?(~r/^#{state.pattern}$/, state.value) ->
          "Invalid input format"

        true ->
          nil
      end

    %{state | error: error}
  end

  @doc """
  Checks if adding a character would exceed the maximum length.
  """
  def would_exceed_max_length?(state, char) when is_integer(char) do
    case state.max_length do
      nil -> false
      max -> String.length(state.value) >= max
    end
  end

  @doc """
  Checks if adding text would exceed the maximum length.
  """
  def would_exceed_max_length?(state, text) when is_binary(text) do
    case state.max_length do
      nil -> false
      max -> String.length(text) > max
    end
  end

  @doc """
  Validates a value against a pattern.
  Returns :ok if valid, {:error, reason} if invalid.
  """
  def validate_pattern(value, pattern) when is_binary(pattern) do
    if Regex.match?(~r/^#{pattern}$/, value) do
      :ok
    else
      {:error, "Invalid input format"}
    end
  end

  @doc """
  Validates a value's length against a maximum.
  Returns :ok if valid, {:error, reason} if invalid.
  """
  def validate_length(value, max_length)
      when is_integer(max_length) and max_length > 0 do
    if String.length(value) <= max_length do
      :ok
    else
      {:error, "Maximum length is #{max_length} characters"}
    end
  end
end
