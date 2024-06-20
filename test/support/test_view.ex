defmodule SearchableSelect.TestView do
  @moduledoc false
  use Phoenix.LiveView

  @impl true
  def mount(_params, _session, socket) do
    example_options = [
      %{id: 1, name: "Ayy"},
      %{id: 2, name: "Bar"},
      %{id: 3, name: "Foo"},
      %{id: 4, name: "Lmao"},
      %{id: 5, name: "Biz"},
      %{id: 6, name: "Baz"},
      %{id: 7, name: "Foo"}
    ]

    socket =
      socket
      |> assign(:last_search_message_params, nil)
      |> assign(:options, example_options)
      |> assign(:selected_options, [])

    {:ok, socket}
  end

  @impl true
  def handle_info({:change_options, options}, socket) do
    socket
    |> assign(:options, options)
    |> then(&{:noreply, &1})
  end

  def handle_info({:select, _items_key, items}, socket) do
    socket
    |> assign(:selected_options, items)
    |> then(&{:noreply, &1})
  end

  def handle_info({:search, key, search_string}, socket) do
    socket
    |> assign(:last_search_message_params, {key, search_string})
    |> then(&{:noreply, &1})
  end

  defp get_selected_id_list([]), do: "[]"
  defp get_selected_id_list([%{id: id}]), do: "[#{id}]"
  defp get_selected_id_list(nil), do: "nil"
  defp get_selected_id_list(%{id: id}), do: "#{id}"
  defp get_selected_id_list(selected), do: Enum.map(selected, & &1.id) |> inspect()

  @impl true
  def render(assigns) do
    ~H"""
    <.live_component
      id="multi"
      module={SearchableSelect}
      multiple
      options={@options}
      parent_key="selected_options"
    />
    <.live_component
      id="multi_custom_no_matching_options_text"
      module={SearchableSelect}
      multiple
      options={@options}
      parent_key="selected_options"
      no_matching_options_text="These aren't the droids you're looking for..."
      send_search_events
    />
    <.live_component
      id="single"
      module={SearchableSelect}
      options={@options}
      parent_key="selected_options"
    />
    <.live_component
      id="single_limited"
      module={SearchableSelect}
      options={@options}
      limit={2}
      parent_key="selected_options"
    />
    <.live_component
      id="single_preselected"
      module={SearchableSelect}
      options={@options}
      parent_key="selected_options"
      preselected_id={4}
    />
    <.live_component
      id="multi_preselected"
      module={SearchableSelect}
      multiple
      options={@options}
      parent_key="selected_options"
      preselected_ids={[1, 2]}
    />
    <.live_component
      dropdown
      id="dropdown"
      module={SearchableSelect}
      options={@options}
      parent_key="selected_options"
    />
    <span id="selected-options"><%= get_selected_id_list(@selected_options) %></span>
    <.form for={%{}} :let={f} as={:test}>
      <.live_component
        field={:single_select}
        form={f}
        id="single_form"
        module={SearchableSelect}
        options={@options}
      />
      <.live_component
        field={:multi_select}
        form={f}
        id="multi_form"
        module={SearchableSelect}
        multiple
        options={@options}
      />
      <.live_component
        id="single_form_preselected"
        module={SearchableSelect}
        options={@options}
        parent_key="selected_options"
        preselected_id={3}
      />
      <.live_component
        id="multi_form_preselected"
        module={SearchableSelect}
        multiple
        options={@options}
        parent_key="selected_options"
        preselected_ids={[1, 2]}
      />
    </.form>
    <.live_component
      id="single_invalid_preselect"
      module={SearchableSelect}
      options={@options}
      parent_key="selected_options"
      preselected_id={99}
    />
    <.live_component
      id="multi_invalid_preselect"
      module={SearchableSelect}
      options={@options}
      parent_key="selected_options"
      preselected_ids={[98, 99]}
    />

    last_search_message_params: <p id="last_search_message_params_p">
      <%= inspect(@last_search_message_params) %>
    </p>
    """
  end
end
