defmodule Raxol.Core.Accessibility.EnableDisableTest do
  @moduledoc """
  Tests for the accessibility enable/disable functionality, including
  preference application, announcement handling, and state management.
  """
  use ExUnit.Case, async: false
  import Mox

  alias Raxol.Core.Accessibility
  alias Raxol.Core.AccessibilityTestHelper, as: Helper
  alias Raxol.Core.UserPreferences

  setup :verify_on_exit!
  setup :set_mox_global

  setup do
    Raxol.Core.I18n.init()
    :ok
  end

  describe "enable/1 and disable/0" do
    setup do
      prefs_name =
        String.to_atom(
          "user_prefs_enable_disable_" <>
            Integer.to_string(System.unique_integer([:positive]))
        )

      {:ok, context} = Helper.setup_test_preferences(prefs_name)
      context
    end

    test "enable/1 applies default preferences if none are set", %{
      prefs_name: prefs_name
    } do
      # Set prefs to nil initially
      Raxol.Core.UserPreferences.set(
        Helper.pref_key(:high_contrast),
        nil,
        prefs_name
      )

      Raxol.Core.UserPreferences.set(
        Helper.pref_key(:reduced_motion),
        nil,
        prefs_name
      )

      Raxol.Core.UserPreferences.set(
        Helper.pref_key(:large_text),
        nil,
        prefs_name
      )

      # Disable first to clear handlers etc.
      Accessibility.disable(prefs_name)

      Helper.wait_for_state(fn ->
        Accessibility.get_option(:enabled, prefs_name, false) == false
      end)

      # Enable reads preferences
      Accessibility.enable([], prefs_name)

      Helper.wait_for_state(fn ->
        Accessibility.get_option(:enabled, prefs_name, false) == true
      end)

      # Assert default values
      assert Raxol.Core.UserPreferences.get(
               Helper.pref_key(:high_contrast),
               prefs_name
             ) ==
               false

      assert Raxol.Core.UserPreferences.get(
               Helper.pref_key(:reduced_motion),
               prefs_name
             ) ==
               false

      assert Raxol.Core.UserPreferences.get(
               Helper.pref_key(:large_text),
               prefs_name
             ) ==
               false

      assert Raxol.Core.UserPreferences.get(
               Helper.pref_key(:screen_reader),
               prefs_name
             ) ==
               true

      assert Accessibility.get_text_scale(prefs_name) == 1.0
    end

    test "enable/1 applies custom options over defaults", %{
      prefs_name: prefs_name
    } do
      # Set prefs to nil initially
      Raxol.Core.UserPreferences.set(
        Helper.pref_key(:high_contrast),
        nil,
        prefs_name
      )

      Raxol.Core.UserPreferences.set(
        Helper.pref_key(:reduced_motion),
        nil,
        prefs_name
      )

      Raxol.Core.UserPreferences.set(
        Helper.pref_key(:screen_reader),
        nil,
        prefs_name
      )

      Accessibility.disable(prefs_name)

      Helper.wait_for_state(fn ->
        Accessibility.get_option(:enabled, prefs_name, false) == false
      end)

      custom_opts = [
        high_contrast: true,
        reduced_motion: true,
        screen_reader: false
      ]

      Accessibility.enable(custom_opts, prefs_name)

      Helper.wait_for_state(fn ->
        Accessibility.get_option(:enabled, prefs_name, false) == true
      end)

      assert Accessibility.get_option(:high_contrast, prefs_name, false) == true

      assert Accessibility.get_option(:reduced_motion, prefs_name, false) ==
               true

      assert Accessibility.get_option(:screen_reader, prefs_name, true) == false
      assert Accessibility.get_text_scale(prefs_name) == 1.0
    end

    test "disable/0 stops functionality", %{
      prefs_name: prefs_name
    } do
      Accessibility.enable([], prefs_name)

      Helper.wait_for_state(fn ->
        Accessibility.get_option(:enabled, prefs_name, false) == true
      end)

      assert Accessibility.get_option(:enabled, prefs_name, false) == true
      Accessibility.announce("Test before disable", [], prefs_name)

      assert Accessibility.get_next_announcement(prefs_name) ==
               "Test before disable"

      Accessibility.disable(prefs_name)

      Helper.wait_for_state(fn ->
        Accessibility.get_option(:enabled, prefs_name, false) == false
      end)

      Accessibility.announce("Test after disable", [], prefs_name)
      assert Accessibility.get_next_announcement(prefs_name) == nil
    end
  end
end

ExUnit.start()
Code.require_file("../accessibility_test_helper.exs", __DIR__)
