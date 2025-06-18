defmodule Raxol.Terminal.Session.Storage do
  @moduledoc '''
  Handles persistence of terminal sessions.
  '''

  alias Raxol.Terminal.Session.Serializer

  @doc '''
  Saves a session state to persistent storage.
  '''
  @spec save_session(Raxol.Terminal.Session.t()) :: :ok | {:error, term()}
  def save_session(session) do
    serialized = Serializer.serialize(session)
    storage_path = get_storage_path(session.id)

    case File.write(storage_path, :erlang.term_to_binary(serialized)) do
      :ok -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  @doc '''
  Loads a session state from persistent storage.
  '''
  @spec load_session(String.t()) ::
          {:ok, Raxol.Terminal.Session.t()} | {:error, term()}
  def load_session(session_id) do
    storage_path = get_storage_path(session_id)

    case File.read(storage_path) do
      {:ok, binary} ->
        try do
          serialized = :erlang.binary_to_term(binary)
          Serializer.deserialize(serialized)
        rescue
          _ -> {:error, :invalid_session_data}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc '''
  Deletes a saved session.
  '''
  @spec delete_session(String.t()) :: :ok | {:error, term()}
  def delete_session(session_id) do
    storage_path = get_storage_path(session_id)
    File.rm(storage_path)
  end

  @doc '''
  Lists all saved sessions.
  '''
  @spec list_sessions() :: {:ok, [String.t()]} | {:error, term()}
  def list_sessions do
    storage_dir = get_storage_dir()

    case File.ls(storage_dir) do
      {:ok, files} ->
        sessions =
          files
          |> Enum.filter(&String.ends_with?(&1, ".session"))
          |> Enum.map(&String.replace(&1, ".session", ""))

        {:ok, sessions}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Private functions

  defp get_storage_dir do
    base_dir = Application.get_env(:raxol, :session_storage_dir, "tmp/sessions")
    File.mkdir_p!(base_dir)
    base_dir
  end

  defp get_storage_path(session_id) do
    Path.join(get_storage_dir(), "#{session_id}.session")
  end
end
