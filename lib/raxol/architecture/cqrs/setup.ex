defmodule Raxol.Architecture.CQRS.Setup do
  @moduledoc """
  Setup and initialization for CQRS and Event Sourcing components.

  This module handles the registration of command handlers and middleware,
  ensuring the CQRS system is properly configured when the application starts.
  """
  alias Raxol.Architecture.CQRS.CommandDispatcher

  alias Raxol.Architecture.CQRS.Middleware.{
    ValidationMiddleware,
    AuthorizationMiddleware,
    LoggingMiddleware
  }

  alias Raxol.Commands.{
    CreateTerminalCommand,
    UpdateTerminalCommand,
    SendInputCommand,
    CloseTerminalCommand,
    ApplyThemeCommand
  }

  alias Raxol.Core.Runtime.Log

  alias Raxol.Handlers.{
    CreateTerminalHandler,
    UpdateTerminalHandler,
    SendInputHandler,
    CloseTerminalHandler,
    ApplyThemeHandler
  }

  @doc """
  Sets up the CQRS system by registering handlers and middleware.
  """
  def setup do
    Log.info("Setting up CQRS system...")

    # Add middleware in the correct order (executed in reverse)
    :ok = CommandDispatcher.add_middleware(LoggingMiddleware)
    :ok = CommandDispatcher.add_middleware(AuthorizationMiddleware)
    :ok = CommandDispatcher.add_middleware(ValidationMiddleware)

    # Register command handlers
    :ok =
      CommandDispatcher.register_handler(
        CreateTerminalCommand,
        CreateTerminalHandler
      )

    :ok =
      CommandDispatcher.register_handler(
        UpdateTerminalCommand,
        UpdateTerminalHandler
      )

    :ok = CommandDispatcher.register_handler(SendInputCommand, SendInputHandler)

    :ok =
      CommandDispatcher.register_handler(
        CloseTerminalCommand,
        CloseTerminalHandler
      )

    :ok =
      CommandDispatcher.register_handler(ApplyThemeCommand, ApplyThemeHandler)

    Log.info("CQRS system setup completed")
    :ok
  end

  @doc """
  Gets the list of registered handlers for verification.
  """
  def list_handlers do
    CommandDispatcher.list_handlers()
  end

  @doc """
  Gets CQRS system statistics.
  """
  def get_statistics do
    CommandDispatcher.get_statistics()
  end
end
