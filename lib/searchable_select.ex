defmodule SearchableSelect do
  @moduledoc """
  Select component with nicer styling than HTML5 select

  Render it with `searchable_select/1` from a LiveView or another LiveComponent.
  `searchable_select/1` is the only supported entry point - rendering the module
  directly with `<.live_component module={SearchableSelect} />` bypasses the
  declared attributes and their defaults.

  To be told about selections, pass an `on_select` callback:

      <SearchableSelect.searchable_select
        id="customer-select"
        options={@customers}
        on_select={@on_customer_select}
      />

  Assign the callback once in `mount/3` rather than building it inline in
  `render/1`, so change tracking can tell that it has not changed:

      view = self()
      assign(socket, :on_customer_select, &send(view, {:select, :customer, &1}))

  For multiple selects, the callback receives a list of selected structs/maps.
  For single selects, it receives a struct/map, or `nil` once the selection is
  cleared.

  Alternatively you can use it as part of a normal Phoenix HTML form by passing
  a `field`, and an optional callback for getting the value of each struct.

  The following attributes are available:

  - class
    Classes to apply to outermost div, defaults to ""

  - disabled
    True=component is disabled - optional, defaults to `false`

  - dropdown
    True=selection doesn't persist after click, so behaves like a dropdown
    instead of a select - optional, defaults to `false`

  - field
    `Phoenix.HTML.FormField` (i.e. `@form[:your_field]`), optional. If set, the
    select returns values via hidden inputs instead of via `on_select`.

  - grouper
    Optional. Groups the options under headings in the dropdown. A map of
    `%{groups: [%{name: "Heading"}, ...], group_by_fn: fn {key, option}, group -> boolean end}`.
    Groups render in the order given, and a group with no matching options is
    skipped. Note that `group_by_fn` receives the internal `{key, option}`
    tuple rather than the option on its own.

  - id
    Component id - required

  - id_key
    Map/struct key to use when generating DOM IDs for options - optional, defaults to `:id`.
    If your maps/structs don't have this field then no DOM IDs will be set. Not
    needed for the select to function, just included as a testing convenience.

  - label_callback
    Function used to populate label when displaying items. Defaults to
    `fn item -> item.name end`

  - limit
    Maximum number of entries to display. Useful for improving performance with
    long lists. Setting to `0` removes the limit. (default: 100)
  - limit_hit_text
    If results are being limited, an option at the end of the list will be added
    to notify the user about this. Clicking on on, removes the limit. Set this
    to `nil` to hide this last option entirely. (default:
    "(Limited results shown; refine search, or click to display all)")

  - multiple
    Optional, defaults to `false`
    - `true`: multiple options may be selected
    - `false`: only one option may be select

  - options
    List of maps or structs to use as options - required. Each option must have
    a unique `:id`, which should not contain any spaces.

  - no_matching_options_text
    Text to display if a search is entered but there are no matching options.
    Defaults to: "Sorry, no matching options."

  - on_select
    Arity-1 function called with the current selection whenever it changes.
    Optional, defaults to `nil` (no notification).

  - on_search
    Arity-1 function called with the search string whenever it changes. A
    trailing "\\n" is appended when the change came from pressing Enter.
    Optional, defaults to `nil` (no notification).

  - placeholder
    Placeholder for the search input, defaults to "Search"

  - preselected_id
    Used to populate the component with an already-selected option upon first
    render. Only for `multiple: false`. Specify the `id` of the desired option,
    defaults to `nil` (no pre-selection occurs).

  - preselected_ids
    Used to populate the component with already-selected options upon first
    render. Only for `multiple: true`. Specify a list of `id`s of the desired
    options, defaults to [] (no pre-selection occurs).

  - value_callback
    Function used to populate the hidden input when field is set. Defaults to
    `fn item -> item.id end`

  - sort_callback
    Optional. Either `:asc` or `:desc` and optional module to use for comparison
    (refer to `Enum.sort_by/3`)

  - sort_mapping_callback
    Optional. Function for mapping of value to sort by (refer to
    `Enum.sort_by/3`)
  """
  use Phoenix.LiveComponent
  alias Phoenix.HTML.Form
  alias Phoenix.LiveView.JS

  attr(:id, :string, required: true)
  attr(:options, :list, required: true)
  attr(:class, :string, default: "")
  attr(:disabled, :boolean, default: false)
  attr(:dropdown, :boolean, default: false)
  attr(:field, Phoenix.HTML.FormField, default: nil)
  attr(:grouper, :any, default: nil)
  attr(:id_key, :atom, default: :id)
  attr(:label_callback, :any, default: &SearchableSelect.default_label/1)
  attr(:limit, :integer, default: 100)

  attr(:limit_hit_text, :any,
    default: "(Limited results shown; refine search, or click to display all)"
  )

  attr(:multiple, :boolean, default: false)
  attr(:no_matching_options_text, :string, default: nil)
  attr(:on_search, :any, default: nil)
  attr(:on_select, :any, default: nil)
  attr(:placeholder, :string, default: "Search")
  attr(:preselected_id, :any, default: nil)
  attr(:preselected_ids, :list, default: [])
  attr(:sort_callback, :any, default: nil)
  attr(:sort_mapping_callback, :any, default: nil)
  attr(:value_callback, :any, default: &SearchableSelect.default_value/1)

  def searchable_select(assigns) do
    ~H"""
    <.live_component module={__MODULE__} {assigns} />
    """
  end

  def default_label(item), do: item.name
  def default_value(item), do: item.id

  @impl true
  # assigns changed after mount - the selection belongs to the component now, so
  # it survives, and preselection is not reapplied
  def update(assigns, %{assigns: %{id: _id}} = socket) do
    socket
    |> assign(assigns)
    |> assign(:search, "")
    |> prep_options(assigns)
    |> sort_and_filter()
    |> then(&{:ok, &1})
  end

  def update(assigns, socket) do
    socket
    |> assign(assigns)
    |> assign(:search, "")
    |> assign(:selected, [])
    |> pre_select(assigns)
    |> prep_options(assigns)
    |> sort_and_filter()
    |> then(&{:ok, &1})
  end

  @impl true
  def handle_event("pop", %{"key" => key}, %{assigns: assigns} = socket) do
    %{options: options, selected: selected} = assigns

    case List.keyfind(selected, key, 0) do
      nil ->
        {:noreply, socket}

      {^key, val} ->
        options = :gb_trees.insert(key, val, options)

        socket
        |> assign(:options, options)
        |> assign(:selected, List.keydelete(selected, key, 0))
        |> update_parent_view()
        |> sort_and_filter()
        |> then(&{:noreply, &1})
    end
  end

  def handle_event("search", %{"value" => search} = params, socket) do
    if on_search = socket.assigns.on_search do
      on_search.(if params["key"] == "Enter", do: "#{search}\n", else: search)
    end

    socket
    |> assign(:search, search)
    |> sort_and_filter()
    |> then(&{:noreply, &1})
  end

  def handle_event("select", %{"key" => key}, %{assigns: %{dropdown: true} = assigns} = socket) do
    %{on_select: on_select, options: options} = assigns

    case :gb_trees.lookup(key, options) do
      :none ->
        {:noreply, socket}

      {:value, val} ->
        if on_select, do: on_select.(val)

        socket
        |> assign(:search, "")
        |> then(&{:noreply, &1})
    end
  end

  def handle_event("select", %{"key" => key}, %{assigns: assigns} = socket) do
    %{options: options, selected: selected} = assigns

    case :gb_trees.take_any(key, options) do
      :error ->
        {:noreply, socket}

      {val, options} ->
        {options, selected} =
          if !assigns.multiple and length(selected) == 1 do
            [{old_key, old_val}] = selected
            {:gb_trees.insert(old_key, old_val, options), []}
          else
            {options, selected}
          end

        selected = selected ++ [{key, val}]

        socket
        |> assign(:options, options)
        |> assign(:selected, selected)
        |> assign(:search, "")
        |> sort_and_filter()
        |> update_parent_view()
        |> then(&{:noreply, &1})
    end
  end

  def handle_event("remove_limit", _, socket) do
    socket
    |> assign(limit: 0, search: "")
    |> sort_and_filter()
    |> then(&{:noreply, &1})
  end

  def pop_cross(assigns) do
    ~H"""
    <button
      type="button"
      class="my-auto h-4 w-4 fill-current"
      id={get_pop_cross_id(@component_id, elem(@selected, 1), @id_key)}
      aria-label="Remove selection"
      phx-click="pop"
      phx-value-key={elem(@selected, 0)}
      phx-target={@target}
    >
      <svg class="h-full w-full" aria-hidden="true" viewBox="0 0 20 20">
        <path d="M14.348,14.849c-0.469,0.469-1.229,0.469-1.697,0L10,11.819l-2.651,3.029c-0.469,0.469-1.229,0.469-1.697,0 c-0.469-0.469-0.469-1.229,0-1.697l2.758-3.15L5.651,6.849c-0.469-0.469-0.469-1.228,0-1.697s1.228-0.469,1.697,0L10,8.183 l2.651-3.031c0.469-0.469,1.228-0.469,1.697,0s0.469,1.229,0,1.697l-2.758,3.152l2.758,3.15 C14.817,13.62,14.817,14.38,14.348,14.849z" />
      </svg>
    </button>
    """
  end

  # get id_key, component id, selected
  def get_option_id(component_id, selected, id_key) do
    case Map.get(selected, id_key) do
      nil -> nil
      id -> "#{component_id}-option-#{id}"
    end
  end

  def get_pop_cross_id(component_id, selected, id_key) do
    case Map.get(selected, id_key) do
      nil -> nil
      id -> "#{component_id}-pop-cross-#{id}"
    end
  end

  def hide_dropdown(id, js \\ %JS{}) do
    JS.hide(js, to: "##{id}-dropdown")
  end

  def show_dropdown(js, id) do
    JS.show(js, to: "##{id}-dropdown")
  end

  def toggle_dropdown(id) do
    JS.toggle(%JS{}, to: "##{id}-dropdown")
  end

  def selection_action(key, target, id, multiple) do
    js = JS.push("select", target: target, value: %{"key" => key})

    if multiple do
      js
    else
      hide_dropdown(id, js)
    end
  end

  def sort_and_filter(%{assigns: assigns} = socket) do
    {limit_hit?, visible_options} =
      assigns.options
      |> filter(assigns.search)
      |> limit_options(assigns.limit)

    visible_options =
      sort_options(visible_options, assigns.sort_mapping_callback, assigns.sort_callback)

    assign(socket, limit_hit?: limit_hit?, visible_options: visible_options)
  end

  defp sort_options(visible_options, nil, nil), do: visible_options

  defp sort_options(visible_options, sort_mapping_callback, sort_callback) do
    Enum.sort_by(visible_options, fn {_, x} -> sort_mapping_callback.(x) end, sort_callback)
  end

  defp limit_options(options, limit) when is_integer(limit) and limit > 0 do
    {count, limited_options} =
      Enum.reduce_while(options, {0, []}, fn
        _, {count, list} when count >= limit -> {:halt, {count, list}}
        option, {count, list} -> {:cont, {count + 1, [option | list]}}
      end)

    if count >= limit, do: {true, Enum.reverse(limited_options)}, else: {false, options}
  end

  defp limit_options(options, _), do: {false, options}

  def prep_options(%{assigns: assigns} = socket, %{options: options}) do
    gb_options =
      Enum.reduce(options, :gb_trees.empty(), fn option, acc ->
        :gb_trees.insert(unique_normalised_key(option, assigns.label_callback), option, acc)
      end)

    gb_options =
      Enum.reduce(assigns.selected, gb_options, fn {key, _}, acc ->
        :gb_trees.delete_any(key, acc)
      end)

    assign(socket, :options, gb_options)
  end

  def filter(options, search) do
    search = normalise_string(search)

    if search == "" do
      :gb_trees.to_list(options)
    else
      options
      |> :gb_trees.iterator()
      |> :gb_trees.next()
      |> filter([], search)
    end
  end

  def filter({key, val, next}, acc, search) do
    acc =
      if key |> String.split(" ") |> List.first() |> String.contains?(search) do
        [{key, val} | acc]
      else
        acc
      end

    filter(:gb_trees.next(next), acc, search)
  end

  def filter(:none, acc, _search), do: Enum.reverse(acc)

  defp update_parent_view(%{assigns: assigns} = socket) do
    %{field: field, id: id, multiple: multiple, on_select: on_select, selected: selected} =
      assigns

    if on_select, do: on_select.(selection(selected, multiple))

    if field do
      push_event(socket, "searchable_select", %{id: get_hook_id(id)})
    else
      socket
    end
  end

  defp selection(selected, true), do: Enum.map(selected, fn {_key, val} -> val end)
  defp selection([], false), do: nil
  defp selection([{_key, val}], false), do: val

  def hidden_form_input(%{selected_val: selected_val, value_callback: value_callback} = assigns) do
    assigns = assign(assigns, :value, value_callback.(selected_val))

    ~H"""
    <input
      id={if @multiple, do: Form.input_id(@field.form, @field.field, @value), else: @field.id}
      name={@field.name <> if @multiple, do: "[]", else: ""}
      type="hidden"
      value={@value}
    />
    """
  end

  defp get_hook_id(id), do: id <> "-form-hook"

  defp pre_select(socket, %{preselected_ids: [], multiple: true}) do
    assign(socket, :selected, [])
  end

  defp pre_select(socket, %{preselected_id: nil, preselected_ids: []}), do: socket

  defp pre_select(socket, %{options: options, preselected_id: preselected_id, multiple: false}) do
    preselected_id =
      if is_binary(preselected_id) do
        String.to_integer(preselected_id)
      else
        preselected_id
      end

    selected_option = Enum.find(options, &(Map.get(&1, :id) == preselected_id))

    if selected_option do
      selected_option_key = unique_normalised_key(selected_option, socket.assigns.label_callback)
      assign(socket, :selected, [{selected_option_key, selected_option}])
    else
      assign(socket, :selected, [])
    end
  end

  defp pre_select(socket, %{options: options, preselected_ids: preselected_ids, multiple: true}) do
    selected =
      Enum.reduce(options, [], fn option, acc ->
        if option.id in preselected_ids do
          option_key = unique_normalised_key(option, socket.assigns.label_callback)
          acc ++ [{option_key, option}]
        else
          acc
        end
      end)

    assign(socket, :selected, selected)
  end

  defp pre_select(socket, _assigns), do: socket

  defp normalise_string(string) do
    string
    |> String.replace(" ", "")
    |> String.downcase()
  end

  defp unique_normalised_key(option, label_callback) do
    normalised_label = label_callback.(option) |> normalise_string()
    "#{normalised_label} #{option.id}"
  end
end
