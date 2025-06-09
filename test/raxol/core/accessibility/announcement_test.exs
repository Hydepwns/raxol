defmodule Raxol.Core.Accessibility.AnnouncementTest do
  use Raxol.DataCase, async: false
  import Mox

  alias Raxol.Core.Accessibility
  alias Raxol.Core.AccessibilityTestHelper, as: Helper

  setup :verify_on_exit!
  setup :set_mox_global

  setup do
    Raxol.Core.I18n.init()
    :ok
  end

  describe "announce/2 related functions" do
    setup do
      prefs_name =
        String.to_atom(
          "user_prefs_announce_" <>
            Integer.to_string(System.unique_integer([:positive]))
        )

      Helper.setup_test_preferences_with_events(prefs_name)
    end

    test "announce/2 adds announcement to queue", %{prefs_name: prefs_name} do
      ref = make_ref()
      :ok = Accessibility.subscribe_to_announcements(ref)

      Accessibility.announce("Test announcement", [], prefs_name)
      assert_receive {:announcement_added, ^ref, "Test announcement"}, 1000

      :ok = Accessibility.unsubscribe_from_announcements(ref)
    end

    test "get_next_announcement/0 retrieves and removes announcement", %{
      prefs_name: prefs_name
    } do
      ref = make_ref()
      :ok = Accessibility.subscribe_to_announcements(ref)

      Accessibility.announce("First", [], prefs_name)
      Accessibility.announce("Second", [], prefs_name)

      assert_receive {:announcement_added, ^ref, "First"}, 1000
      assert_receive {:announcement_added, ^ref, "Second"}, 1000

      assert Accessibility.get_next_announcement() == "First"
      assert Accessibility.get_next_announcement() == "Second"
      assert Accessibility.get_next_announcement() == nil

      :ok = Accessibility.unsubscribe_from_announcements(ref)
    end

    test "clear_announcements/0 clears the queue", %{prefs_name: prefs_name} do
      ref = make_ref()
      :ok = Accessibility.subscribe_to_announcements(ref)

      Accessibility.announce("Test", [], prefs_name)
      assert_receive {:announcement_added, ^ref, "Test"}, 1000

      Accessibility.clear_announcements()
      assert_receive {:announcements_cleared, ^ref}, 1000

      assert Accessibility.get_next_announcement() == nil

      :ok = Accessibility.unsubscribe_from_announcements(ref)
    end

    test "announce/2 does nothing when screen reader is disabled", %{
      prefs_name: prefs_name
    } do
      ref = make_ref()
      :ok = Accessibility.subscribe_to_announcements(ref)

      Raxol.Core.UserPreferences.set(
        Helper.pref_key(:screen_reader),
        false,
        prefs_name
      )

      Accessibility.announce("Should not be announced", [], prefs_name)

      refute_receive {:announcement_added, ^ref, _}, 1000
      assert Accessibility.get_next_announcement() == nil

      :ok = Accessibility.unsubscribe_from_announcements(ref)
    end

    test "announce/2 handles priority and interrupt options", %{
      prefs_name: prefs_name
    } do
      Accessibility.announce("Normal", [], prefs_name)
      Accessibility.announce("High", [priority: :high], prefs_name)
      Accessibility.announce("Low", [priority: :low], prefs_name)
      assert Accessibility.get_next_announcement() == "High"
      Accessibility.announce("Interrupting", [interrupt: true], prefs_name)
      assert Accessibility.get_next_announcement() == "Interrupting"
      assert Accessibility.get_next_announcement() == nil
    end

    test "announce/2 respects :silence_announcements setting", %{
      prefs_name: prefs_name
    } do
      Raxol.Core.UserPreferences.set(
        Helper.pref_key(:silence_announcements),
        true,
        prefs_name
      )

      Accessibility.announce("Should not be announced", [], prefs_name)
      assert Accessibility.get_next_announcement() == nil
    end
  end
end

ExUnit.start()
Code.require_file("../accessibility_test_helper.exs", __DIR__)
