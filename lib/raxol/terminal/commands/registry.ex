defmodule Raxol.Terminal.Commands.Registry do
  @moduledoc false

  @type command_name :: String.t()
  @type command_description :: String.t()
  @type command_handler :: function()
  @type command_aliases :: [String.t()]
  @type command_usage :: String.t()
  @type command_completion :: function() | nil

  @type command_metrics :: %{
          registrations: integer(),
          executions: integer(),
          completions: integer(),
          validations: integer()
        }

  @type command :: %{
          name: command_name(),
          description: command_description(),
          handler: command_handler(),
          aliases: command_aliases(),
          usage: command_usage(),
          completion: command_completion()
        }

  @type t :: %__MODULE__{
          commands: %{String.t() => command()},
          history: [String.t()],
          max_history: integer(),
          metrics: command_metrics()
        }

  defstruct [
    :commands,
    :history,
    :max_history,
    :metrics
  ]

  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    %__MODULE__{
      commands: %{},
      history: [],
      max_history: Keyword.get(opts, :max_history, 1000),
      metrics: %{
        registrations: 0,
        executions: 0,
        completions: 0,
        validations: 0
      }
    }
  end

  @spec register_command(t(), command()) :: {:ok, t()} | {:error, term()}
  def register_command(registry, command) do
    with :ok <- validate_command(command),
         :ok <- check_name_conflict(registry, command) do
      new_commands = Map.put(registry.commands, command.name, command)

      updated_registry = %{
        registry
        | commands: new_commands,
          metrics: update_metrics(registry.metrics, :registrations)
      }

      {:ok, updated_registry}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @spec execute_command(t(), String.t(), [String.t()]) ::
          {:ok, t(), term()} | {:error, term()}
  def execute_command(registry, command_name, args) do
    with {:ok, command} <- get_command(registry, command_name),
         :ok <- validate_args(command, args) do
      result = command.handler.(args)

      updated_registry = %{
        registry
        | history:
            [command_name | registry.history] |> Enum.take(registry.max_history),
          metrics: update_metrics(registry.metrics, :executions)
      }

      {:ok, updated_registry, result}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @spec get_completions(t(), String.t()) ::
          {:ok, t(), [String.t()]} | {:error, term()}
  def get_completions(registry, input) do
    suggestions =
      registry.commands
      |> Map.values()
      |> Enum.flat_map(fn command ->
        [command.name | command.aliases]
      end)
      |> Enum.filter(&String.starts_with?(&1, input))
      |> Enum.uniq()
      |> Enum.sort()

    updated_registry = %{
      registry
      | metrics: update_metrics(registry.metrics, :completions)
    }

    {:ok, updated_registry, suggestions}
  end

  @spec get_history(t()) :: [String.t()]
  def get_history(registry) do
    registry.history
  end

  @spec get_metrics(t()) :: map()
  def get_metrics(registry) do
    registry.metrics
  end

  @spec clear_history(t()) :: t()
  def clear_history(registry) do
    %{registry | history: []}
  end

  defp validate_command(command) do
    required_fields = [:name, :description, :handler, :usage]

    if Enum.all?(required_fields, &Map.has_key?(command, &1)) do
      :ok
    else
      {:error, :invalid_command}
    end
  end

  defp check_name_conflict(registry, command) do
    if Map.has_key?(registry.commands, command.name) do
      {:error, :command_exists}
    else
      :ok
    end
  end

  defp get_command(registry, name) do
    case Map.get(registry.commands, name) do
      nil -> {:error, :command_not_found}
      command -> {:ok, command}
    end
  end

  defp validate_args(command, args) do
    if command.completion do
      case command.completion.(args) do
        :ok -> :ok
        {:error, reason} -> {:error, reason}
      end
    else
      :ok
    end
  end

  defp update_metrics(metrics, :registrations) do
    update_in(metrics.registrations, &(&1 + 1))
  end

  defp update_metrics(metrics, :executions) do
    update_in(metrics.executions, &(&1 + 1))
  end

  defp update_metrics(metrics, :completions) do
    update_in(metrics.completions, &(&1 + 1))
  end
end
