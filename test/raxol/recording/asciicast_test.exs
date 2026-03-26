defmodule Raxol.Recording.AsciicastTest do
  use ExUnit.Case, async: true

  alias Raxol.Recording.{Asciicast, Session}

  describe "encode/1" do
    test "encodes empty session" do
      session = %Session{
        width: 80,
        height: 24,
        started_at: DateTime.from_unix!(1_700_000_000),
        events: []
      }

      result = Asciicast.encode(session)
      [header_line | _] = String.split(result, "\n")
      header = Jason.decode!(header_line)

      assert header["version"] == 2
      assert header["width"] == 80
      assert header["height"] == 24
      assert header["timestamp"] == 1_700_000_000
    end

    test "encodes session with events" do
      session = %Session{
        width: 80,
        height: 24,
        started_at: DateTime.from_unix!(1_700_000_000),
        events: [
          {0, :output, "hello"},
          {500_000, :output, " world"}
        ]
      }

      result = Asciicast.encode(session)
      lines = String.trim(result) |> String.split("\n")

      assert length(lines) == 3

      event1 = Jason.decode!(Enum.at(lines, 1))
      assert [+0.0, "o", "hello"] = event1

      event2 = Jason.decode!(Enum.at(lines, 2))
      assert [0.5, "o", " world"] = event2
    end

    test "includes title when present" do
      session = %Session{
        width: 80,
        height: 24,
        started_at: DateTime.from_unix!(1_700_000_000),
        title: "My Demo",
        events: []
      }

      result = Asciicast.encode(session)
      header = result |> String.split("\n") |> hd() |> Jason.decode!()
      assert header["title"] == "My Demo"
    end

    test "includes env when present" do
      session = %Session{
        width: 80,
        height: 24,
        started_at: DateTime.from_unix!(1_700_000_000),
        env: %{"TERM" => "xterm-256color"},
        events: []
      }

      result = Asciicast.encode(session)
      header = result |> String.split("\n") |> hd() |> Jason.decode!()
      assert header["env"]["TERM"] == "xterm-256color"
    end
  end

  describe "decode/1" do
    test "decodes encoded session (roundtrip)" do
      original = %Session{
        width: 120,
        height: 40,
        started_at: DateTime.from_unix!(1_700_000_000),
        title: "Roundtrip",
        env: %{"TERM" => "screen"},
        events: [
          {0, :output, "line 1\r\n"},
          {1_000_000, :output, "line 2\r\n"},
          {2_500_000, :output, "done"}
        ]
      }

      encoded = Asciicast.encode(original)
      decoded = Asciicast.decode(encoded)

      assert decoded.width == 120
      assert decoded.height == 40
      assert decoded.title == "Roundtrip"
      assert decoded.env["TERM"] == "screen"
      assert length(decoded.events) == 3

      # Check event data
      texts = Enum.map(decoded.events, fn {_t, _type, data} -> data end)
      assert texts == ["line 1\r\n", "line 2\r\n", "done"]

      # Check timestamps (microsecond precision may round)
      times = Enum.map(decoded.events, fn {t, _, _} -> t end)
      assert Enum.at(times, 0) == 0
      assert Enum.at(times, 1) == 1_000_000
      assert Enum.at(times, 2) == 2_500_000
    end

    test "handles ANSI escape codes in output" do
      session = %Session{
        width: 80,
        height: 24,
        started_at: DateTime.from_unix!(1_700_000_000),
        events: [
          {0, :output, "\e[31mred text\e[0m"},
          {100_000, :output, "\e[H\e[2J"}
        ]
      }

      encoded = Asciicast.encode(session)
      decoded = Asciicast.decode(encoded)

      [{_, _, data1}, {_, _, data2}] = decoded.events
      assert data1 == "\e[31mred text\e[0m"
      assert data2 == "\e[H\e[2J"
    end
  end

  describe "write!/2 and read!/1" do
    @tag :tmp_dir
    test "writes and reads .cast files", %{tmp_dir: dir} do
      path = Path.join(dir, "test.cast")

      session = %Session{
        width: 80,
        height: 24,
        started_at: DateTime.from_unix!(1_700_000_000),
        title: "File Test",
        events: [
          {0, :output, "hello"},
          {1_000_000, :output, "world"}
        ]
      }

      Asciicast.write!(session, path)
      assert File.exists?(path)

      loaded = Asciicast.read!(path)
      assert loaded.width == 80
      assert loaded.title == "File Test"
      assert length(loaded.events) == 2
    end
  end
end
