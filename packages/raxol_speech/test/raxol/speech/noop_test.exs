defmodule Raxol.Speech.TTS.NoopTest do
  use ExUnit.Case

  alias Raxol.Speech.TTS.Noop

  setup do
    start_supervised!(Noop)
    Noop.clear()
    :ok
  end

  describe "speak/1" do
    test "records spoken text" do
      Noop.speak("Hello")
      Noop.speak("World")
      assert ["World", "Hello"] = Noop.get_spoken()
    end

    test "returns :ok" do
      assert :ok = Noop.speak("test")
    end
  end

  describe "stop/0" do
    test "returns :ok" do
      assert :ok = Noop.stop()
    end
  end

  describe "speaking?/0" do
    test "always returns false" do
      refute Noop.speaking?()
    end
  end

  describe "clear/0" do
    test "empties the spoken history" do
      Noop.speak("something")
      Noop.clear()
      assert [] = Noop.get_spoken()
    end
  end
end
