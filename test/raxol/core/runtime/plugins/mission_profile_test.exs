defmodule Raxol.Core.Runtime.Plugins.MissionProfileTest do
  use ExUnit.Case, async: false

  alias Raxol.Core.Runtime.Plugins.{MissionProfile, Manifest}

  setup do
    MissionProfile.init()
    # Clean up ETS between tests
    :ets.delete_all_objects(:raxol_mission_profiles)
    :ok
  end

  defp profile(id, plugins, opts \\ []) do
    %MissionProfile{
      id: id,
      name: to_string(id),
      description: Keyword.get(opts, :description, ""),
      plugins: plugins,
      inherits: Keyword.get(opts, :inherits, nil)
    }
  end

  describe "register/1 and load/1" do
    test "registers and loads a profile" do
      p = profile(:recon, [{:scanner, %{range: 100}}])
      assert :ok = MissionProfile.register(p)
      assert {:ok, loaded} = MissionProfile.load(:recon)
      assert loaded.id == :recon
      assert loaded.plugins == [{:scanner, %{range: 100}}]
    end

    test "returns error for unknown profile" do
      assert {:error, :not_found} = MissionProfile.load(:nonexistent)
    end
  end

  describe "resolve_plugins/1" do
    test "returns plugins directly when no inheritance" do
      p = profile(:simple, [{:a, %{}}, {:b, %{}}])
      assert MissionProfile.resolve_plugins(p) == [{:a, %{}}, {:b, %{}}]
    end

    test "inherits parent plugins" do
      parent = profile(:base, [{:comms, %{channel: 1}}, {:nav, %{}}])
      MissionProfile.register(parent)

      child = profile(:assault, [{:weapons, %{}}], inherits: :base)

      resolved = MissionProfile.resolve_plugins(child)
      ids = Enum.map(resolved, fn {id, _} -> id end)
      assert :comms in ids
      assert :nav in ids
      assert :weapons in ids
    end

    test "child overrides parent plugin config" do
      parent = profile(:base, [{:comms, %{channel: 1}}, {:nav, %{}}])
      MissionProfile.register(parent)

      child =
        profile(:stealth, [{:comms, %{channel: 7, encrypted: true}}],
          inherits: :base
        )

      resolved = MissionProfile.resolve_plugins(child)

      comms_config =
        Enum.find_value(resolved, fn {id, c} -> if id == :comms, do: c end)

      assert comms_config == %{channel: 7, encrypted: true}
    end
  end

  describe "diff/2" do
    test "computes add/remove/reconfigure" do
      from =
        profile(:recon, [{:scanner, %{range: 100}}, {:comms, %{channel: 1}}])

      to =
        profile(:assault, [{:weapons, %{power: :max}}, {:comms, %{channel: 2}}])

      delta = MissionProfile.diff(from, to)
      assert :weapons in delta.add
      assert :scanner in delta.remove
      assert :comms in delta.reconfigure
    end

    test "identical profiles produce empty diff" do
      p = profile(:same, [{:a, %{x: 1}}])
      delta = MissionProfile.diff(p, p)
      assert delta.add == []
      assert delta.remove == []
      assert delta.reconfigure == []
    end
  end

  describe "activate/2" do
    test "returns error when manifest lookup fails" do
      p = profile(:bad, [{:nonexistent, %{}}])
      lookup = fn _id -> {:error, :not_found} end

      assert {:error, {:manifest_not_found, :nonexistent, :not_found}} =
               MissionProfile.activate(p, lookup)
    end

    test "returns error when dependency resolution fails" do
      p = profile(:conflict, [{:a, %{}}, {:b, %{}}])

      lookup = fn
        :a ->
          {:ok,
           %Manifest{
             id: :a,
             name: "A",
             version: "1.0.0",
             module: A,
             conflicts_with: [:b]
           }}

        :b ->
          {:ok, %Manifest{id: :b, name: "B", version: "1.0.0", module: B}}
      end

      assert {:error, {:conflict, :a, :b}} = MissionProfile.activate(p, lookup)
    end
  end
end
