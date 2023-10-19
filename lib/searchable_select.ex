defmodule SearchableSelect do
  @moduledoc """
  Select component with nicer styling than HTML5 select

  Your view will need to implement a callback like this:
  `handle_info({:select, parent_key, selected}, socket)`

  Alternatively you can use it as part of a normal Phoenix HTML form by setting form and field
  assigns, and an optional callback for getting the value of each struct.

  For multiple selects, selected will be a list of selected structs/maps
  For single selects, selected will be a struct/map

  The following attributes are available:

  - class
    Classes to apply to outermost div, defaults to ""

  - disabled
    True=component is disabled - optional, defaults to `false`

  - dropdown
    True=selection doesn't persist after click, so behaves like a dropdown
    instead of a select - optional, defaults to `false`

  - field
    Field name to use as part of form, required if form is set

  - form
    Phoenix.HTML.Form, optional, if set will make searchable select return
    values via a hidden input instead of handle_info

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

  - parent_key
    Key to send to parent view when options are selected/unselected - required
    unless form is set

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
    Function used to populate the hidden input when form is set. Defaults to
    `fn item -> item.id end`

  - send_search_events
    If set, this Component sends a `{:search, key, search_string}` message
    whenever its search string changes. Defaults to false.

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
  attr :field, :any,
    required: true,
    doc: "a Phoenix.HTML.FormField struct identifying the form's field"

  attr :form, :any,
    required: false,
    doc: "a Phoenix.HTML. struct identifying the for"

  attr :id, :string,
    doc:
      ~S(an id to assign to the component. If none is provided, `#{form_name}_#{field}_live_select_component` will be used)

  attr :disabled, :boolean, doc: "set this to `true` to disable the input field"
  attr :dropdown, :boolean, doc: "set this to `true` to disable the input field"
  attr :id_key, :string, doc: "ID Key"
  attr :placehoder, :string, default: "Search", doc: "Placeholder text for the input"
  attr :label_callback, :string, doc: "Label callback for formatting label of option items"
  attr :limit, :integer, doc: "Label callback for formatting label of option items"
  attr :limit_hit?, :boolean, doc: "Label callback for formatting label of option items"
  attr :limit_hit_text?, :string, doc: "Label callback for formatting label of option items"
  attr :multiple, :boolean, default: false, doc: "Allow Multiple selection"
  attr :no_matching_options_text, :string, doc: "Text if search does not return any options"
  attr :parent_key, :string, doc: "Text if search does not return any options"
  attr :search, :string, default: "", doc: "?"
  attr :selected, :list, default: [], doc: "Item selected"
  attr :send_search_events, :boolean, default: false, doc: "Send search events to parent process"
  attr :sort_callback, :string, doc: "Sort option items callback function"
  attr :sort_mapping_callback, :string, doc: "Sort option items callback function"

  # attr :value_callback, :any,
  #   default: &fn item -> item.id end,
  #   doc: "Callback to overload value getting from item"
  @impl true
  def mount(socket) do
    {:ok, socket}
  end

  @impl true
  # this is when assigns change after the component is mounted
  def update(assigns, %{assigns: %{id: _id}} = socket) do
    socket
    |> assign(:disabled, assigns[:disabled])
    |> assign(:placeholder, assigns[:placeholder] || "Search")
    |> assign(:search, "")
    |> then(&pre_select(&1, Map.merge(&1.assigns, assigns)))
    |> prep_options(assigns)
    |> sort_and_filter()
    |> then(&{:ok, &1})
  end



  # credo:disable-for-lines:30 Credo.Check.Refactor.CyclomaticComplexity
  @default_limit_hit_text "(Limited results shown; refine search, or click to display all)"
  # this is when the component is mounted
  def update(assigns, socket) do
    socket
    |> assign(:class, assigns[:class] || "")
    |> assign(:disabled, assigns[:disabled] || false)
    |> assign(:dropdown, assigns[:dropdown] || false)
    |> assign(:field, fn
      %Phoenix.HTML.FormField{} = field, _ ->
        field

      field, %{form: form} ->
        IO.warn(
          "instead of passing separate form and field attributes, pass a single field attribute of type Phoenix.HTML.FormField"
        )

        to_form(form)[field]

      _, _ ->
        raise "if you pass field as atom or string, you also have to pass a form"
    end)
    |> assign(:form, assigns[:form])
    |> assign(:id_key, assigns[:id_key] || :id)
    |> assign(:id, assigns.id)
    |> assign(:label_callback, assigns[:label_callback] || fn item -> item.name end)
    |> assign(:limit, assigns[:limit] || 100)
    |> assign(:limit_hit?, false)
    |> assign(:limit_hit_text, Map.get(assigns, :limit_hit_text, @default_limit_hit_text))
    |> assign(:multiple, assigns[:multiple] || false)
    |> assign(:no_matching_options_text, assigns[:no_matching_options_text])
    |> assign(:parent_key, assigns[:parent_key])
    |> assign(:placeholder, assigns[:placeholder] || "Search")
    |> assign(:search, "")
    |> assign(:selected, assigns[:selected] || [])
    |> assign(:send_search_events, assigns[:send_search_events] || false)
    |> assign(:sort_callback, assigns[:sort_callback])
    |> assign(:sort_mapping_callback, assigns[:sort_mapping_callback])
    |> assign(:value_callback, assigns[:value_callback] || fn item -> item.id end)
    |> then(&pre_select(&1, Map.merge(&1.assigns, assigns)))
    |> prep_options(assigns)
    |> sort_and_filter()
    |> then(&{:ok, &1})
  end

  @impl true
  def handle_event("pop", %{"key" => key}, %{assigns: assigns} = socket) do
    %{options: options, selected: selected} = assigns

    {selected, val} =
      Enum.reduce(selected, {[], nil}, fn
        {^key, val}, {acc, nil} -> {acc, val}
        other_selection, {acc, acc_val} -> {[other_selection | acc], acc_val}
      end)

    options = :gb_trees.insert(key, val, options)

    socket
    |> assign(:options, options)
    |> assign(:selected, Enum.reverse(selected))
    |> update_parent_view()
    |> sort_and_filter()
    |> then(&{:noreply, &1})
  end

  def handle_event("search", %{"value" => search} = params, socket) do
    %{assigns: %{parent_key: parent_key, send_search_events: send_search_events}} = socket

    if send_search_events do
      search_event_str = if params["key"] == "Enter", do: "#{search}\n", else: search
      send(self(), {:search, parent_key, search_event_str})
    end

    socket
    |> assign(:search, search)
    |> sort_and_filter()
    |> then(&{:noreply, &1})
  end

  def handle_event("select", %{"key" => key}, %{assigns: %{dropdown: true} = assigns} = socket) do
    %{options: options, parent_key: parent_key} = assigns
    val = :gb_trees.get(key, options)
    send(self(), {:select, parent_key, val})

    socket
    |> assign(:search, "")
    |> then(&{:noreply, &1})
  end

  def handle_event("select", %{"key" => key}, %{assigns: assigns} = socket) do
    %{options: options, selected: selected} = assigns
    {val, options} = :gb_trees.take(key, options)

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

  def handle_event("remove_limit", _, socket) do
    socket
    |> assign(limit: 0, limit_hit?: false, search: "")
    |> sort_and_filter()
    |> then(&{:noreply, &1})
  end

  def pop_cross(assigns) do
    ~H"""
    <svg
      class="fill-current h-4 w-4 my-auto"
      id={get_pop_cross_id(@component_id, elem(@selected, 1), @id_key)}
      role="button"
      viewBox="0 0 20 20"
      phx-click="pop"
      phx-value-key={elem(@selected, 0)}
      phx-target={@target}
    >
      <path d="M14.348,14.849c-0.469,0.469-1.229,0.469-1.697,0L10,11.819l-2.651,3.029c-0.469,0.469-1.229,0.469-1.697,0 c-0.469-0.469-0.469-1.229,0-1.697l2.758-3.15L5.651,6.849c-0.469-0.469-0.469-1.228,0-1.697s1.228-0.469,1.697,0L10,8.183 l2.651-3.031c0.469-0.469,1.228-0.469,1.697,0s0.469,1.229,0,1.697l-2.758,3.152l2.758,3.15 C14.817,13.62,14.817,14.38,14.348,14.849z" />
    </svg>
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

  # TODO: transition animations
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

  def update_parent_view(%{assigns: %{form: form, id: id}} = socket) when form != nil do
    push_event(socket, "searchable_select", %{id: get_hook_id(id)})
  end

  def update_parent_view(%{assigns: %{multiple: true} = assigns} = socket) do
    %{parent_key: parent_key, selected: selected} = assigns
    send(self(), {:select, parent_key, Enum.map(selected, fn {_key, val} -> val end)})
    socket
  end

  def update_parent_view(%{assigns: %{parent_key: parent_key, selected: []}} = socket) do
    send(self(), {:select, parent_key, nil})
    socket
  end

  def update_parent_view(%{assigns: %{parent_key: parent_key, selected: [{_, val}]}} = socket) do
    send(self(), {:select, parent_key, val})
    socket
  end

  def hidden_form_input(%{selected_val: selected_val, value_callback: value_callback} = assigns) do
    assigns = assign(assigns, :value, value_callback.(selected_val))

    ~H"""
    <input
      id={if @multiple, do: Form.input_id(@form, @field, @value), else: Form.input_id(@form, @field)}
      name={Form.input_name(@form, @field) <> if @multiple, do: "[]", else: ""}
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
