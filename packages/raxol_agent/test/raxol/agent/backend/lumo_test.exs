defmodule Raxol.Agent.Backend.LumoTest do
  use ExUnit.Case, async: true

  alias Raxol.Agent.Backend.Lumo

  @env_keys ~w(PROTON_UID PROTON_ACCESS_TOKEN LUMO_TAMER_URL)

  setup do
    originals = Map.new(@env_keys, fn key -> {key, System.get_env(key)} end)

    on_exit(fn ->
      Enum.each(originals, fn
        {key, nil} -> System.delete_env(key)
        {key, val} -> System.put_env(key, val)
      end)
    end)

    {:ok, originals: originals}
  end

  describe "name/0" do
    test "returns Proton Lumo" do
      assert Lumo.name() == "Proton Lumo"
    end
  end

  describe "capabilities/0" do
    test "supports completion and streaming" do
      assert :completion in Lumo.capabilities()
      assert :streaming in Lumo.capabilities()
    end
  end

  describe "available?/0" do
    test "returns false without credentials or tamer URL" do
      Enum.each(@env_keys, &System.delete_env/1)

      refute Lumo.available?()
    end
  end

  describe "complete/2 without credentials" do
    test "returns error when no credentials set" do
      Enum.each(@env_keys, &System.delete_env/1)

      messages = [%{role: :user, content: "hello"}]
      assert {:error, :missing_credentials} = Lumo.complete(messages)
    end
  end

  describe "stream/2 without credentials" do
    test "returns error when no credentials set" do
      Enum.each(@env_keys, &System.delete_env/1)

      messages = [%{role: :user, content: "hello"}]
      assert {:error, :missing_credentials} = Lumo.stream(messages)
    end
  end
end
