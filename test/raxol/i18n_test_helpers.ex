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

  alias Raxol.Core.I18n
  alias Raxol.Core.Accessibility

  @doc """
  Executes the given function with a specific locale set.

  The locale will be reset to the original value after the function completes.

  ## Examples

      with_locale("fr") do
        assert I18n.t("greeting") == "Bonjour"
      end
  """
  def with_locale(locale, fun) when is_binary(locale) and is_function(fun, 0) do
    original_locale = I18n.get_locale()

    try do
      I18n.set_locale(locale)
      fun.()
    after
      I18n.set_locale(original_locale)
    end
  end

  @doc """
  Asserts that a translation key exists for the given locale.

  ## Examples

      assert_translation_exists("fr", "buttons.save")
  """
  def assert_translation_exists(locale, key)
      when is_binary(locale) and is_binary(key) do
    # Use t/3 with the specific locale and check if it returns the key itself
    # We pass the key as the default to ensure it returns the key if not found
    translated = I18n.t(key, %{}, locale: locale, default: key)

    assert translated != key,
           "Expected translation key '#{key}' to exist for locale '#{locale}', but it doesn't"
  end

  @doc """
  Asserts that a translation matches the expected value for the given locale.

  ## Examples

      assert_translation("fr", "buttons.save", "Enregistrer")
  """
  def assert_translation(locale, key, expected)
      when is_binary(locale) and is_binary(key) do
    actual = I18n.t(key, %{}, locale)

    assert actual == expected,
           "Expected translation of '#{key}' in '#{locale}' to be '#{expected}', but got '#{actual}'"
  end

  @doc """
  Tests screen reader announcements in a specific locale.

  ## Examples

      with_locale_announcements("fr") do
        # Trigger action that should make announcement
        UserPreferences.set(:high_contrast, true)

        # Assert announcement in French
        assert_announced("Mode contraste élevé activé")
      end
  """
  def with_locale_announcements(locale, fun)
      when is_binary(locale) and is_function(fun, 0) do
    with_locale(locale, fn ->
      with_screen_reader_spy(fun)
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
    # Find first available RTL locale
    rtl_locale =
      I18n.available_locales()
      |> Enum.find(fn locale -> I18n.rtl?(locale) end)

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
    # List of essential accessibility-related translation keys
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
        # Use the same logic as assert_translation_exists
        translated = I18n.t(key, %{}, locale: locale, default: key)
        # If translation equals key, it's missing
        translated == key
      end)

    assert Enum.empty?(missing_keys),
           "Missing accessibility translations for locale '#{locale}': #{inspect(missing_keys)}"
  end

  @doc """
  Tests that screen reader announcements are properly formatted for the given locale.

  ## Examples

      assert_screen_reader_format("fr", "focus_moved", %{element: "bouton"})
  """
  def assert_screen_reader_format(locale, announcement_type, bindings \\ %{}) do
    with_locale(locale, fn ->
      key = "accessibility.screen_reader.#{announcement_type}"

      # Use I18n.t/3 to get the translated and formatted string
      formatted = I18n.t(key, bindings)

      # Verify the announcement is not just the key (which would indicate missing translation)
      refute formatted == key,
             "Screen reader announcement '#{announcement_type}' not properly formatted for locale '#{locale}'"

      # If there are bindings, verify they are applied
      if map_size(bindings) > 0 do
        Enum.each(bindings, fn {key, value} ->
          assert String.contains?(formatted, to_string(value)),
                 "Screen reader announcement doesn't contain binding value '#{value}' for key '#{key}'"
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
      # Get all metadata for the component once
      metadata = Accessibility.get_element_metadata(component_id) || %{}

      Enum.each(label_types, fn label_type ->
        # Fetch the specific label type from metadata
        label = Map.get(metadata, label_type)

        refute is_nil(label),
               "Component '#{component_id}' is missing '#{label_type}' accessibility label in locale '#{locale}'"

        # Verify the label is not in the default locale when a different locale is set
        # Use the suggested function name
        default_locale = I18n.get_locale()

        if locale != default_locale do
          default_label =
            with_locale(default_locale, fn ->
              # Fetch metadata and the specific label in the default locale
              default_metadata =
                Accessibility.get_element_metadata(component_id) || %{}

              Map.get(default_metadata, label_type)
            end)

          # Ensure the default label was found before comparing
          unless is_nil(default_label) do
            refute label == default_label,
                   "Component '#{component_id}' '#{label_type}' label ('#{label}') was not translated from default locale ('#{default_label}')"
          else
            # If default label is nil, we can't compare, but the translated label exists (checked above)
            # This might indicate an issue with the test setup or default translations
            Logger.debug(
              "Could not compare label for '#{component_id}' '#{label_type}' as default label was nil"
            )
          end
        end
      end)
    end)
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
      # Get all shortcuts for the current context (implicitly set by with_locale)
      all_shortcuts = Raxol.Core.KeyboardShortcuts.get_shortcuts_for_context()

      # Find the specific shortcut by its ID
      shortcut_data =
        Enum.find(all_shortcuts, fn s -> s.name == shortcut_id end)

      if shortcut_data do
        actual_key = shortcut_data.key_combo
        actual_description = shortcut_data.description

        assert actual_key == expected_key,
               "Expected shortcut key for '#{shortcut_id}' to be '#{expected_key}' in locale '#{locale}', but got '#{actual_key}'"

        assert actual_description == expected_description,
               "Expected shortcut description for '#{shortcut_id}' to be '#{expected_description}' in locale '#{locale}', but got '#{actual_description}'"
      else
        # Shortcut ID not found in the current context
        flunk(
          "Shortcut with ID '#{shortcut_id}' not found in current context for locale '#{locale}'"
        )
      end
    end)
  end

  # TODO: Commenting out this test helper as the underlying
  # I18n.get_locale_accessibility_settings/0 function is undefined.
  # Need to revisit how locale-specific accessibility settings are managed and tested.
  # @doc """
  # Tests that locale-specific accessibility settings are properly applied.
  #
  # ## Examples
  #
  #     assert_locale_accessibility_settings("ja", fn settings ->
  #       assert settings.font_size_adjustment == 1.2
  #     end)
  # """
  # def assert_locale_accessibility_settings(locale, assertion_fn)
  #     when is_function(assertion_fn, 1) do
  #   with_locale(locale, fn ->
  #     settings = I18n.get_locale_accessibility_settings()
  #     assertion_fn.(settings)
  #   end)
  # end
end
