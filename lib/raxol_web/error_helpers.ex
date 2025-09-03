defmodule RaxolWeb.ErrorHelpers do
  @moduledoc """
  Helper functions for consistent error handling in RaxolWeb.

  This module provides utilities for:
  - LiveView error handling
  - Form input sanitization
  - Safe assign operations
  """
  require Logger
  import Phoenix.Component, only: [assign: 2, assign: 3]
  import Phoenix.LiveView, only: [put_flash: 3]

  @doc """
  Handles LiveView errors consistently across the application.
  """
  def handle_live_view_error(socket, error, fallback_assigns \\ %{}) do
    Logger.error("LiveView error: #{inspect(error)}")

    socket
    |> put_flash(:error, "An unexpected error occurred")
    |> assign(fallback_assigns)
  end

  @doc """
  Safely assigns a value to the socket, handling errors gracefully.
  """
  def safe_assign(socket, key, value_fn) when is_function(value_fn) do
    case Raxol.Core.ErrorHandling.safe_call(value_fn) do
      {:ok, value} ->
        assign(socket, key, value)
      {:error, error} ->
        Logger.error("Error assigning #{key}: #{inspect(error)}")
        assign(socket, key, nil)
    end
  end

  @doc """
  Creates a standardized error response for forms.
  """
  def create_form_error_response(socket, field, message, error_text) do
    socket
    |> put_flash(:error, message)
    |> assign(:changeset, %{
      errors: [{field, {error_text, []}}]
    })
  end

  @doc """
  Handles channel errors consistently.
  """
  def handle_channel_error(socket, error, context \\ %{}) do
    Logger.error("Channel error in #{context[:module]}: #{inspect(error)}")

    case error do
      :rate_limited ->
        {:reply, {:error, %{reason: "rate_limited"}}, socket}

      :invalid_input ->
        {:reply, {:error, %{reason: "invalid_input"}}, socket}

      _ ->
        {:reply, {:error, %{reason: "internal_error"}}, socket}
    end
  end
end
