defmodule Raxol.Core.Accessibility.PreferencesTest do
  @moduledoc """
  Tests for the accessibility preferences system, including high contrast,
  reduced motion, large text, and feature flag management.
  """
  use ExUnit.Case, async: false
  import Mox

  alias Raxol.Core.Accessibility, as: Accessibility
  alias Raxol.Core.AccessibilityTestHelper, as: Helper
  alias Raxol.Core.UserPreferences

  setup :verify_on_exit!
  setup :set_mox_global

  setup do
    Raxol.Core.I18n.init()

    on_exit(fn ->
      Raxol.Core.I18n.cleanup()
    end)

    :ok
  end

  describe "set_high_contrast/1" do
    setup do
      prefs_name =
        String.to_atom(
          "user_prefs_high_contrast_" <>
            Integer.to_string(System.unique_integer([:positive]))
        )

      Helper.setup_test_preferences(prefs_name)
    end

    test "updates high contrast preference", %{prefs_name: prefs_name} do
      Accessibility.set_high_contrast(true, prefs_name)

      assert UserPreferences.get(Helper.pref_key(:high_contrast), prefs_name) ==
               true

      Accessibility.set_high_contrast(false, prefs_name)

      assert UserPreferences.get(Helper.pref_key(:high_contrast), prefs_name) ==
               false
    end
  end

  describe "set_reduced_motion/1" do
    setup do
      prefs_name =
        String.to_atom(
          "user_prefs_reduced_motion_" <>
            Integer.to_string(System.unique_integer([:positive]))
        )

      Helper.setup_test_preferences(prefs_name)
    end

    test "updates reduced motion preference", %{prefs_name: prefs_name} do
      Accessibility.set_reduced_motion(true, prefs_name)

      assert UserPreferences.get(Helper.pref_key(:reduced_motion), prefs_name) ==
               true

      Accessibility.set_reduced_motion(false, prefs_name)

      assert UserPreferences.get(Helper.pref_key(:reduced_motion), prefs_name) ==
               false
    end
  end

  describe "set_large_text/1" do
    setup do
      prefs_name =
        String.to_atom(
          "user_prefs_large_text_" <>
            Integer.to_string(System.unique_integer([:positive]))
        )

      Helper.setup_test_preferences(prefs_name)
    end

    test "updates large text preference and text scale", %{
      prefs_name: prefs_name
    } do
      initial_scale = Accessibility.get_text_scale(prefs_name)
      Accessibility.set_large_text(true, prefs_name)

      assert UserPreferences.get(Helper.pref_key(:large_text), prefs_name) ==
               true

      assert Accessibility.get_text_scale(prefs_name) > initial_scale

      Accessibility.set_large_text(false, prefs_name)

      assert UserPreferences.get(Helper.pref_key(:large_text), prefs_name) ==
               false

      assert Accessibility.get_text_scale(prefs_name) == initial_scale
    end
  end

  describe "get_text_scale/0" do
    setup do
      prefs_name =
        String.to_atom(
          "user_prefs_get_scale_" <>
            Integer.to_string(System.unique_integer([:positive]))
        )

      Helper.setup_test_preferences(prefs_name)
    end

    test "returns default text scale when large_text is false", %{
      prefs_name: prefs_name
    } do
      Raxol.Core.UserPreferences.set(
        Helper.pref_key(:large_text),
        false,
        prefs_name
      )

      assert_receive {:preferences_applied, ^prefs_name}, 1000

      Accessibility.set_large_text(false, prefs_name)
      assert_receive {:text_scale_updated, ^prefs_name, 1.0}, 1000

      assert Accessibility.get_text_scale(prefs_name) == 1.0
    end

    test "returns current text scale when large_text is true", %{
      prefs_name: prefs_name
    } do
      Raxol.Core.UserPreferences.set(
        Helper.pref_key(:large_text),
        true,
        prefs_name
      )

      assert_receive {:preferences_applied, ^prefs_name}, 1000

      Accessibility.set_large_text(true, prefs_name)

      assert_receive {:text_scale_updated, ^prefs_name, scale} when scale > 1.0,
                     1000

      assert Accessibility.get_text_scale(prefs_name) > 1.0
    end
  end

  describe "Feature Flags / Status Checks" do
    setup do
      prefs_name =
        String.to_atom(
          "user_prefs_feature_flags_" <>
            Integer.to_string(System.unique_integer([:positive]))
        )

      Helper.setup_test_preferences(prefs_name)
    end

    test "feature flags return false by default", %{prefs_name: prefs_name} do
      assert Accessibility.high_contrast_enabled?(prefs_name) == false
      assert Accessibility.reduced_motion_enabled?(prefs_name) == false
      assert Accessibility.large_text_enabled?(prefs_name) == false
    end

    test "feature flags return current settings when enabled", %{
      prefs_name: prefs_name
    } do
      Accessibility.set_high_contrast(true, prefs_name)
      Accessibility.set_reduced_motion(true, prefs_name)
      Accessibility.set_large_text(true, prefs_name)

      assert_receive {:preferences_applied, ^prefs_name}, 1000

      assert Accessibility.high_contrast_enabled?(prefs_name) == true
      assert Accessibility.reduced_motion_enabled?(prefs_name) == true
      assert Accessibility.large_text_enabled?(prefs_name) == true

      # Restore defaults
      Accessibility.set_high_contrast(false, prefs_name)
      Accessibility.set_reduced_motion(false, prefs_name)
      Accessibility.set_large_text(false, prefs_name)

      assert_receive {:preferences_applied, ^prefs_name}, 1000
    end
  end
end
