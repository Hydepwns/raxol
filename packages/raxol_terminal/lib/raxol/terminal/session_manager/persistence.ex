defmodule Raxol.Terminal.SessionManager.Persistence do
  @moduledoc """
  Session persistence: save/restore sessions to/from disk.
  """

  alias Raxol.Core.Runtime.Log

  @doc """
  Initializes the persistence manager with a directory path.
  """
  def init(persistence_dir) do
    %{directory: persistence_dir, enabled: true}
  end

  @doc """
  Saves a session to disk if persistence is enabled.
  """
  def save_session(_session, %{enabled: false}), do: :ok

  def save_session(session, %{enabled: true, directory: dir}) do
    filename = Path.join(dir, "#{session.id}.session")
    data = serialize(session)
    File.write(filename, data)
  end

  @doc """
  Restores all persisted sessions from disk.
  Returns a map of session_id => session.
  """
  def restore_all(false, _state), do: %{}

  def restore_all(true, state) do
    persistence_dir = state.config.persistence_directory |> Path.expand()

    case File.ls(persistence_dir) do
      {:ok, files} ->
        files
        |> Enum.filter(&String.ends_with?(&1, ".session"))
        |> Enum.reduce(%{}, fn file, acc ->
          file_path = Path.join(persistence_dir, file)

          case restore_from_file(file_path) do
            {:ok, session} -> Map.put(acc, session.id, session)
            {:error, _reason} -> acc
          end
        end)

      {:error, reason} ->
        Log.warning("Could not list persistence directory: #{inspect(reason)}")
        %{}
    end
  end

  @doc """
  Restores a single session from a file path.
  """
  def restore_from_file(file) do
    with {:ok, data} <- File.read(file),
         {:ok, session} <- deserialize(data) do
      Log.info("Restored session '#{session.name}' from #{file}")
      {:ok, session}
    else
      {:error, reason} ->
        Log.warning("Failed to restore session from #{file}: #{inspect(reason)}")

        {:error, reason}
    end
  end

  defp serialize(session) do
    session
    |> Map.from_struct()
    |> :erlang.term_to_binary()
  end

  defp deserialize(data) do
    case Raxol.Core.ErrorHandling.safe_call(fn ->
           session_map = :erlang.binary_to_term(data, [:safe])
           struct(Raxol.Terminal.SessionManager.Session, session_map)
         end) do
      {:ok, session} -> {:ok, session}
      {:error, reason} -> {:error, reason}
    end
  end
end
