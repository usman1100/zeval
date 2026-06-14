defmodule ZevalWeb.PageView do
  use ZevalWeb, :view

  def code_block do
    Phoenix.HTML.raw("""
    <pre><span class="text-text-muted">// Define document relation graph</span>
    {
      <span class="text-emerald-success">"namespace"</span>: <span class="text-text-primary">"document"</span>,
      <span class="text-emerald-success">"relations"</span>: {
        <span class="text-emerald-success">"owner"</span>: { <span class="text-text-primary">"this"</span>: {} },
        <span class="text-emerald-success">"editor"</span>: {
          <span class="text-text-primary">"union"</span>: [
            { <span class="text-text-primary">"this"</span>: {} },
            { <span class="text-emerald-success">"computed_userset"</span>: { <span class="text-text-primary">"relation"</span>: <span class="text-text-primary">"owner"</span> } }
          ]
        },
        <span class="text-emerald-success">"viewer"</span>: {
          <span class="text-text-primary">"union"</span>: [
            { <span class="text-text-primary">"this"</span>: {} },
            { <span class="text-text-primary">"computed_userset"</span>: { <span class="text-text-primary">"relation"</span>: <span class="text-text-primary">"editor"</span> } },
            { <span class="text-emerald-success">"tuple_to_userset"</span>: {
                <span class="text-emerald-success">"tupleset_relation"</span>: <span class="text-text-primary">"parent"</span>,
                <span class="text-emerald-success">"computed_userset_relation"</span>: <span class="text-text-primary">"viewer"</span>
              }
            }
          ]
        }
      }
    }</pre>
    """)
  end
end
