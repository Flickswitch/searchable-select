# Changelog

## 0.2.0 (unreleased)

Upgrade to Phoenix LiveView 1.2 patterns. **This release contains breaking
changes to the component's API.**

### Breaking

- **Requires Elixir 1.15+, matching the floor `phoenix_live_view` itself
  declares.** The `phoenix_live_view` requirement is `~> 1.1`; CI runs the
  suite against both ends of that range and against Elixir 1.15, so neither
  bound is an untested claim. LiveView 1.0 is not supported:
  `Phoenix.LiveViewTest` still needed Floki there.

  Development happens on Elixir 1.20 / OTP 28, pinned in `.tool-versions`.
  That is a contributor toolchain, not a requirement on consumers.

- **`searchable_select/1` is now the only supported entry point.** Rendering the
  module directly bypasses the declared attributes and their defaults, so it
  will raise. Replace:

  ```heex
  <.live_component module={SearchableSelect} id="x" options={@options} />
  ```

  with:

  ```heex
  <SearchableSelect.searchable_select id="x" options={@options} />
  ```

- **`parent_key`, `send_change_events` and `send_search_events` are replaced by
  the `on_select` and `on_search` callbacks.** The component no longer messages
  the parent with `send(self(), ...)`, which only ever reached the root
  LiveView and so could not be used from inside another LiveComponent. Replace:

  ```heex
  <SearchableSelect.searchable_select id="x" options={@options} parent_key="customer" />
  ```

  ```elixir
  def handle_info({:select, "customer", selected}, socket), do: ...
  ```

  with:

  ```heex
  <SearchableSelect.searchable_select id="x" options={@options} on_select={@on_customer_select} />
  ```

  ```elixir
  # in mount/3, so change tracking can see the callback hasn't changed
  view = self()
  assign(socket, :on_customer_select, &send(view, {:select, "customer", &1}))
  ```

  That adapter is for a LiveView parent. From inside another LiveComponent,
  `send/2` still reaches the root LiveView rather than your component, so route
  with `send_update/2` and handle it in your own `update/2`:

  ```elixir
  # in mount/1
  myself = socket.assigns.myself
  assign(socket, :on_customer_select, &send_update(myself, customers: &1))
  ```

  The callback receives the same value the message used to carry: a list of
  structs for `multiple` selects, a single struct or `nil` otherwise. In form
  mode the callback is no longer gated behind a flag - pass `on_select` to
  receive changes, omit it to not. `field` and `on_select` are independent, so
  both can be used together. Form mode also no longer wraps the value of a
  single select in a list; it now matches non-form mode.

- **The `form` attribute is removed; `field` now takes a
  `Phoenix.HTML.FormField`.** Replace `form={f} field={:your_field}` with
  `field={f[:your_field]}`.

- **`preselected_id` and `preselected_ids` are replaced by `preselected`.**
  `multiple` already says whether one or many are expected, so the pair only
  created a way to disagree with it. `preselected` takes a single id or a list
  of them; in a single select, only the first match is used. Ids are compared
  as strings, so a value taken straight from params matches an integer id.

- **Preselection is applied on first render only.** It was previously
  re-evaluated on every parent update, which discarded the user's selection in
  a `multiple` select whenever the parent re-rendered the component with new
  assigns.

- **`sort_callback` and `sort_mapping_callback` are replaced by `sort_by`.**
  Pass a mapper function to sort ascending by its result, or `{mapper, sorter}`
  for any other order - the same shape `Enum.sort_by/3` takes. Replace
  `sort_mapping_callback={& &1.name} sort_callback={:desc}` with
  `sort_by={{& &1.name, :desc}}`.

- **`id_key` is removed.** Options were already required to have an `:id` -
  the search key is built from it regardless of what `id_key` was set to - so
  the attribute only renamed the key used to build DOM ids.

- **`grouper.group_by_fn` receives the option, not a `{key, option}` tuple.**
  The tuple was the component's internal representation leaking out. Replace
  `fn {_key, option}, group -> ... end` with `fn option, group -> ... end`.

### Fixed

- Crafted `select` and `pop` events with an unknown key no longer crash the
  LiveView process.
- Preselecting by an id that is not an integer - a UUID, say - no longer
  crashes. `preselected_id` used to call `String.to_integer/1` on it.
- Sorting by a mapper without also naming a direction no longer crashes.
  `sort_mapping_callback` without `sort_callback` reached `Enum.sort_by/3` with
  a `nil` sorter.
- Dropdown caret and remove-selection icons are sized again; Tailwind Preflight
  does not constrain `svg` the way it does `img`, so the intrinsic 20x20
  viewBox was rendering at the wrong size.

### Development

- `mix.lock` moves to `phoenix_live_view` 1.2.10, past the 1.2.7 pinned by
  EEF-CVE-2026-64941 (`validate_local_url!/2` open redirect, LOW). This library
  does not call the affected function, and the advisory does not narrow the
  `~> 1.1` requirement - consumers resolve their own version - but the suite
  should not be verified against a package with an open advisory.

### Removed

- `aria-expanded` on the search input. It was set on an implicit `role=textbox`,
  which does not support the attribute. Proper combobox semantics are tracked
  separately.

## 0.1.0

Initial release.
