defmodule Raxol.Speech.RecognizerTest do
  use ExUnit.Case

  alias Raxol.Speech.Recognizer

  setup do
    start_supervised!(Recognizer)
    :ok
  end

  describe "recognize/1" do
    test "returns an error tuple for invalid audio input" do
      # Whether Bumblebee is available or not, fake data should error
      assert {:error, _reason} = Recognizer.recognize("fake audio data")
    end
  end

  describe "available?/0" do
    test "returns a boolean" do
      result = Recognizer.available?()
      assert is_boolean(result)
    end
  end
end
