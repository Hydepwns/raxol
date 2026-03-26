defmodule Raxol.Recording.Session do
  @moduledoc """
  Data structure for a recorded terminal session.

  Contains metadata (dimensions, timestamps, environment) and a list of
  timestamped output events captured during recording.
  """

  defstruct [
    :width,
    :height,
    :started_at,
    :ended_at,
    :title,
    :env,
    events: []
  ]

  @type event ::
          {elapsed_us :: non_neg_integer(), type :: :output, data :: binary()}

  @type t :: %__MODULE__{
          width: pos_integer(),
          height: pos_integer(),
          started_at: DateTime.t(),
          ended_at: DateTime.t() | nil,
          title: String.t() | nil,
          env: map(),
          events: [event()]
        }

  @doc "Creates a new session with current terminal dimensions."
  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    {width, height} = detect_size()

    %__MODULE__{
      width: Keyword.get(opts, :width, width),
      height: Keyword.get(opts, :height, height),
      started_at: DateTime.utc_now(),
      title: Keyword.get(opts, :title),
      env: %{"TERM" => System.get_env("TERM", "xterm-256color")},
      events: []
    }
  end

  @doc "Returns the total duration in seconds."
  @spec duration(t()) :: float()
  def duration(%__MODULE__{events: []}), do: 0.0

  def duration(%__MODULE__{events: events}) do
    {last_us, _, _} = List.last(events)
    last_us / 1_000_000
  end

  @doc "Returns event count."
  @spec event_count(t()) :: non_neg_integer()
  def event_count(%__MODULE__{events: events}), do: length(events)

  defp detect_size do
    width =
      case :io.columns() do
        {:ok, w} -> w
        _ -> 80
      end

    height =
      case :io.rows() do
        {:ok, h} -> h
        _ -> 24
      end

    {width, height}
  end
end
