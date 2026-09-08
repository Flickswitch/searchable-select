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

  The callback is a plain arity-1 function, so it is invoked wherever the
  component is rendered - but routing its argument somewhere the parent can
  handle is up to you, and the adapter you need depends on what the parent is.

  From a LiveView, capture the view's pid and `send/2` to it, handling the
  message in `handle_info/2`:

      # in mount/3
      view = self()
      assign(socket, :on_customer_select, &send(view, {:customer_selected, &1}))

      def handle_info({:customer_selected, customers}, socket) do
        {:noreply, assign(socket, :customers, customers)}
      end

  From another LiveComponent, `send/2` would reach the root LiveView rather than
  your component - the limitation that parent messaging never got around. Route
  with `send_update/2` and handle it in your own `update/2` instead:

      # in mount/1
      myself = socket.assigns.myself
      assign(socket, :on_customer_select, &send_update(myself, customers: &1))

      def update(%{customers: customers}, socket) do
        {:ok, assign(socket, :customers, customers)}
      end

      def update(assigns, socket), do: {:ok, assign(socket, assigns)}

  Either way, assign the callback in the parent's mount rather than building it
  inline in `render/1`, so change tracking can tell that it has not changed.

  For multiple selects, the callback receives a list of selected structs/maps.
  For single selects, it receives a struct/map, or `nil` once the selection is
  cleared.

  You can also use it as part of a normal Phoenix HTML form by passing a
  `field`, and an optional callback for getting the value of each struct.
  `field` and `on_select` are independent rather than alternatives - pass both
  if you want the form params and the callback.

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
    select additionally returns values through hidden inputs, so selections
    arrive in your form's params. Does not disable `on_select`; pass both to
    get the params and the callback.

  - grouper
    Optional. Groups the options under headings in the dropdown. A map of
    `%{groups: [%{name: "Heading"}, ...], group_by_fn: fn option, group -> boolean end}`.
    Groups render in the order given, and a group with no matching options is
    skipped.

  - id
    Component id - required

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
    Called whether or not `field` is set. Optional, defaults to `nil` (no
    notification).

  - on_search
    Arity-1 function called with the search string whenever it changes. A
    trailing "\\n" is appended when the change came from pressing Enter.
    Optional, defaults to `nil` (no notification).

  - placeholder
    Placeholder for the search input, defaults to "Search"

  - preselected
    Populates the component with already-selected options. An `id` for
    `multiple: false`, a list of `id`s for `multiple: true`. Defaults to `nil`
    (no pre-selection occurs). Ids are compared as strings, so a value taken
    straight out of params matches an integer id. Applied on first render, and
    again whenever the value you pass changes - so a parent that resets its own
    state to `nil` or `[]` clears the selection. A re-render that passes the
    same value leaves the user's selection alone.

    Reapplying updates the component and the hidden inputs `field` renders, but
    it does not call `on_select` and does not push a form change event. You
    changed `preselected`, so you already know what the selection is - set your
    own form state to match rather than waiting to be told.

  - sort_by
    Optional. Sorts the options shown in the dropdown. Either a function
    mapping an option to the value to sort by, or a `{function, sorter}` tuple
    where `sorter` is anything `Enum.sort_by/3` accepts, e.g.
    `sort_by={{& &1.name, :desc}}`. Defaults to `nil` (options are sorted by
    their label).

  - value_callback
    Function used to populate the hidden input when field is set. Defaults to
    `fn item -> item.id end`
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
  attr(:preselected, :any, default: nil)
  attr(:sort_by, :any, default: nil)
  attr(:value_callback, :any, default: &SearchableSelect.default_value/1)

  def searchable_select(assigns) do
    ~H"""
    <.live_component module={__MODULE__} {assigns} />
    """
  end

  def default_label(item), do: item.name
  def default_value(item), do: item.id

  @impl true
  # assigns changed after mount - the selection belongs to the component, so it
  # survives a re-render that leaves preselected alone. A parent that changes
  # preselected is asking for a different selection, so that is reapplied.
  def update(assigns, %{assigns: %{id: _id}} = socket) do
    reselect? =
      Map.has_key?(assigns, :preselected) and assigns.preselected != socket.assigns.preselected

    socket
    |> assign(assigns)
    |> assign(:search, "")
    |> then(&if reselect?, do: pre_select(&1, assigns), else: &1)
    |> prep_options(assigns)
    |> sort_and_filter()
    |> then(&{:ok, &1})
  end

  def update(assigns, socket) do
    socket
    |> assign(assigns)
    |> assign(:search, "")
    |> assign(:selected, [])
    |> assign(:limit_removed?, false)
    |> pre_select(assigns)
    |> prep_options(assigns)
    |> sort_and_filter()
    |> then(&{:ok, &1})
  end

  @impl true
  def handle_event("pop", %{"key" => key}, %{assigns: %{selected: selected}} = socket) do
    if List.keymember?(selected, key, 0) do
      socket
      |> assign(:selected, List.keydelete(selected, key, 0))
      |> update_parent_view()
      |> sort_and_filter()
      |> then(&{:noreply, &1})
    else
      {:noreply, socket}
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
    case List.keyfind(assigns.keyed_options, key, 0) do
      nil ->
        {:noreply, socket}

      {^key, val} ->
        if assigns.on_select, do: assigns.on_select.(val)

        socket
        |> assign(:search, "")
        |> then(&{:noreply, &1})
    end
  end

  def handle_event("select", %{"key" => key}, %{assigns: assigns} = socket) do
    case List.keyfind(unselected(assigns), key, 0) do
      nil ->
        {:noreply, socket}

      option ->
        selected = if assigns.multiple, do: assigns.selected ++ [option], else: [option]

        socket
        |> assign(selected: selected, search: "")
        |> sort_and_filter()
        |> update_parent_view()
        |> then(&{:noreply, &1})
    end
  end

  def handle_event("remove_limit", _, socket) do
    socket
    |> assign(limit_removed?: true, search: "")
    |> sort_and_filter()
    |> then(&{:noreply, &1})
  end

  def pop_cross(assigns) do
    ~H"""
    <button
      type="button"
      class="my-auto h-4 w-4 fill-current"
      id={get_pop_cross_id(@component_id, elem(@selected, 1))}
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

  def get_option_id(component_id, option), do: "#{component_id}-option-#{option.id}"
  def get_pop_cross_id(component_id, option), do: "#{component_id}-pop-cross-#{option.id}"

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

  # The dropdown shows everything that is not currently selected. Deriving that
  # each time is what keeps the option list and the selection from drifting
  # apart - neither one is edited in place.
  defp sort_and_filter(%{assigns: assigns} = socket) do
    {limit_hit?, visible_options} =
      assigns
      |> unselected()
      |> filter(assigns.search)
      |> limit_options(if assigns.limit_removed?, do: 0, else: assigns.limit)

    assign(socket,
      limit_hit?: limit_hit?,
      visible_options: sort_options(visible_options, assigns.sort_by)
    )
  end

  defp unselected(%{keyed_options: keyed_options, selected: selected}) do
    selected_keys = MapSet.new(selected, fn {key, _val} -> key end)
    Enum.reject(keyed_options, fn {key, _val} -> MapSet.member?(selected_keys, key) end)
  end

  defp sort_options(visible_options, nil), do: visible_options

  defp sort_options(visible_options, {mapper, sorter}) do
    Enum.sort_by(visible_options, fn {_key, option} -> mapper.(option) end, sorter)
  end

  defp sort_options(visible_options, mapper), do: sort_options(visible_options, {mapper, :asc})

  defp limit_options(options, limit) when is_integer(limit) and limit > 0 do
    {count, limited_options} =
      Enum.reduce_while(options, {0, []}, fn
        _, {count, list} when count >= limit -> {:halt, {count, list}}
        option, {count, list} -> {:cont, {count + 1, [option | list]}}
      end)

    if count >= limit, do: {true, Enum.reverse(limited_options)}, else: {false, options}
  end

  defp limit_options(options, _), do: {false, options}

  defp prep_options(%{assigns: assigns} = socket, %{options: options}) do
    keyed_options =
      options
      |> Enum.map(&{unique_normalised_key(&1, assigns.label_callback), &1})
      |> Enum.sort_by(fn {key, _val} -> key end)

    assign(socket, :keyed_options, keyed_options)
  end

  defp filter(keyed_options, search) do
    case normalise_string(search) do
      "" ->
        keyed_options

      search ->
        Enum.filter(keyed_options, fn {key, _val} ->
          key |> String.split(" ") |> List.first() |> String.contains?(search)
        end)
    end
  end

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

  # ids are compared as strings so that a preselection taken straight from
  # params matches an integer id, without assuming ids are integers at all
  defp pre_select(socket, %{options: options, preselected: preselected, multiple: multiple}) do
    ids = preselected |> List.wrap() |> MapSet.new(&to_string/1)

    selected =
      options
      |> Enum.filter(&MapSet.member?(ids, to_string(&1.id)))
      |> then(&if multiple, do: &1, else: Enum.take(&1, 1))
      |> Enum.map(&{unique_normalised_key(&1, socket.assigns.label_callback), &1})

    assign(socket, :selected, selected)
  end

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
