defmodule ZevalWeb.CheckController do
  use ZevalWeb, :controller

  alias ZevalCore.Check

  def check(conn, %{"namespace" => ns, "object_id" => oid, "relation" => rel, "subject" => raw_subject}) do
    tenant_id = conn.assigns.tenant_id
    subject = parse_subject(raw_subject)
    opts = if conn.params["zookie"], do: [consistency: conn.params["zookie"]], else: []

    result = Check.check(tenant_id, ns, oid, rel, subject, opts)

    json(conn, %{
      allowed: result.allowed,
      zookie: conn.params["zookie"],
      resolution_path: result.path
    })
  end

  def check(conn, _) do
    ZevalWeb.JsonHelpers.bad_request(
      conn,
      "namespace, object_id, relation, and subject are required"
    )
  end

  defp parse_subject(subject) when is_binary(subject), do: {:user, subject}
  defp parse_subject(%{"type" => "user", "id" => uid}), do: {:user, uid}
  defp parse_subject(%{"type" => "userset", "namespace" => ns, "object_id" => oid, "relation" => rel}),
    do: {:userset, ns, oid, rel}
  defp parse_subject(_), do: {:user, ""}
end