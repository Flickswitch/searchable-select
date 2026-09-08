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

    view = self()

    socket =
      socket
      |> assign(:grouper, %{groups: [%{name: "Odd"}, %{name: "Even"}], group_by_fn: &parity?/2})
      |> assign(:label_callback, &label_with_id/1)
      |> assign(:last_search_message_params, nil)
      |> assign(:on_search, &send(view, {:search, "selected_options", &1}))
      |> assign(:on_select, &send(view, {:select, "selected_options", &1}))
      |> assign(:options, example_options)
      |> assign(:reset_preselected, [1, 2])
      |> assign(:selected_options, [])
      |> assign(:sort_by, {&sort_by_name/1, :desc})
      |> assign(:sort_by_asc, &sort_by_name/1)
      |> assign(:string_id_options, [
        %{id: "a3f9-uuid", name: "Alpha"},
        %{id: "b7c2", name: "Beta"}
      ])
      |> assign(:value_callback, &value_as_name/1)

    {:ok, socket}
  end

  defp label_with_id(%{id: id, name: name}), do: "#{name} ##{id}"
  defp sort_by_name(%{name: name}), do: name
  defp value_as_name(%{name: name}), do: name

  defp parity?(%{id: id}, %{name: "Odd"}), do: rem(id, 2) == 1
  defp parity?(%{id: id}, %{name: "Even"}), do: rem(id, 2) == 0

  @impl true
  def handle_info({:change_preselected, preselected}, socket) do
    socket
    |> assign(:reset_preselected, preselected)
    |> then(&{:noreply, &1})
  end

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
    <SearchableSelect.searchable_select
      id="multi"
      multiple
      options={@options}
      on_select={@on_select}
    />
    <SearchableSelect.searchable_select
      id="multi_custom_no_matching_options_text"
      multiple
      options={@options}
      on_select={@on_select}
      no_matching_options_text="These aren't the droids you're looking for..."
      on_search={@on_search}
    />
    <SearchableSelect.searchable_select
      id="single"
      options={@options}
      on_select={@on_select}
    />
    <SearchableSelect.searchable_select
      id="single_limited"
      options={@options}
      limit={2}
      on_select={@on_select}
    />
    <SearchableSelect.searchable_select
      id="single_unlimited"
      options={@options}
      limit={0}
      on_select={@on_select}
    />
    <SearchableSelect.searchable_select
      id="single_preselected"
      options={@options}
      on_select={@on_select}
      preselected={4}
    />
    <SearchableSelect.searchable_select
      id="multi_preselected"
      multiple
      options={@options}
      on_select={@on_select}
      preselected={[1, 2]}
    />
    <SearchableSelect.searchable_select
      id="reset_preselected"
      multiple
      options={@options}
      preselected={@reset_preselected}
    />
    <SearchableSelect.searchable_select
      dropdown
      id="dropdown"
      options={@options}
      on_select={@on_select}
    />
    <SearchableSelect.searchable_select
      id="custom_label"
      label_callback={@label_callback}
      multiple
      options={@options}
      on_select={@on_select}
    />
    <SearchableSelect.searchable_select
      id="sorted"
      options={@options}
      on_select={@on_select}
      sort_by={@sort_by}
    />
    <SearchableSelect.searchable_select
      id="sorted_asc"
      options={@options}
      on_select={@on_select}
      sort_by={@sort_by_asc}
    />
    <SearchableSelect.searchable_select
      id="string_id_preselect"
      options={@string_id_options}
      on_select={@on_select}
      preselected="a3f9-uuid"
    />
    <SearchableSelect.searchable_select
      grouper={@grouper}
      id="grouped"
      multiple
      options={@options}
      on_select={@on_select}
    />
    <span id="selected-options">{get_selected_id_list(@selected_options)}</span>
    <.form :let={f} for={%{}} as={:test}>
      <SearchableSelect.searchable_select
        field={f[:single_select]}
        id="single_form"
        on_select={@on_select}
        options={@options}
      />
      <SearchableSelect.searchable_select
        field={f[:multi_select]}
        id="multi_form"
        multiple
        on_select={@on_select}
        options={@options}
      />
      <SearchableSelect.searchable_select
        field={f[:custom_value]}
        id="custom_value_form"
        on_select={@on_select}
        options={@options}
        value_callback={@value_callback}
      />
      <SearchableSelect.searchable_select
        id="single_form_preselected"
        options={@options}
        on_select={@on_select}
        preselected={3}
      />
      <SearchableSelect.searchable_select
        id="multi_form_preselected"
        multiple
        options={@options}
        on_select={@on_select}
        preselected={[1, 2]}
      />
      <SearchableSelect.searchable_select
        field={f[:reset_form_select]}
        id="reset_form"
        multiple
        options={@options}
        preselected={@reset_preselected}
      />
    </.form>
    <SearchableSelect.searchable_select
      id="single_invalid_preselect"
      options={@options}
      on_select={@on_select}
      preselected={99}
    />
    <SearchableSelect.searchable_select
      id="multi_invalid_preselect"
      options={@options}
      on_select={@on_select}
      preselected={[98, 99]}
    />
    <.live_component module={SearchableSelect.TestComponent} id="nested" options={@options} />
    last_search_message_params:
    <p id="last_search_message_params_p">
      {inspect(@last_search_message_params)}
    </p>
    """
  end
end
