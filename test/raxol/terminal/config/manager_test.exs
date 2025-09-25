defmodule Raxol.Terminal.Config.ManagerTest do
  use ExUnit.Case
  alias Raxol.Terminal.Config.Manager

  describe "new/0" do
    test "creates a new config manager with default values" do
      config = Manager.new()
      assert config.width == 80
      assert config.height == 24
      assert config.colors == %{}
      assert config.styles == %{}
      assert config.input == %{}
      assert config.performance == %{}
      assert config.mode == %{}
    end
  end

  describe "get_setting/2" do
    test "returns nil for non-existent setting" do
      {:ok, config_pid} = Manager.start_link(width: 80, height: 24)
      emulator = %Raxol.Terminal.Emulator{config: config_pid}
      assert Manager.get_setting(emulator, :non_existent) == nil
    end

    test "returns setting value when it exists" do
      {:ok, config_pid} = Manager.start_link(width: 80, height: 24)
      emulator = %Raxol.Terminal.Emulator{config: config_pid}
      emulator = Manager.set_setting(emulator, :test_setting, "value")
      assert Manager.get_setting(emulator, :test_setting) == "value"
    end
  end

  describe "set_setting/3" do
    test "sets a new setting value" do
      {:ok, config_pid} = Manager.start_link(width: 80, height: 24)
      emulator = %Raxol.Terminal.Emulator{config: config_pid}
      emulator = Manager.set_setting(emulator, :test_setting, "value")
      assert Manager.get_setting(emulator, :test_setting) == "value"
    end

    test "updates existing setting value" do
      {:ok, config_pid} = Manager.start_link(width: 80, height: 24)
      emulator = %Raxol.Terminal.Emulator{config: config_pid}
      emulator = Manager.set_setting(emulator, :test_setting, "old")
      emulator = Manager.set_setting(emulator, :test_setting, "new")
      assert Manager.get_setting(emulator, :test_setting) == "new"
    end
  end

  describe "get_preference/2" do
    test "returns nil for non-existent preference" do
      {:ok, config_pid} = Manager.start_link(width: 80, height: 24)
      emulator = %Raxol.Terminal.Emulator{config: config_pid}
      assert Manager.get_preference(emulator, :non_existent) == nil
    end

    test "returns preference value when it exists" do
      {:ok, config_pid} = Manager.start_link(width: 80, height: 24)
      emulator = %Raxol.Terminal.Emulator{config: config_pid}
      emulator = Manager.set_preference(emulator, :test_pref, "value")
      assert Manager.get_preference(emulator, :test_pref) == "value"
    end
  end

  describe "set_preference/3" do
    test "sets a new preference value" do
      {:ok, config_pid} = Manager.start_link(width: 80, height: 24)
      emulator = %Raxol.Terminal.Emulator{config: config_pid}
      emulator = Manager.set_preference(emulator, :test_pref, "value")
      assert Manager.get_preference(emulator, :test_pref) == "value"
    end

    test "updates existing preference value" do
      {:ok, config_pid} = Manager.start_link(width: 80, height: 24)
      emulator = %Raxol.Terminal.Emulator{config: config_pid}
      emulator = Manager.set_preference(emulator, :test_pref, "old")
      emulator = Manager.set_preference(emulator, :test_pref, "new")
      assert Manager.get_preference(emulator, :test_pref) == "new"
    end
  end

  describe "get_environment/2" do
    test "returns nil for non-existent environment variable" do
      {:ok, config_pid} = Manager.start_link(width: 80, height: 24)
      emulator = %Raxol.Terminal.Emulator{config: config_pid}
      assert Manager.get_environment(emulator, "NON_EXISTENT") == nil
    end

    test "returns environment variable value when it exists" do
      {:ok, config_pid} = Manager.start_link(width: 80, height: 24)
      emulator = %Raxol.Terminal.Emulator{config: config_pid}
      emulator = Manager.set_environment(emulator, "TEST_VAR", "value")
      assert Manager.get_environment(emulator, "TEST_VAR") == "value"
    end
  end

  describe "set_environment/3" do
    test "sets a new environment variable" do
      {:ok, config_pid} = Manager.start_link(width: 80, height: 24)
      emulator = %Raxol.Terminal.Emulator{config: config_pid}
      emulator = Manager.set_environment(emulator, "TEST_VAR", "value")
      assert Manager.get_environment(emulator, "TEST_VAR") == "value"
    end

    test "updates existing environment variable" do
      {:ok, config_pid} = Manager.start_link(width: 80, height: 24)
      emulator = %Raxol.Terminal.Emulator{config: config_pid}
      emulator = Manager.set_environment(emulator, "TEST_VAR", "old")
      emulator = Manager.set_environment(emulator, "TEST_VAR", "new")
      assert Manager.get_environment(emulator, "TEST_VAR") == "new"
    end
  end

  describe "get_all_environment/1" do
    test "returns empty map initially" do
      {:ok, config_pid} = Manager.start_link(width: 80, height: 24)
      emulator = %Raxol.Terminal.Emulator{config: config_pid}
      assert Manager.get_all_environment(emulator) == %{}
    end

    test "returns all environment variables" do
      {:ok, config_pid} = Manager.start_link(width: 80, height: 24)
      emulator = %Raxol.Terminal.Emulator{config: config_pid}
      emulator = Manager.set_environment(emulator, "VAR1", "value1")
      emulator = Manager.set_environment(emulator, "VAR2", "value2")
      env = Manager.get_all_environment(emulator)
      assert env["VAR1"] == "value1"
      assert env["VAR2"] == "value2"
    end
  end

  describe "set_environment_variables/2" do
    test "sets multiple environment variables" do
      {:ok, config_pid} = Manager.start_link(width: 80, height: 24)
      emulator = %Raxol.Terminal.Emulator{config: config_pid}
      vars = %{"VAR1" => "value1", "VAR2" => "value2"}
      emulator = Manager.set_environment_variables(emulator, vars)
      assert Manager.get_environment(emulator, "VAR1") == "value1"
      assert Manager.get_environment(emulator, "VAR2") == "value2"
    end

    test "merges with existing environment variables" do
      {:ok, config_pid} = Manager.start_link(width: 80, height: 24)
      emulator = %Raxol.Terminal.Emulator{config: config_pid}
      emulator = Manager.set_environment(emulator, "VAR1", "old")
      vars = %{"VAR1" => "new", "VAR2" => "value2"}
      emulator = Manager.set_environment_variables(emulator, vars)
      assert Manager.get_environment(emulator, "VAR1") == "new"
      assert Manager.get_environment(emulator, "VAR2") == "value2"
    end
  end

  describe "clear_environment/1" do
    test "removes all environment variables" do
      {:ok, config_pid} = Manager.start_link(width: 80, height: 24)
      emulator = %Raxol.Terminal.Emulator{config: config_pid}
      emulator = Manager.set_environment(emulator, "VAR1", "value1")
      emulator = Manager.set_environment(emulator, "VAR2", "value2")
      emulator = Manager.clear_environment(emulator)
      assert Manager.get_all_environment(emulator) == %{}
    end
  end

  describe "reset_config_manager/1" do
    test "resets config manager to initial state" do
      {:ok, config_pid} = Manager.start_link(width: 80, height: 24)
      emulator = %Raxol.Terminal.Emulator{config: config_pid}
      emulator = Manager.set_setting(emulator, :test_setting, "value")
      emulator = Manager.set_preference(emulator, :test_pref, "value")
      emulator = Manager.set_environment(emulator, "TEST_VAR", "value")
      emulator = Manager.reset_config_manager(emulator)
      assert Manager.get_setting(emulator, :test_setting) == nil
      assert Manager.get_preference(emulator, :test_pref) == nil
      assert Manager.get_environment(emulator, "TEST_VAR") == nil
    end
  end
end
