defmodule SearchableSelect.SearchableSelectTest do
  use ExUnit.Case, async: true
  import Plug.Test

  import Phoenix.LiveViewTest
  @endpoint SearchableSelect.Endpoint

  setup :load_test_view

  test "renders all options below limit on load", %{live: live} do
    Enum.each(1..4, fn i -> assert has_element?(live, "#multi-option-#{i}") end)
    Enum.each(1..4, fn i -> assert has_element?(live, "#single-option-#{i}") end)
    Enum.each(1..2, fn i -> assert has_element?(live, "#single_limited-option-#{i}") end)
    Enum.each(3..4, fn i -> refute has_element?(live, "#single_limited-option-#{i}") end)
    Enum.each(1..4, fn i -> assert has_element?(live, "#single_unlimited-option-#{i}") end)
    Enum.each(1..4, fn i -> assert has_element?(live, "#dropdown-option-#{i}") end)

    live |> element("#single_limited-remove-limit-option") |> render_click()
    Enum.each(1..4, fn i -> assert has_element?(live, "#single_limited-option-#{i}") end)
  end

  test "removed limit survives a parent re-render", %{live: live} do
    live |> element("#single_limited-remove-limit-option") |> render_click()
    assert has_element?(live, "#single_limited-option-4")

    send(
      live.pid,
      {:change_options,
       [
         %{id: 1, name: "Ayy"},
         %{id: 2, name: "Bar"},
         %{id: 3, name: "Foo"},
         %{id: 4, name: "Lmao"}
       ]}
    )

    assert has_element?(live, "#single_limited-option-4")
  end

  test "renders accessible dropdown controls", %{live: live} do
    assert has_element?(live, "#single-search[aria-haspopup=listbox]")
    assert has_element?(live, "#single-search[aria-controls=single-dropdown]")
    assert has_element?(live, "#single-option-1[type=button]")
    assert has_element?(live, "#single-caret[type=button]")
    assert has_element?(live, "#single-caret svg.h-full.w-full")
    assert has_element?(live, "#single_preselected-pop-cross-4 svg.h-full.w-full")
  end

  test "ignores stale events for select and pop branches", %{live: live} do
    live |> element("#single-option-1") |> render_click(%{"key" => "missing"})
    live |> element("#dropdown-option-1") |> render_click(%{"key" => "missing"})

    live |> element("#single-option-1") |> render_click()
    live |> element("#single-pop-cross-1") |> render_click(%{"key" => "missing"})

    assert has_element?(live, "#single-pop-cross-1")
  end

  test "ignores stale select events without changing the socket" do
    socket = %Phoenix.LiveView.Socket{
      assigns: %{keyed_options: [], selected: [], multiple: false}
    }

    assert {:noreply, ^socket} =
             SearchableSelect.handle_event("select", %{"key" => "missing"}, socket)
  end

  test "a crafted select event cannot select an option that is already selected", %{live: live} do
    live |> element("#multi-option-1") |> render_click()
    live |> element("#multi-option-2") |> render_click(%{"key" => "ayy 1"})

    assert live |> element("#selected-options") |> render() ==
             "<span id=\"selected-options\">[1]</span>"
  end

  test "search filters items in dropdown", %{live: live} do
    live |> element("#multi-search") |> render_keyup(%{"value" => " ayy  "})
    assert has_element?(live, "#multi-option-1")
    Enum.each(2..4, fn i -> refute has_element?(live, "#multi-option-#{i}") end)

    live |> element("#single-search") |> render_keyup(%{"value" => "LmAO  "})
    assert has_element?(live, "#single-option-4")
    Enum.each(1..3, fn i -> refute has_element?(live, "#single-option-#{i}") end)

    live |> element("#multi-search") |> render_keyup(%{"value" => ""})
    Enum.each(1..4, fn i -> assert has_element?(live, "#multi-option-#{i}") end)
  end

  test "no results message shows if no items available", %{live: live} do
    assert live
           |> element("#multi-search")
           |> render_keyup(%{"value" => "asdf"}) =~ "Sorry, no matching options."

    Enum.each(1..4, fn i -> refute has_element?(live, "#multi-option-#{i}") end)
  end

  test "no results message shows if no items available - custom no_matching_options_text", %{
    live: live
  } do
    html =
      live
      |> element("#multi_custom_no_matching_options_text-search")
      |> render_keyup(%{"value" => "asdf"})

    assert html =~ "These aren&#39;t the droids you&#39;re looking for..."

    Enum.each(1..4, fn i ->
      refute has_element?(live, "#multi_custom_no_matching_options_text-option-#{i}")
    end)

    assert "<p id=\"last_search_message_params_p\">\n  {&quot;selected_options&quot;, &quot;asdf&quot;}\n</p>" =
             live |> element("#last_search_message_params_p") |> render()
  end

  test "can select multiple items if multiple=true", %{live: live} do
    live |> element("#multi-option-1") |> render_click()
    live |> element("#multi-option-2") |> render_click()

    assert has_element?(live, "#multi-pop-cross-1")
    assert has_element?(live, "#multi-pop-cross-2")
    refute has_element?(live, "#multi-option-1")
    refute has_element?(live, "#multi-option-2")

    assert live |> element("#selected-options") |> render() ==
             "<span id=\"selected-options\">[1, 2]</span>"
  end

  test "no change to options or selection if dropdown=true", %{live: live} do
    live |> element("#dropdown-option-1") |> render_click()
    live |> element("#dropdown-option-2") |> render_click()

    refute has_element?(live, "#dropdown-pop-cross-1")
    refute has_element?(live, "#dropdown-pop-cross-2")
    assert has_element?(live, "#dropdown-option-1")
    assert has_element?(live, "#dropdown-option-2")

    assert live |> element("#selected-options") |> render() ==
             "<span id=\"selected-options\">2</span>"
  end

  test "selection is replaced instead of appended if multiple=false", %{live: live} do
    live |> element("#single-option-1") |> render_click()
    live |> element("#single-option-2") |> render_click()

    refute has_element?(live, "#single-pop-cross-1")
    assert has_element?(live, "#single-pop-cross-2")
    assert has_element?(live, "#single-option-1")
    refute has_element?(live, "#single-option-2")

    assert live |> element("#selected-options") |> render() ==
             "<span id=\"selected-options\">2</span>"
  end

  test "pop cross removes correct item from selected if multiple=true", %{live: live} do
    live |> element("#multi-option-1") |> render_click()
    live |> element("#multi-option-2") |> render_click()
    live |> element("#multi-pop-cross-1") |> render_click()

    refute has_element?(live, "#multi-pop-cross-1")
    assert has_element?(live, "#multi-pop-cross-2")
    assert has_element?(live, "#multi-option-1")
    refute has_element?(live, "#multi-option-2")

    assert live |> element("#selected-options") |> render() ==
             "<span id=\"selected-options\">[2]</span>"
  end

  test "pop cross clears selection if multiple=false", %{live: live} do
    live |> element("#single-option-1") |> render_click()
    live |> element("#single-pop-cross-1") |> render_click()

    refute has_element?(live, "#single-pop-cross-1")
    assert has_element?(live, "#single-option-1")

    assert live |> element("#selected-options") |> render() ==
             "<span id=\"selected-options\">nil</span>"
  end

  test "view can change available options dynamically without messing up selection", %{live: live} do
    live |> element("#single-option-2") |> render_click()

    new_options = [
      %{id: 1, name: "Ayy"},
      %{id: 2, name: "Bar"},
      %{id: 3, name: "Foo"}
    ]

    send(live.pid, {:change_options, new_options})

    assert has_element?(live, "#single-option-1")
    refute has_element?(live, "#single-option-2")
    assert has_element?(live, "#single-option-3")
    refute has_element?(live, "#single-option-4")

    live |> element("#single-pop-cross-2") |> render_click()
    assert has_element?(live, "#single-option-2")
  end

  test "view can change available options dynamically without messing up selection, multiple=true",
       %{live: live} do
    live |> element("#multi-option-1") |> render_click()
    live |> element("#multi-option-2") |> render_click()

    send(live.pid, {:change_options, [%{id: 1, name: "Ayy"}, %{id: 2, name: "Bar"}]})

    assert has_element?(live, "#multi-pop-cross-1")
    assert has_element?(live, "#multi-pop-cross-2")
    refute has_element?(live, "#multi-option-1")
    refute has_element?(live, "#multi-option-2")
  end

  test "form mode pushes event and creates hidden inputs when changing single select", %{
    live: live
  } do
    hook_id = "single_form-form-hook"
    assert has_element?(live, "##{hook_id}")

    live |> element("#single_form-option-1") |> render_click()

    assert has_element?(live, "#test_single_select[value=\"1\"]")
    assert_push_event(live, "searchable_select", %{id: ^hook_id})

    live |> element("#single_form-option-2") |> render_click()

    refute has_element?(live, "#test_single_select[value=\"1\"]")
    assert has_element?(live, "#test_single_select[value=\"2\"]")
    assert_push_event(live, "searchable_select", %{id: ^hook_id})

    live |> element("#single_form-pop-cross-2") |> render_click()

    refute has_element?(live, "#test_single_select[value=\"2\"]")
    assert_push_event(live, "searchable_select", %{id: ^hook_id})
  end

  test "form mode pushes event and creates hidden inputs when changing multi select", %{
    live: live
  } do
    hook_id = "multi_form-form-hook"
    assert has_element?(live, "##{hook_id}")

    live |> element("#multi_form-option-1") |> render_click()

    assert has_element?(live, "#test_multi_select_1[name=\"test[multi_select][]\"]")
    assert_push_event(live, "searchable_select", %{id: ^hook_id})

    live |> element("#multi_form-option-2") |> render_click()

    assert has_element?(live, "#test_multi_select_1[name=\"test[multi_select][]\"]")
    assert has_element?(live, "#test_multi_select_2[name=\"test[multi_select][]\"]")
    assert_push_event(live, "searchable_select", %{id: ^hook_id})

    live |> element("#multi_form-pop-cross-2") |> render_click()

    refute has_element?(live, "#test_multi_select_2[name=\"test[multi_select][]\"]")
    assert_push_event(live, "searchable_select", %{id: ^hook_id})
  end

  test "pre-selection made, form mode, multiple=false", %{live: live} do
    assert has_element?(live, "#single_form_preselected-option-1")
    assert has_element?(live, "#single_form_preselected-option-2")
    refute has_element?(live, "#single_form_preselected-option-3")
    assert has_element?(live, "#single_form_preselected-option-4")
  end

  test "pre-selection made, form mode, multiple=true", %{live: live} do
    refute has_element?(live, "#multi_form_preselected-option-1")
    refute has_element?(live, "#multi_form_preselected-option-2")
    assert has_element?(live, "#multi_form_preselected-option-3")
    assert has_element?(live, "#multi_form_preselected-option-4")
  end

  test "pre-selection made, non-form mode, multiple=true", %{live: live} do
    refute has_element?(live, "#multi_preselected-option-1")
    refute has_element?(live, "#multi_preselected-option-2")
    assert has_element?(live, "#multi_preselected-option-3")
    assert has_element?(live, "#multi_preselected-option-4")
  end

  test "pre-selection made on invalid element", %{live: live} do
    assert has_element?(live, "#single_invalid_preselect-option-1")
    assert has_element?(live, "#single_invalid_preselect-option-2")
    assert has_element?(live, "#single_invalid_preselect-option-3")
    assert has_element?(live, "#single_invalid_preselect-option-4")
  end

  test "pre-selection made on invalid elements", %{live: live} do
    assert has_element?(live, "#multi_invalid_preselect-option-1")
    assert has_element?(live, "#multi_invalid_preselect-option-2")
    assert has_element?(live, "#multi_invalid_preselect-option-3")
    assert has_element?(live, "#multi_invalid_preselect-option-4")
  end

  test "label_callback drives labels, selection pills and the search key", %{live: live} do
    assert live |> element("#custom_label-option-4") |> render() =~ "Lmao #4"

    # matches the custom label, not the default one - "lmao 4" would not contain it
    live |> element("#custom_label-search") |> render_keyup(%{"value" => "lmao#4"})
    assert has_element?(live, "#custom_label-option-4")
    refute has_element?(live, "#custom_label-option-1")

    live |> element("#custom_label-option-4") |> render_click()
    assert live |> element("#custom_label-root") |> render() =~ "Lmao #4"
  end

  test "sort_by orders the visible options", %{live: live} do
    assert option_ids(live, "sorted") == ["4", "3", "7", "5", "6", "2", "1"]
  end

  test "sort_by given a bare mapper sorts ascending", %{live: live} do
    assert option_ids(live, "sorted_asc") == ["1", "2", "6", "5", "3", "7", "4"]
  end

  test "preselected matches ids that are not integers", %{live: live} do
    assert has_element?(live, "#string_id_preselect-pop-cross-a3f9-uuid")
    refute has_element?(live, "#string_id_preselect-option-a3f9-uuid")
    assert has_element?(live, "#string_id_preselect-option-b7c2")
  end

  test "grouper groups the visible options under their headers", %{live: live} do
    html = live |> element("#grouped-dropdown") |> render()

    assert html =~ "Odd"
    assert html =~ "Even"
    assert option_ids(live, "grouped") == ["1", "5", "3", "7", "2", "6", "4"]
  end

  test "grouper hides a group with no matching options", %{live: live} do
    live |> element("#grouped-search") |> render_keyup(%{"value" => "ayy"})
    html = live |> element("#grouped-dropdown") |> render()

    assert html =~ "Odd"
    refute html =~ "Even"
    assert option_ids(live, "grouped") == ["1"]
  end

  test "value_callback drives the hidden form input value", %{live: live} do
    live |> element("#custom_value_form-option-1") |> render_click()

    assert has_element?(live, "#test_custom_value[value=Ayy]")
  end

  test "on_select routed with send_update reaches the containing LiveComponent", %{live: live} do
    assert live |> element("#nested-selected-options") |> render() ==
             "<span id=\"nested-selected-options\">[]</span>"

    live |> element("#nested_multi-option-1") |> render_click()
    live |> element("#nested_multi-option-2") |> render_click()

    # the containing component's own update/2 saw the selection - the root
    # LiveView is not involved at all
    assert live |> element("#nested-selected-options") |> render() ==
             "<span id=\"nested-selected-options\">[1, 2]</span>"

    assert live |> element("#selected-options") |> render() ==
             "<span id=\"selected-options\">[]</span>"

    live |> element("#nested_multi-pop-cross-1") |> render_click()

    assert live |> element("#nested-selected-options") |> render() ==
             "<span id=\"nested-selected-options\">[2]</span>"
  end

  test "on_search appends a newline when the change came from Enter", %{live: live} do
    live
    |> element("#multi_custom_no_matching_options_text-search")
    |> render_keyup(%{"value" => "ayy", "key" => "Enter"})

    assert "<p id=\"last_search_message_params_p\">\n  {&quot;selected_options&quot;, &quot;ayy\\n&quot;}\n</p>" =
             live |> element("#last_search_message_params_p") |> render()

    # the search itself is unaffected by the trailing newline
    assert has_element?(live, "#multi_custom_no_matching_options_text-option-1")

    live
    |> element("#multi_custom_no_matching_options_text-search")
    |> render_keyup(%{"value" => "ayy", "key" => "y"})

    assert "<p id=\"last_search_message_params_p\">\n  {&quot;selected_options&quot;, &quot;ayy&quot;}\n</p>" =
             live |> element("#last_search_message_params_p") |> render()
  end

  defp option_ids(live, component_id) do
    live
    |> element("##{component_id}-dropdown")
    |> render()
    |> then(&Regex.scan(~r/id="#{component_id}-option-(\d+)"/, &1, capture: :all_but_first))
    |> List.flatten()
  end

  defp load_test_view(_) do
    {:ok, live, _html} = live_isolated(conn(:get, "/"), SearchableSelect.TestView)
    %{live: live}
  end
end
