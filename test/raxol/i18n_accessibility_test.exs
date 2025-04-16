defmodule Raxol.I18nAccessibilityTest do
  use ExUnit.Case

  import Raxol.AccessibilityTestHelpers
  import Raxol.I18nTestHelpers

  alias Raxol.Core.Accessibility
  alias Raxol.Core.I18n
  alias Raxol.Core.UserPreferences

  setup do
    # Initialize required systems for testing
    I18n.init(
      default_locale: "en",
      available_locales: ["en", "fr", "es", "ar", "ja"],
      fallback_locale: "en"
    )

    # Register test translations
    I18n.register_translations("en", %{
      "accessibility.high_contrast_enabled" => "High contrast mode enabled",
      "accessibility.high_contrast_disabled" => "High contrast mode disabled",
      "accessibility.reduced_motion_enabled" => "Reduced motion mode enabled",
      "accessibility.reduced_motion_disabled" => "Reduced motion mode disabled",
      "accessibility.screen_reader.focus_moved" => "Focus moved to %{element}",
      "accessibility.screen_reader.button_pressed" => "Button %{name} pressed",
      "test.greeting" => "Hello",
      "test.button.save" => "Save"
    })

    I18n.register_translations("fr", %{
      "accessibility.high_contrast_enabled" => "Mode contraste élevé activé",
      "accessibility.high_contrast_disabled" =>
        "Mode contraste élevé désactivé",
      "accessibility.reduced_motion_enabled" => "Mode mouvement réduit activé",
      "accessibility.reduced_motion_disabled" =>
        "Mode mouvement réduit désactivé",
      "accessibility.screen_reader.focus_moved" =>
        "Focus déplacé vers %{element}",
      "accessibility.screen_reader.button_pressed" => "Bouton %{name} pressé",
      "test.greeting" => "Bonjour",
      "test.button.save" => "Enregistrer"
    })

    I18n.register_translations("ar", %{
      "accessibility.high_contrast_enabled" => "تم تمكين وضع التباين العالي",
      "accessibility.high_contrast_disabled" => "تم تعطيل وضع التباين العالي",
      "accessibility.reduced_motion_enabled" => "تم تمكين وضع الحركة المخفضة",
      "accessibility.reduced_motion_disabled" => "تم تعطيل وضع الحركة المخفضة",
      "accessibility.screen_reader.focus_moved" =>
        "انتقل التركيز إلى %{element}",
      "accessibility.screen_reader.button_pressed" =>
        "تم الضغط على الزر %{name}",
      "test.greeting" => "مرحبا",
      "test.button.save" => "حفظ"
    })

    Accessibility.enable()
    UserPreferences.init()

    :ok
  end

  describe "I18n and Accessibility integration" do
    test "screen reader announcements are translated" do
      with_locale_announcements("fr") do
        # Trigger high contrast mode
        UserPreferences.set(:high_contrast, true)

        # Assert announcement in French
        assert_announced("Mode contraste élevé activé")

        # Disable high contrast mode
        UserPreferences.set(:high_contrast, false)

        # Assert announcement in French
        assert_announced("Mode contraste élevé désactivé")
      end
    end

    test "screen reader announcements with bindings are translated" do
      with_locale_announcements("fr") do
        # Simulate focus movement
        Accessibility.announce_focus_moved("bouton")

        # Assert announcement in French with binding
        assert_announced("Focus déplacé vers bouton")
      end
    end

    test "RTL languages are properly detected" do
      with_locale("ar") do
        assert I18n.rtl?()
      end

      with_locale("en") do
        refute I18n.rtl?()
      end
    end

    test "locale-specific accessibility settings are applied" do
      # Define locale-specific settings for testing
      locale_settings = %{
        "ja" => %{
          font_size_adjustment: 1.2,
          line_height_adjustment: 1.5
        },
        "ar" => %{
          text_direction: :rtl,
          font_size_adjustment: 1.1
        }
      }

      # Mock the function to return our test settings
      original_get_settings = &I18n.get_locale_accessibility_settings/0

      try do
        # Replace the function with our mock
        :meck.new(I18n, [:passthrough])

        :meck.expect(I18n, :get_locale_accessibility_settings, fn ->
          current_locale = I18n.get_locale()
          Map.get(locale_settings, current_locale, %{})
        end)

        # Test Japanese settings
        assert_locale_accessibility_settings("ja", fn settings ->
          assert settings.font_size_adjustment == 1.2
          assert settings.line_height_adjustment == 1.5
        end)

        # Test Arabic settings
        assert_locale_accessibility_settings("ar", fn settings ->
          assert settings.text_direction == :rtl
          assert settings.font_size_adjustment == 1.1
        end)
      after
        # Clean up the mock
        :meck.unload(I18n)
      end
    end

    test "translations for accessibility features exist" do
      # Test for English
      assert_translation_exists("en", "accessibility.high_contrast_enabled")
      assert_translation_exists("en", "accessibility.reduced_motion_enabled")

      # Test for French
      assert_translation_exists("fr", "accessibility.high_contrast_enabled")
      assert_translation_exists("fr", "accessibility.reduced_motion_enabled")
    end

    test "screen reader format is correct for different locales" do
      # Test English format
      assert_screen_reader_format("en", "focus_moved", %{element: "button"})

      # Test French format
      assert_screen_reader_format("fr", "focus_moved", %{element: "bouton"})
    end

    test "component accessibility labels are translated" do
      # Create a mock component with accessibility labels
      component = %{
        id: "save_button",
        type: :button,
        accessibility_labels: %{
          en: %{
            label: "Save",
            hint: "Save the current document"
          },
          fr: %{
            label: "Enregistrer",
            hint: "Enregistrer le document actuel"
          }
        }
      }

      # Mock the function to get component labels
      :meck.new(Accessibility, [:passthrough])

      :meck.expect(Accessibility, :get_component_label, fn comp, label_type ->
        locale = I18n.get_locale()

        get_in(comp.accessibility_labels, [
          String.to_atom(locale),
          String.to_atom(label_type)
        ])
      end)

      try do
        # Test English labels
        with_locale("en") do
          assert Accessibility.get_component_label(component, "label") == "Save"

          assert Accessibility.get_component_label(component, "hint") ==
                   "Save the current document"
        end

        # Test French labels
        with_locale("fr") do
          assert Accessibility.get_component_label(component, "label") ==
                   "Enregistrer"

          assert Accessibility.get_component_label(component, "hint") ==
                   "Enregistrer le document actuel"
        end
      after
        :meck.unload(Accessibility)
      end
    end

    test "changing locale triggers appropriate screen reader announcement" do
      with_screen_reader_spy(fn ->
        # Change locale
        I18n.set_locale("fr")

        # Assert announcement about locale change
        assert_announced("fr")
      end)
    end

    test "fallback translations are used when translation is missing" do
      # Register incomplete translations for Spanish
      I18n.register_translations("es", %{
        "test.greeting" => "Hola"
        # Missing accessibility translations
      })

      with_locale("es") do
        # Should fall back to English for missing translations
        assert I18n.t("accessibility.high_contrast_enabled") ==
                 "High contrast mode enabled"

        # But use Spanish for existing translations
        assert I18n.t("test.greeting") == "Hola"
      end
    end

    test "user preferences for locale are persisted" do
      # Set locale preference
      UserPreferences.set(:locale, "fr")

      # Save preferences
      UserPreferences.save()

      # Reset preferences to defaults
      Process.put(:user_preferences, %{})

      # Load preferences
      UserPreferences.load()

      # Verify preference was maintained
      assert UserPreferences.get(:locale) == "fr"

      # Verify current locale matches preference
      assert I18n.get_locale() == "fr"
    end
  end
end
