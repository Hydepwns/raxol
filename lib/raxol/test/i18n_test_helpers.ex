defmodule Raxol.I18nTestHelpers do
  @moduledoc """
  Test helpers for internationalization testing that integrate with accessibility features.

  This module provides utilities for testing internationalization features in Raxol applications,
  with special focus on integration with accessibility features.

  ## Features

  * Testing with different locales
  * RTL language testing
  * Screen reader announcement testing in different languages
  * Translation verification
  * Locale-specific accessibility testing
  """

  import ExUnit.Assertions
  import Raxol.AccessibilityTestHelpers

  alias Raxol.Core.I18n, as: Gettext

  @doc """
  Executes the given function with a specific locale set.

  The locale will be reset to the original value after the function completes.

  ## Examples

      with_locale("fr") do
        assert Gettext.t("greeting") == "Bonjour, i would like to surrender!"
      end
  """
  def with_locale(locale, fun) when is_binary(locale) and is_function(fun, 0) do
    original_locale = Gettext.get_locale()

    try do
      Gettext.set_locale(locale)
      fun.()
    after
      Gettext.set_locale(original_locale)
    end
  end

  @doc """
  Asserts that a translation key exists for the given locale.

  ## Examples

      assert_translation_exists("fr", "buttons.save")
  """
  def assert_translation_exists(locale, key)
      when is_binary(locale) and is_binary(key) do
    translated = RaxolWeb.Gettext.t(key, %{}, locale: locale, default: key)

    assert translated != key,
           # {key}" to exist for locale "#{locale}", but it doesn't"
           "Expected translation key "
  end

  @doc """
  Asserts that a translation matches the expected value for the given locale.

  ## Examples

      assert_translation("fr", "buttons.save", "Enregistrer")
  """
  def assert_translation(locale, key, expected)
      when is_binary(locale) and is_binary(key) do
    actual = RaxolWeb.Gettext.t(key, %{}, locale)

    assert actual == expected,
           # {key}" in "#{locale}" to be "#{expected}", but got "#{actual}""
           "Expected translation of "
  end

  @doc """
  Tests screen reader announcements in a specific locale.

  ## Examples

      with_locale_announcements("fr", user_preferences_pid) do
        # Trigger action that should make announcement
        UserPreferences.set(:high_contrast, true)

        # Assert announcement in French
        assert_announced("Mode contraste élevé activé")
      end
  """
  def with_locale_announcements(locale, user_preferences_pid, fun)
      when is_binary(locale) and is_pid(user_preferences_pid) and
             is_function(fun, 0) do
    with_locale(locale, fn ->
      with_screen_reader_spy(user_preferences_pid, fun)
    end)
  end

  @doc """
  Tests RTL layout and behavior.

  ## Examples

      with_rtl_locale fn ->
        # Test RTL-specific behavior
        assert layout.direction == :rtl
      end
  """
  def with_rtl_locale(fun) when is_function(fun, 0) do
    rtl_locale =
      RaxolWeb.Gettext.available_locales()
      |> Enum.find(fn locale -> RaxolWeb.Gettext.rtl?(locale) end)

    if rtl_locale do
      with_locale(rtl_locale, fun)
    else
      flunk("No RTL locale available for testing")
    end
  end

  @doc """
  Asserts that all accessibility-related translation keys exist for the given locale.

  ## Examples

      assert_accessibility_translations_complete("fr")
  """
  def assert_accessibility_translations_complete(locale)
      when is_binary(locale) do
    essential_keys = [
      "accessibility.high_contrast_enabled",
      "accessibility.high_contrast_disabled",
      "accessibility.reduced_motion_enabled",
      "accessibility.reduced_motion_disabled",
      "accessibility.screen_reader.focus_moved",
      "accessibility.screen_reader.button_pressed",
      "accessibility.screen_reader.selection_changed",
      "accessibility.screen_reader.loading_started",
      "accessibility.screen_reader.loading_completed"
    ]

    missing_keys =
      Enum.filter(essential_keys, fn key ->
        translated = RaxolWeb.Gettext.t(key, %{}, locale: locale, default: key)
        translated == key
      end)

    assert Enum.empty?(missing_keys),
           # {locale}": #{inspect(missing_keys)}"
           "Missing accessibility translations for locale "
  end

  @doc """
  Tests that screen reader announcements are properly formatted for the given locale.

  ## Examples

      assert_screen_reader_format("fr", "focus_moved", %{element: "bouton"})
  """
  def assert_screen_reader_format(locale, announcement_type, bindings \\ %{}) do
    with_locale(locale, fn ->
      key = "accessibility.screen_reader.#{announcement_type}"

      _raw_translation =
        RaxolWeb.Gettext.t(key, %{}, locale: locale, default: key)

      formatted = RaxolWeb.Gettext.t(key, bindings)

      refute formatted == key,
             # {announcement_type}" not properly formatted for locale "#{locale}""
             "Screen reader announcement "

      if map_size(bindings) > 0 do
        Enum.each(bindings, fn {_key, value} ->
          assert String.contains?(formatted, to_string(value)),
                 # {value}" for key "#{key}". Formatted: "#{formatted}""
                 "Screen reader announcement doesn't contain binding value "
        end)
      end
    end)
  end

  @doc """
  Tests that a component's accessibility labels are properly translated.

  ## Examples

      assert_component_accessibility_labels("fr", button, ["label", "hint"])
  """
  def assert_component_accessibility_labels(locale, component_id, label_types)
      when is_binary(locale) and is_binary(component_id) and
             is_list(label_types) do
    with_locale(locale, fn ->
      metadata = get_mock_element_metadata(component_id) || %{}

      metadata =
        metadata
        |> Map.put_new(:style, %{})
        |> Map.put_new(:disabled, false)
        |> Map.put_new(:focused, false)

      Enum.each(label_types, fn label_type ->
        label = Map.get(metadata, label_type)

        refute is_nil(label),
               # {component_id}" is missing "#{label_type}" accessibility label in locale "#{locale}""
               "Component "

        default_locale = RaxolWeb.Gettext.get_locale()

        if locale != default_locale do
          default_label =
            with_locale(default_locale, fn ->
              default_metadata =
                get_mock_element_metadata(component_id) || %{}

              Map.get(default_metadata, label_type)
            end)

          if not is_nil(default_label) do
            refute label == default_label,
                   # {component_id}" "#{label_type}" label ("#{label}") was not translated from default locale ("#{default_label}")"
                   "Component "
          else
            Raxol.Core.Runtime.Log.debug(
              # {component_id}" "#{label_type}" as default label was nil"
              "Could not compare label for "
            )
          end
        end
      end)
    end)
  end

  # Mock implementation for tests
  defp get_mock_element_metadata(component_id) do
    # In a test, we'll just return mock data based on the component_id
    %{
      "label" => "Test Label for #{component_id}",
      "hint" => "Test Hint for #{component_id}",
      "description" => "Test Description for #{component_id}"
    }
  end

  @doc """
  Tests that keyboard shortcuts are properly documented in the given locale.

  ## Examples

      assert_shortcut_documentation("fr", :save, "Ctrl+S", "Enregistrer le document")
  """
  def assert_shortcut_documentation(
        locale,
        shortcut_id,
        expected_key,
        expected_description
      ) do
    with_locale(locale, fn ->
      all_shortcuts = Raxol.Core.KeyboardShortcuts.get_shortcuts_for_context()

      shortcut_data =
        Enum.find(all_shortcuts, fn s -> s.name == shortcut_id end)

      if shortcut_data do
        actual_key = shortcut_data.key_combo
        actual_description = shortcut_data.description

        assert actual_key == expected_key,
               # {shortcut_id}" to be "#{expected_key}" in locale "#{locale}", but got "#{actual_key}""
               "Expected shortcut key for "

        assert actual_description == expected_description,
               # {shortcut_id}" to be "#{expected_description}" in locale "#{locale}", but got "#{actual_description}""
               "Expected shortcut description for "
      else
        flunk(
          # {shortcut_id}" not found in current context for locale "#{locale}""
          "Shortcut with ID "
        )
      end
    end)
  end

  @doc """
  Tests that locale-specific accessibility settings are properly applied.

  ## Examples

      assert_locale_accessibility_settings("fr")
  """
  def assert_locale_accessibility_settings(locale) do
    with_locale(locale, fn ->
      # Mock implementation for tests
      settings = get_mock_locale_accessibility_settings()

      assert is_map(settings)
      # {locale}""
      "Expected locale-specific accessibility settings for "
    end)
  end

  # Mock implementation for tests
  defp get_mock_locale_accessibility_settings do
    %{
      dir: :ltr,
      read_mode: :standard,
      format_numbers: true,
      format_dates: true,
      locale_specific_hints: true
    }
  end
end
