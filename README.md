# SearchableSelect

Searchable multi/single select made for LiveView. Requires Tailwind to be set up in your project.

Requires Elixir 1.15+ and Phoenix LiveView 1.1+. Developed on Elixir 1.20 /
Erlang OTP 28 (see `.tool-versions`).

# Implementation

## Tailwind config
in tailwind.config.js add "../deps/searchable_select/lib/*.*ex", to the module.exports
```js
module.exports = {
    content: [
        "./js/**/*.js",
        "../lib/*_web.ex",
        "../lib/*_web/**/*.*ex",
        "../deps/searchable_select/lib/*.*ex",
    ],
```


## JS hooks
in app.js implement searchable select hooks

```js
import {SearchableSelect} from "../../deps/searchable_select/lib/hook.js"

Hooks.SearchableSelect = SearchableSelect
```

# Usage

Render the stateful component from a LiveView or another LiveComponent, and pass
an `on_select` callback to be told about selections:

```heex
<SearchableSelect.searchable_select
  id="customer-select"
  options={@customers}
  on_select={@on_customer_select}
/>
```

Assign the callback in `mount/3` rather than building it inline in `render/1`, so
LiveView's change tracking can see that it hasn't changed:

```elixir
def mount(_params, _session, socket) do
  view = self()
  {:ok, assign(socket, :on_customer_select, &send(view, {:customer_selected, &1}))}
end
```

The callback receives a list of the selected structs when `multiple` is set, and
a single struct (or `nil`) otherwise. Because it is a plain function, this works
the same whether the parent is a LiveView or another LiveComponent.

If you want to make the searchable select more integrated with your form and don't care about getting the whole struct (e.g. you have options like `[%{id: 1, name: "ABC", value: 25}]` and only want `25`) you can pass a form field instead:
```
    <SearchableSelect.searchable_select
      id="your-select"
      field={@form[:your_field]}
      options={@options}
    />
```
then whenever you select stuff it'll show up as part of params in your form's `handle_event` instead of via `on_select`

If you want to change how the labels are generated, you can add a callback, for example if you had a list of options like this:`[%{id: 1, network_name: "ABC", billing_type: "Prepaid"}, %{id: 2, network_name: "ABC", billing_type: "Contract"}]` you could add a callback like this:
```
    label_callback={fn item -> "#{item.network_name} - #{item.billing_type}" end}
```

A similar callback is available for generating values if you opt to go the form route (instead of `on_select`). You set it with `value_callback`:
```
    value_callback={fn item -> item.billing_type end}
```
