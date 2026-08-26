defmodule SearchableSelect.TestComponent do
  @moduledoc """
  Fixture for the LiveComponent routing adapter.

  Renders a searchable select from inside another LiveComponent and routes the
  selection back to itself with `send_update(@myself, ...)`, which lands in this
  module's `update/2`. This is the case that the old `send(self(), ...)`
  messaging could not support, because the message reached the root LiveView
  rather than the containing component.
  """
  use Phoenix.LiveComponent

  @impl true
  def mount(socket) do
    myself = socket.assigns.myself

    socket
    |> assign(:nested_selected, [])
    |> assign(:on_select, &send_update(myself, nested_selected: &1))
    |> then(&{:ok, &1})
  end

  @impl true
  # routed back from the select via send_update/2
  def update(%{nested_selected: nested_selected}, socket) do
    {:ok, assign(socket, :nested_selected, nested_selected)}
  end

  def update(assigns, socket) do
    {:ok, assign(socket, assigns)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <SearchableSelect.searchable_select
        id="nested_multi"
        multiple
        options={@options}
        on_select={@on_select}
      />
      <span id="nested-selected-options">{inspect(Enum.map(@nested_selected, & &1.id))}</span>
    </div>
    """
  end
end
