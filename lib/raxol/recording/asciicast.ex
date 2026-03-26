defmodule Raxol.Recording.Asciicast do
  @moduledoc """
  Serializes and deserializes asciinema v2 `.cast` files.

  The asciicast v2 format is:
  - Line 1: JSON header with version, width, height, timestamp, env
  - Remaining lines: `[elapsed_seconds, "o", "output_data"]` (newline-delimited JSON)

  See: https://docs.asciinema.org/manual/asciicast/v2/
  """

  alias Raxol.Recording.Session

  @doc "Writes a session to a .cast file."
  @spec write!(Session.t(), Path.t()) :: :ok
  def write!(%Session{} = session, path) do
    content = encode(session)
    File.write!(path, content)
  end

  @doc "Reads a .cast file into a session. Returns `{:ok, session}` or `{:error, reason}`."
  @spec read(Path.t()) :: {:ok, Session.t()} | {:error, term()}
  def read(path) do
    with {:ok, content} <- File.read(path) do
      {:ok, decode(content)}
    end
  end

  @doc "Reads a .cast file into a session. Raises on failure."
  @spec read!(Path.t()) :: Session.t()
  def read!(path) do
    case read(path) do
      {:ok, session} -> session
      {:error, reason} -> raise "Failed to read #{path}: #{inspect(reason)}"
    end
  end

  @doc "Encodes a session to asciicast v2 format string."
  @spec encode(Session.t()) :: String.t()
  def encode(%Session{} = session) do
    header = encode_header(session)
    events = Enum.map_join(session.events, "\n", &encode_event/1)

    if events == "" do
      header <> "\n"
    else
      header <> "\n" <> events <> "\n"
    end
  end

  @doc "Decodes an asciicast v2 format string into a session."
  @spec decode(String.t()) :: Session.t()
  def decode(content) do
    [header_line | event_lines] =
      content
      |> String.trim()
      |> String.split("\n")

    header = Jason.decode!(header_line)

    events =
      event_lines
      |> Enum.reject(&(&1 == ""))
      |> Enum.map(&decode_event/1)

    %Session{
      width: header["width"],
      height: header["height"],
      started_at: parse_timestamp(header["timestamp"]),
      title: header["title"],
      command: header["command"],
      idle_time_limit: header["idle_time_limit"],
      theme: header["theme"],
      env: header["env"] || %{},
      events: events
    }
  end

  # -- Private --

  defp encode_header(%Session{} = s) do
    %{
      "version" => 2,
      "width" => s.width,
      "height" => s.height,
      "timestamp" => DateTime.to_unix(s.started_at)
    }
    |> maybe_put("title", s.title)
    |> maybe_put("command", s.command)
    |> maybe_put("idle_time_limit", s.idle_time_limit)
    |> maybe_put("theme", s.theme)
    |> maybe_put("env", if(s.env == %{}, do: nil, else: s.env))
    |> Jason.encode!()
  end

  defp encode_event({elapsed_us, type, data}) do
    seconds = elapsed_us / 1_000_000

    type_str =
      case type do
        :input -> "i"
        _ -> "o"
      end

    Jason.encode!([seconds, type_str, data])
  end

  defp decode_event(line) do
    [seconds, type, data] = Jason.decode!(line)
    elapsed_us = round(seconds * 1_000_000)

    event_type =
      case type do
        "o" -> :output
        "i" -> :input
        _ -> :output
      end

    {elapsed_us, event_type, data}
  end

  defp parse_timestamp(nil), do: DateTime.utc_now()

  defp parse_timestamp(unix) when is_integer(unix) do
    DateTime.from_unix!(unix)
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
