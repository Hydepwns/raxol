defmodule Raxol.Speech.SpeakerTest do
  use ExUnit.Case

  alias Raxol.Speech.{Speaker, TTS.Noop}

  setup do
    start_supervised!(Noop)
    start_supervised!({Speaker, tts_backend: Noop})
    Noop.clear()
    :ok
  end

  describe "speak/1" do
    test "speaks text via the configured backend" do
      assert :ok = Speaker.speak("Hello world")
      assert ["Hello world"] = Noop.get_spoken()
    end

    test "speaks multiple texts in order" do
      Speaker.speak("First")
      Speaker.speak("Second")
      assert ["Second", "First"] = Noop.get_spoken()
    end
  end

  describe "stop_speaking/0" do
    test "stops without error" do
      assert :ok = Speaker.stop_speaking()
    end
  end
end
