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

  The callback receives the same value the message used to carry: a list of
  structs for `multiple` selects, a single struct or `nil` otherwise. In form
  mode the callback is no longer gated behind a flag - pass `on_select` to
  receive changes, omit it to not. Form mode also no longer wraps the value of a
  single select in a list; it now matches non-form mode.

- **The `form` attribute is removed; `field` now takes a
  `Phoenix.HTML.FormField`.** Replace `form={f} field={:your_field}` with
  `field={f[:your_field]}`.

- **Preselection is applied on first render only.** `preselected_id` and
  `preselected_ids` were previously re-evaluated on every parent update, which
  discarded the user's selection in a `multiple` select whenever the parent
  re-rendered the component with new assigns.

### Fixed

- Crafted `select` and `pop` events with an unknown key no longer crash the
  LiveView process.
- Dropdown caret and remove-selection icons are sized again; Tailwind Preflight
  does not constrain `svg` the way it does `img`, so the intrinsic 20x20
  viewBox was rendering at the wrong size.

### Removed

- `aria-expanded` on the search input. It was set on an implicit `role=textbox`,
  which does not support the attribute. Proper combobox semantics are tracked
  separately.

## 0.1.0

Initial release.
