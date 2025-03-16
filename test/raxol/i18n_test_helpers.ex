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
  def assert_translation_exists(locale, key) when is_binary(locale) and is_binary(key) do
    assert I18n.has_translation?(locale, key), 
      "Expected translation key '#{key}' to exist for locale '#{locale}', but it doesn't"
  end
  
  @doc """
  Asserts that a translation matches the expected value for the given locale.
  
  ## Examples
  
      assert_translation("fr", "buttons.save", "Enregistrer")
  """
  def assert_translation(locale, key, expected) when is_binary(locale) and is_binary(key) do
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
  def with_locale_announcements(locale, fun) when is_binary(locale) and is_function(fun, 0) do
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
  def assert_accessibility_translations_complete(locale) when is_binary(locale) do
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
    
    missing_keys = Enum.filter(essential_keys, fn key -> 
      not I18n.has_translation?(locale, key)
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
      formatted = I18n.format_screen_reader_announcement(announcement_type, bindings)
      
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
  def assert_component_accessibility_labels(locale, component, label_types) do
    with_locale(locale, fn ->
      Enum.each(label_types, fn label_type ->
        label = Accessibility.get_component_label(component, label_type)
        refute is_nil(label), 
          "Component is missing '#{label_type}' accessibility label in locale '#{locale}'"
          
        # Verify the label is not in the default locale when a different locale is set
        default_locale = I18n.get_default_locale()
        if locale != default_locale do
          default_label = with_locale(default_locale, fn -> 
            Accessibility.get_component_label(component, label_type)
          end)
          
          refute label == default_label,
            "Component '#{label_type}' label was not translated from default locale"
        end
      end)
    end)
  end
  
  @doc """
  Tests that keyboard shortcuts are properly documented in the given locale.
  
  ## Examples
  
      assert_shortcut_documentation("fr", :save, "Ctrl+S", "Enregistrer le document")
  """
  def assert_shortcut_documentation(locale, shortcut_id, expected_key, expected_description) do
    with_locale(locale, fn ->
      {actual_key, actual_description} = Raxol.Core.KeyboardShortcuts.get_shortcut_documentation(shortcut_id)
      
      assert actual_key == expected_key,
        "Expected shortcut key for '#{shortcut_id}' to be '#{expected_key}' in locale '#{locale}', but got '#{actual_key}'"
        
      assert actual_description == expected_description,
        "Expected shortcut description for '#{shortcut_id}' to be '#{expected_description}' in locale '#{locale}', but got '#{actual_description}'"
    end)
  end
  
  @doc """
  Tests that locale-specific accessibility settings are properly applied.
  
  ## Examples
  
      assert_locale_accessibility_settings("ja", fn settings ->
        assert settings.font_size_adjustment == 1.2
      end)
  """
  def assert_locale_accessibility_settings(locale, assertion_fn) when is_function(assertion_fn, 1) do
    with_locale(locale, fn ->
      settings = I18n.get_locale_accessibility_settings()
      assertion_fn.(settings)
    end)
  end
end 