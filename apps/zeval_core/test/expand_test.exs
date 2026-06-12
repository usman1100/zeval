defmodule ZevalCore.ExpandTest do
  use ExUnit.Case, async: false

  alias ZevalCore.{Repo, Expand, Namespace, Tuples}
  alias ZevalCore.Tuples.Tuple
  alias ZevalCore.Namespace.Cache
  alias Ecto.UUID

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
    Cache.flush_all()

    tenant_id = UUID.generate()
    tenant_bin = Ecto.UUID.dump!(tenant_id)

    Repo.insert_all("tenants", [
      %{id: tenant_bin, name: "expand-test-#{System.unique_integer([:positive])}"}
    ])

    on_exit(fn ->
      Repo.delete_all(Tuples.RelationTuple)
      Repo.delete_all(ZevalCore.Namespace.NamespaceConfig)
      Repo.delete_all("tenants")
      Cache.flush_all()
    end)

    {:ok, tenant_id: tenant_id}
  end

  defp users(tree), do: tree.users |> Enum.sort()

  describe "this rule" do
    setup %{tenant_id: tid} do
      Namespace.write(tid, %{"name" => "doc", "relations" => %{"viewer" => %{"this" => %{}}}})

      Tuples.write(tid, [
        %Tuple{
          namespace: "doc",
          object_id: "readme",
          relation: "viewer",
          subject: {:user, "alice"}
        },
        %Tuple{
          namespace: "doc",
          object_id: "readme",
          relation: "viewer",
          subject: {:user, "bob"}
        },
        %Tuple{
          namespace: "doc",
          object_id: "other",
          relation: "viewer",
          subject: {:user, "carol"}
        }
      ])

      :ok
    end

    test "returns the direct users for the object", %{tenant_id: tid} do
      tree = Expand.expand(tid, "doc", "readme", "viewer")
      assert users(tree) == ["alice", "bob"]
    end

    test "excludes users on other objects", %{tenant_id: tid} do
      tree = Expand.expand(tid, "doc", "other", "viewer")
      assert users(tree) == ["carol"]
    end

    test "empty when no tuples", %{tenant_id: tid} do
      tree = Expand.expand(tid, "doc", "missing", "viewer")
      assert tree.users == []
    end
  end

  describe "computed_userset rule" do
    setup %{tenant_id: tid} do
      Namespace.write(tid, %{
        "name" => "doc",
        "relations" => %{
          "viewer" => %{"computed_userset" => %{"relation" => "editor"}},
          "editor" => %{"this" => %{}}
        }
      })

      Tuples.write(tid, [
        %Tuple{
          namespace: "doc",
          object_id: "readme",
          relation: "editor",
          subject: {:user, "alice"}
        }
      ])

      :ok
    end

    test "follows the computed relation", %{tenant_id: tid} do
      tree = Expand.expand(tid, "doc", "readme", "viewer")
      assert users(tree) == ["alice"]
    end
  end

  describe "union rule" do
    setup %{tenant_id: tid} do
      Namespace.write(tid, %{
        "name" => "doc",
        "relations" => %{
          "viewer" => %{
            "union" => [%{"this" => %{}}, %{"computed_userset" => %{"relation" => "editor"}}]
          },
          "editor" => %{"this" => %{}}
        }
      })

      Tuples.write(tid, [
        %Tuple{
          namespace: "doc",
          object_id: "readme",
          relation: "viewer",
          subject: {:user, "alice"}
        },
        %Tuple{namespace: "doc", object_id: "readme", relation: "editor", subject: {:user, "bob"}}
      ])

      :ok
    end

    test "unions users from all branches", %{tenant_id: tid} do
      tree = Expand.expand(tid, "doc", "readme", "viewer")
      assert users(tree) == ["alice", "bob"]
    end
  end

  describe "intersection rule" do
    setup %{tenant_id: tid} do
      Namespace.write(tid, %{
        "name" => "doc",
        "relations" => %{
          "viewer" => %{
            "intersection" => [
              %{"computed_userset" => %{"relation" => "a"}},
              %{"computed_userset" => %{"relation" => "b"}}
            ]
          },
          "a" => %{"this" => %{}},
          "b" => %{"this" => %{}}
        }
      })

      Tuples.write(tid, [
        %Tuple{namespace: "doc", object_id: "x", relation: "a", subject: {:user, "alice"}},
        %Tuple{namespace: "doc", object_id: "x", relation: "a", subject: {:user, "bob"}},
        %Tuple{namespace: "doc", object_id: "x", relation: "b", subject: {:user, "bob"}}
      ])

      :ok
    end

    test "returns only users in every branch", %{tenant_id: tid} do
      tree = Expand.expand(tid, "doc", "x", "viewer")
      assert users(tree) == ["bob"]
    end
  end

  describe "exclusion rule" do
    setup %{tenant_id: tid} do
      Namespace.write(tid, %{
        "name" => "doc",
        "relations" => %{
          "viewer" => %{
            "exclusion" => %{
              "base" => %{"computed_userset" => %{"relation" => "a"}},
              "subtract" => %{"computed_userset" => %{"relation" => "banned"}}
            }
          },
          "a" => %{"this" => %{}},
          "banned" => %{"this" => %{}}
        }
      })

      Tuples.write(tid, [
        %Tuple{namespace: "doc", object_id: "x", relation: "a", subject: {:user, "alice"}},
        %Tuple{namespace: "doc", object_id: "x", relation: "a", subject: {:user, "bob"}},
        %Tuple{namespace: "doc", object_id: "x", relation: "banned", subject: {:user, "bob"}}
      ])

      :ok
    end

    test "subtracts the excluded users", %{tenant_id: tid} do
      tree = Expand.expand(tid, "doc", "x", "viewer")
      assert users(tree) == ["alice"]
    end
  end

  describe "tuple_to_userset rule" do
    setup %{tenant_id: tid} do
      # doc:readme has a parent folder:root via "parent"; folder viewers can view the doc.
      Namespace.write(tid, %{
        "name" => "doc",
        "relations" => %{
          "viewer" => %{
            "tuple_to_userset" => %{
              "tupleset_relation" => "parent",
              "computed_userset_relation" => "viewer"
            }
          },
          "parent" => %{"this" => %{}}
        }
      })

      Namespace.write(tid, %{
        "name" => "folder",
        "relations" => %{"viewer" => %{"this" => %{}}}
      })

      Tuples.write(tid, [
        %Tuple{
          namespace: "doc",
          object_id: "readme",
          relation: "parent",
          subject: {:userset, "folder", "root", "..."}
        },
        %Tuple{
          namespace: "folder",
          object_id: "root",
          relation: "viewer",
          subject: {:user, "alice"}
        }
      ])

      :ok
    end

    test "expands through the parent userset", %{tenant_id: tid} do
      tree = Expand.expand(tid, "doc", "readme", "viewer")
      assert "alice" in tree.users
    end
  end

  describe "safety limits" do
    test "cycle between relations terminates and returns no users", %{tenant_id: tid} do
      # Build a config that the validator would reject for cycles, so insert the
      # raw record directly to exercise Expand's runtime cycle guard.
      cyclic = %{
        "name" => "doc",
        "relations" => %{
          "viewer" => %{"computed_userset" => %{"relation" => "editor"}},
          "editor" => %{"computed_userset" => %{"relation" => "viewer"}}
        }
      }

      tenant_bin = Ecto.UUID.dump!(tid)

      Repo.insert_all("namespace_configs", [
        %{
          id: Ecto.UUID.bingenerate(),
          tenant_id: tenant_bin,
          name: "doc",
          config: cyclic,
          version: 1
        }
      ])

      Cache.flush_all()

      tree = Expand.expand(tid, "doc", "readme", "viewer")
      assert tree.users == []
    end

    test "unknown namespace returns an empty leaf", %{tenant_id: tid} do
      tree = Expand.expand(tid, "nope", "x", "viewer")
      assert tree.users == []
    end
  end
end
