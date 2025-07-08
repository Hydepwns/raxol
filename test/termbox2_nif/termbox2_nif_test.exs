@skip_termbox2_tests !Raxol.Terminal.TerminalUtils.real_tty?()

if @skip_termbox2_tests do
  defmodule Termbox2NifTest do
    use ExUnit.Case
    @tag :skip
    test "termbox2_nif tests are skipped (not in a TTY environment)" do
      assert true
    end
  end
else
  defmodule Termbox2NifTest do
    @moduledoc """
    Tests for the termbox2_nif module, verifying terminal UI functionality and error handling.
    """
    use ExUnit.Case
    alias :termbox2_nif, as: Termbox2Nif

    describe "initialization and shutdown" do
      test "initializes and shuts down cleanly" do
        assert Termbox2Nif.tb_init() == 0
        assert Termbox2Nif.tb_shutdown() == :ok
      end

      test "handles multiple init/shutdown cycles" do
        assert Termbox2Nif.tb_init() == 0
        assert Termbox2Nif.tb_shutdown() == :ok
        assert Termbox2Nif.tb_init() == 0
        assert Termbox2Nif.tb_shutdown() == :ok
      end
    end

    describe "terminal dimensions" do
      setup do
        assert Termbox2Nif.tb_init() == 0
        on_exit(fn -> assert Termbox2Nif.tb_shutdown() == :ok end)
        :ok
      end

      test "gets valid terminal dimensions" do
        width = Termbox2Nif.tb_width()
        height = Termbox2Nif.tb_height()
        assert is_integer(width) and width > 0
        assert is_integer(height) and height > 0
      end
    end

    describe "terminal operations" do
      setup do
        assert Termbox2Nif.tb_init() == 0
        on_exit(fn -> assert Termbox2Nif.tb_shutdown() == :ok end)
        :ok
      end

      test "clears the terminal" do
        assert Termbox2Nif.tb_clear() == :ok
      end

      test "sets and presents cells" do
        assert Termbox2Nif.tb_clear() == :ok
        assert Termbox2Nif.tb_set_cell(0, 0, ?A, 7, 0) == 0
        assert Termbox2Nif.tb_present() == :ok
      end

      test "handles cursor operations" do
        assert Termbox2Nif.tb_hide_cursor() == 0
        assert Termbox2Nif.tb_set_cursor(10, 10) == :ok
      end

      test "prints text" do
        assert Termbox2Nif.tb_clear() == :ok
        assert Termbox2Nif.tb_print(0, 0, 7, 0, "Test") == 0
        assert Termbox2Nif.tb_present() == :ok
      end
    end

    describe "terminal configuration" do
      setup do
        assert Termbox2Nif.tb_init() == 0
        on_exit(fn -> assert Termbox2Nif.tb_shutdown() == :ok end)
        :ok
      end

      test "sets terminal title" do
        assert {:ok, "set"} = Termbox2Nif.tb_set_title("Test Title")
      end

      test "sets terminal position" do
        assert {:ok, "set"} = Termbox2Nif.tb_set_position(100, 100)
      end

      test "sets input mode" do
        assert is_integer(Termbox2Nif.tb_set_input_mode(0))
      end

      test "sets output mode" do
        assert is_integer(Termbox2Nif.tb_set_output_mode(0))
      end
    end

    describe "error handling" do
      setup do
        assert Termbox2Nif.tb_init() == 0
        on_exit(fn -> assert Termbox2Nif.tb_shutdown() == :ok end)
        :ok
      end

      test "handles invalid cell coordinates" do
        assert Termbox2Nif.tb_set_cell(-1, -1, ?A, 7, 0) == -1
        width = Termbox2Nif.tb_width()
        height = Termbox2Nif.tb_height()
        assert Termbox2Nif.tb_set_cell(width + 1, height + 1, ?A, 7, 0) == -1
      end

      test "handles invalid cursor position" do
        assert Termbox2Nif.tb_set_cursor(-1, -1) == :ok
        width = Termbox2Nif.tb_width()
        height = Termbox2Nif.tb_height()
        assert Termbox2Nif.tb_set_cursor(width + 1, height + 1) == :ok
      end
    end
  end
end
