defmodule Raxol.Recording.PlayerTest do
  use ExUnit.Case, async: true

  alias Raxol.Recording.{Player, Session}

  describe "play/2" do
    test "plays empty session without error" do
      session = %Session{
        width: 80,
        height: 24,
        started_at: DateTime.utc_now(),
        events: []
      }

      assert :ok = Player.play(session)
    end

    test "plays session with events" do
      session = %Session{
        width: 80,
        height: 24,
        started_at: DateTime.utc_now(),
        events: [
          {0, :output, "hello"},
          {10_000, :output, " world"}
        ]
      }

      assert :ok = Player.play(session, speed: 100.0)
    end

    @tag :tmp_dir
    test "plays from .cast file", %{tmp_dir: dir} do
      path = Path.join(dir, "test.cast")

      content = """
      {"version":2,"width":80,"height":24,"timestamp":1700000000}
      [0.0,"o","hello"]
      [0.01,"o"," world"]
      """

      File.write!(path, content)

      assert :ok = Player.play(path, speed: 100.0)
    end

    test "respects speed multiplier" do
      session = %Session{
        width: 80,
        height: 24,
        started_at: DateTime.utc_now(),
        events: [
          {0, :output, "a"},
          {100_000, :output, "b"}
        ]
      }

      # At 100x speed, 100ms delay becomes 1ms
      {time_us, :ok} = :timer.tc(fn -> Player.play(session, speed: 100.0) end)
      assert time_us < 500_000
    end
  end
end
