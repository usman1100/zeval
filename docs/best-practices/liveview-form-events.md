# LiveView: `phx-change` requires a wrapping `<form>`

A short post-mortem and the rule it leaves behind. Lives here because we hit
this in the Tuples, Check, and Expand dashboard tools and it cost real
debugging time.

## Symptom

On the Tuples tool, selecting a tenant from the dropdown appeared to work, but
**as soon as you typed into any field, the dropdown snapped back to "Select a
tenant."** The browser console showed:

```
Uncaught Error: form events require the input to be inside a form
    at _View.pushInput (phoenix_live_view.js:...)
```

## Root cause

The tenant selector was a bare element:

```heex
<select name="tenant_id" phx-change="select_tenant">
  ...
</select>
```

`phx-change` (and `phx-submit`) are **form bindings**. LiveView requires the
element to be inside a `<form>`. When it isn't, `pushInput` throws client-side
and **the event never reaches the server** — so `select_tenant` never ran and
`selected_tenant_id` stayed `""`.

Why it *looked* selected at first, then reset:

1. Picking an option changes the native `<select>` value in the browser — purely
   client-side, no server involved.
2. The text inputs used `phx-keyup`, which is a **key event, not a form event**,
   so it has no form requirement and worked fine.
3. The first keystroke pushed a real event, the server re-rendered, and the
   re-render produced the `<select>` with `selected_tenant_id` still `""` — so
   morphdom patched the dropdown back to "Select a tenant".

The reset wasn't a rendering bug — the server never knew a tenant was chosen.

## Why our test didn't catch it

A LiveView test that calls `render_change/2` invokes the server handler
**directly** and bypasses the client-side "must be in a form" guard. So a
green server-side test can still ship a feature that is broken in the browser.
The console error is the source of truth for this class of bug.

## Fix

Wrap the control in a `<form>` and move `phx-change` onto it. Give the form a
stable `id` (LiveView wants one; it also silences the `missing_form_id` test
warning):

```heex
<form id="tenant-form" phx-change="select_tenant" class="relative">
  <select name="tenant_id">
    <option value="">Select a tenant</option>
    <%= for t <- @tenants do %>
      <option value={t.id} selected={@selected_tenant_id == t.id}>{t.name}</option>
    <% end %>
  </select>
</form>
```

The handler is unchanged — a form `phx-change` serializes the named inputs, so
`%{"tenant_id" => id}` still matches:

```elixir
def handle_event("select_tenant", %{"tenant_id" => id}, socket) do
  {:noreply, assign(socket, selected_tenant_id: id, ...)}
end
```

Fixed in `tuple_live.ex`, `check_live.ex`, and `expand_live.ex` — all three
shared the bare-`<select>` pattern.

## The rules

- **`phx-change` / `phx-submit` → must be inside a `<form>`.** This includes a
  lone `<select>` or `<input>`. If it's not in a form, the event silently dies
  client-side with a console error.
- **`phx-click`, `phx-keyup`, `phx-keydown`, `phx-blur`, `phx-focus`** are not
  form events and do **not** require a form.
- **Give forms a stable `id`** so morphdom can match the node across patches and
  so tests don't warn.
- **Watch the browser console** when a LiveView interaction "resets" or silently
  does nothing — a thrown JS error means the event never reached the server, and
  no server-side test will reproduce it.
