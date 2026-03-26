defmodule Raxol.Debug.TimeTravelTest do
  use ExUnit.Case, async: true

  alias Raxol.Debug.TimeTravel

  setup do
    pid = start_supervised!({TimeTravel, max_snapshots: 100})
    {:ok, tt: pid}
  end

  describe "record/4 and count/1" do
    test "records snapshots", %{tt: tt} do
      assert TimeTravel.count(tt) == 0
      TimeTravel.record(tt, :inc, %{count: 0}, %{count: 1})
      # cast is async, sync with a call
      assert TimeTravel.count(tt) == 1
    end

    test "records multiple snapshots in order", %{tt: tt} do
      for i <- 0..4 do
        TimeTravel.record(tt, {:inc, i}, %{count: i}, %{count: i + 1})
      end

      assert TimeTravel.count(tt) == 5
    end

    test "respects max_snapshots limit" do
      small = start_supervised!({TimeTravel, max_snapshots: 3, name: nil}, id: :small)

      for i <- 0..9 do
        TimeTravel.record(small, {:inc, i}, %{count: i}, %{count: i + 1})
      end

      assert TimeTravel.count(small) == 3

      entries = TimeTravel.list_entries(small)
      indices = Enum.map(entries, & &1.index)
      # Only the last 3 should remain
      assert indices == [7, 8, 9]
    end
  end

  describe "current/1" do
    test "returns error when empty", %{tt: tt} do
      assert {:error, :empty} = TimeTravel.current(tt)
    end

    test "returns the latest snapshot after recording", %{tt: tt} do
      TimeTravel.record(tt, :a, %{v: 0}, %{v: 1})
      TimeTravel.record(tt, :b, %{v: 1}, %{v: 2})

      assert {:ok, snap} = TimeTravel.current(tt)
      assert snap.index == 1
      assert snap.message == :b
      assert snap.model_after == %{v: 2}
    end
  end

  describe "step_back/1 and step_forward/1" do
    test "steps back through history", %{tt: tt} do
      TimeTravel.record(tt, :a, %{v: 0}, %{v: 1})
      TimeTravel.record(tt, :b, %{v: 1}, %{v: 2})
      TimeTravel.record(tt, :c, %{v: 2}, %{v: 3})

      assert {:ok, snap} = TimeTravel.step_back(tt)
      assert snap.index == 1
      assert snap.message == :b
    end

    test "returns error at start of history", %{tt: tt} do
      TimeTravel.record(tt, :a, %{v: 0}, %{v: 1})

      assert {:error, :at_start} = TimeTravel.step_back(tt)
    end

    test "steps forward after stepping back", %{tt: tt} do
      TimeTravel.record(tt, :a, %{v: 0}, %{v: 1})
      TimeTravel.record(tt, :b, %{v: 1}, %{v: 2})

      {:ok, _} = TimeTravel.step_back(tt)
      assert {:ok, snap} = TimeTravel.step_forward(tt)
      assert snap.index == 1
    end

    test "returns error at end of history", %{tt: tt} do
      TimeTravel.record(tt, :a, %{v: 0}, %{v: 1})

      assert {:error, :at_end} = TimeTravel.step_forward(tt)
    end

    test "navigates back and forth correctly", %{tt: tt} do
      for i <- 0..4 do
        TimeTravel.record(tt, {:msg, i}, %{v: i}, %{v: i + 1})
      end

      # At index 4, step back to 3
      {:ok, s3} = TimeTravel.step_back(tt)
      assert s3.index == 3

      # Step back to 2
      {:ok, s2} = TimeTravel.step_back(tt)
      assert s2.index == 2

      # Step forward to 3
      {:ok, s3b} = TimeTravel.step_forward(tt)
      assert s3b.index == 3

      # Step forward to 4
      {:ok, s4} = TimeTravel.step_forward(tt)
      assert s4.index == 4

      # Can't go further
      assert {:error, :at_end} = TimeTravel.step_forward(tt)
    end
  end

  describe "jump_to/2" do
    test "jumps to a specific index", %{tt: tt} do
      for i <- 0..4 do
        TimeTravel.record(tt, {:msg, i}, %{v: i}, %{v: i + 1})
      end

      assert {:ok, snap} = TimeTravel.jump_to(tt, 2)
      assert snap.index == 2
      assert snap.model_after == %{v: 3}
    end

    test "returns error for non-existent index", %{tt: tt} do
      TimeTravel.record(tt, :a, %{v: 0}, %{v: 1})
      assert {:error, :not_found} = TimeTravel.jump_to(tt, 999)
    end

    test "updates cursor position", %{tt: tt} do
      for i <- 0..4 do
        TimeTravel.record(tt, {:msg, i}, %{v: i}, %{v: i + 1})
      end

      {:ok, _} = TimeTravel.jump_to(tt, 1)
      {:ok, current} = TimeTravel.current(tt)
      assert current.index == 1
    end
  end

  describe "list_entries/1" do
    test "returns summaries for all snapshots", %{tt: tt} do
      TimeTravel.record(tt, :inc, %{count: 0}, %{count: 1})
      TimeTravel.record(tt, :dec, %{count: 1}, %{count: 0})

      entries = TimeTravel.list_entries(tt)
      assert length(entries) == 2

      [e1, e2] = entries
      assert e1.index == 0
      assert e1.changed == true
      assert e2.index == 1
      assert is_binary(e1.summary)
    end
  end

  describe "diff/3" do
    test "diffs two snapshots by index", %{tt: tt} do
      TimeTravel.record(tt, :a, %{}, %{x: 1, y: 2})
      TimeTravel.record(tt, :b, %{x: 1, y: 2}, %{x: 1, y: 5, z: 3})

      assert {:ok, changes} = TimeTravel.diff(tt, 0, 1)
      assert {:changed, [:y], 2, 5} in changes
      assert {:added, [:z], 3} in changes
    end

    test "returns error for missing index", %{tt: tt} do
      TimeTravel.record(tt, :a, %{}, %{x: 1})
      assert {:error, :not_found} = TimeTravel.diff(tt, 0, 99)
    end
  end

  describe "pause/1 and resume/1" do
    test "pausing stops recording", %{tt: tt} do
      TimeTravel.record(tt, :a, %{v: 0}, %{v: 1})
      assert TimeTravel.count(tt) == 1

      TimeTravel.pause(tt)
      TimeTravel.record(tt, :b, %{v: 1}, %{v: 2})
      # sync
      assert TimeTravel.count(tt) == 1
    end

    test "resuming restarts recording", %{tt: tt} do
      TimeTravel.pause(tt)
      TimeTravel.record(tt, :a, %{v: 0}, %{v: 1})
      assert TimeTravel.count(tt) == 0

      TimeTravel.resume(tt)
      TimeTravel.record(tt, :b, %{v: 1}, %{v: 2})
      assert TimeTravel.count(tt) == 1
    end
  end

  describe "clear/1" do
    test "removes all snapshots", %{tt: tt} do
      for i <- 0..4 do
        TimeTravel.record(tt, {:msg, i}, %{v: i}, %{v: i + 1})
      end

      assert TimeTravel.count(tt) == 5

      TimeTravel.clear(tt)
      assert TimeTravel.count(tt) == 0
      assert {:error, :empty} = TimeTravel.current(tt)
    end
  end

  describe "restore/1" do
    test "returns error with no dispatcher", %{tt: tt} do
      TimeTravel.record(tt, :a, %{v: 0}, %{v: 1})
      assert {:error, :no_dispatcher} = TimeTravel.restore(tt)
    end

    test "returns error when empty" do
      # Need a dispatcher to get past the nil check
      dispatcher = spawn(fn -> Process.sleep(:infinity) end)

      tt =
        start_supervised!(
          {TimeTravel, dispatcher: dispatcher, max_snapshots: 100, name: nil},
          id: :empty_restore
        )

      assert {:error, :empty} = TimeTravel.restore(tt)
    end

    test "sends restore_model to dispatcher and pauses recording" do
      # Start a fake dispatcher that records messages
      test_pid = self()

      dispatcher =
        spawn(fn ->
          receive do
            {:"$gen_cast", {:restore_model, model}} ->
              send(test_pid, {:restored, model})
          end
        end)

      tt =
        start_supervised!(
          {TimeTravel, dispatcher: dispatcher, max_snapshots: 100, name: nil},
          id: :restore_test
        )

      TimeTravel.record(tt, :a, %{v: 0}, %{v: 1})
      TimeTravel.record(tt, :b, %{v: 1}, %{v: 2})

      # Step back to index 0
      {:ok, _} = TimeTravel.step_back(tt)

      assert :ok = TimeTravel.restore(tt)

      assert_receive {:restored, %{v: 1}}, 1000

      # Should be paused after restore
      TimeTravel.record(tt, :c, %{v: 2}, %{v: 3})
      assert TimeTravel.count(tt) == 2
    end
  end

  describe "export/2 and import_file/2" do
    test "round-trips snapshots through a file", %{tt: tt} do
      for i <- 0..2 do
        TimeTravel.record(tt, {:msg, i}, %{v: i}, %{v: i + 1})
      end

      path = Path.join(System.tmp_dir!(), "tt_export_test_#{:rand.uniform(100_000)}.bin")

      on_exit(fn -> File.rm(path) end)

      assert :ok = TimeTravel.export(tt, path)
      assert File.exists?(path)

      # Import into a fresh instance
      tt2 = start_supervised!({TimeTravel, max_snapshots: 100, name: nil}, id: :import_test)

      assert {:ok, 3} = TimeTravel.import_file(tt2, path)
      assert TimeTravel.count(tt2) == 3

      {:ok, snap} = TimeTravel.current(tt2)
      assert snap.index == 2
    end

    test "returns error for non-existent file", %{tt: tt} do
      assert {:error, :enoent} = TimeTravel.import_file(tt, "/tmp/nonexistent_tt_file.bin")
    end
  end

  describe "set_dispatcher" do
    test "wires up dispatcher after start" do
      test_pid = self()

      dispatcher =
        spawn(fn ->
          receive do
            {:"$gen_cast", {:restore_model, model}} ->
              send(test_pid, {:restored, model})
          end
        end)

      tt =
        start_supervised!(
          {TimeTravel, max_snapshots: 100, name: nil},
          id: :set_disp_test
        )

      # No dispatcher initially
      TimeTravel.record(tt, :a, %{v: 0}, %{v: 1})
      assert {:error, :no_dispatcher} = TimeTravel.restore(tt)

      # Wire it up
      GenServer.cast(tt, {:set_dispatcher, dispatcher})

      # Now restore should work
      assert :ok = TimeTravel.restore(tt)
      assert_receive {:restored, %{v: 1}}, 1000
    end
  end
end
