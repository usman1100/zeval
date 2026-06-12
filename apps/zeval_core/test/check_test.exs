defmodule ZevalCore.CheckTest do
  use ExUnit.Case, async: false

  alias ZevalCore.{Repo, Check, Namespace, Tuples}
  alias ZevalCore.Tuples.Tuple
  alias ZevalCore.Namespace.Cache
  alias Ecto.UUID

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
    Cache.flush_all()

    tenant_id = UUID.generate()
    tenant_bin = Ecto.UUID.dump!(tenant_id)

    Repo.insert_all("tenants", [
      %{id: tenant_bin, name: "check-test-#{System.unique_integer([:positive])}"}
    ])

    on_exit(fn ->
      Repo.delete_all(Tuples.RelationTuple)
      Repo.delete_all(ZevalCore.Namespace.NamespaceConfig)
      Repo.delete_all("tenants")
      Cache.flush_all()
    end)

    {:ok, tenant_id: tenant_id}
  end

  # ============================================================================
  # this rule
  # ============================================================================

  describe "this rule" do
    setup %{tenant_id: tid} do
      Namespace.write(tid, %{
        "name" => "doc",
        "relations" => %{
          "viewer" => %{"this" => %{}}
        }
      })

      Tuples.write(tid, [
        %Tuple{
          namespace: "doc",
          object_id: "readme",
          relation: "viewer",
          subject: {:user, "alice"}
        }
      ])

      :ok
    end

    test "allows when direct tuple exists", %{tenant_id: tid} do
      result = Check.check(tid, "doc", "readme", "viewer", {:user, "alice"})
      assert result.allowed == true
      assert length(result.path) > 0
    end

    test "denies when direct tuple does not exist", %{tenant_id: tid} do
      result = Check.check(tid, "doc", "readme", "viewer", {:user, "bob"})
      assert result.allowed == false
    end

    test "denies for different object", %{tenant_id: tid} do
      result = Check.check(tid, "doc", "other", "viewer", {:user, "alice"})
      assert result.allowed == false
    end
  end

  # ============================================================================
  # computed_userset rule
  # ============================================================================

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

    test "allows when computed_userset chain resolves", %{tenant_id: tid} do
      result = Check.check(tid, "doc", "readme", "viewer", {:user, "alice"})
      assert result.allowed == true
    end

    test "denies when computed_userset chain does not resolve", %{tenant_id: tid} do
      result = Check.check(tid, "doc", "readme", "viewer", {:user, "bob"})
      assert result.allowed == false
    end

    test "resolution path includes computed_userset step", %{tenant_id: tid} do
      result = Check.check(tid, "doc", "readme", "viewer", {:user, "alice"})

      # The path should have at least the computed_userset step and the this step
      path_rules = Enum.map(result.path, & &1.rule)
      assert "computed_userset" in path_rules
      assert "this" in path_rules
    end
  end

  # ============================================================================
  # tuple_to_userset rule
  # ============================================================================

  describe "tuple_to_userset rule" do
    setup %{tenant_id: tid} do
      Namespace.write(tid, %{
        "name" => "doc",
        "relations" => %{
          "viewer" => %{
            "tuple_to_userset" => %{
              "tupleset_relation" => "parent",
              "computed_userset_relation" => "viewer"
            }
          }
        }
      })

      Namespace.write(tid, %{
        "name" => "folder",
        "relations" => %{
          "viewer" => %{"this" => %{}}
        }
      })

      # doc:readme has parent folder:eng
      Tuples.write(tid, [
        %Tuple{
          namespace: "doc",
          object_id: "readme",
          relation: "parent",
          subject: {:userset, "folder", "eng", "member"}
        }
      ])

      # alice is a viewer of folder:eng
      Tuples.write(tid, [
        %Tuple{
          namespace: "folder",
          object_id: "eng",
          relation: "viewer",
          subject: {:user, "alice"}
        }
      ])

      :ok
    end

    test "allows when parent's computed_userset resolves", %{tenant_id: tid} do
      result = Check.check(tid, "doc", "readme", "viewer", {:user, "alice"})
      assert result.allowed == true
    end

    test "denies when parent's computed_userset does not resolve", %{tenant_id: tid} do
      result = Check.check(tid, "doc", "readme", "viewer", {:user, "bob"})
      assert result.allowed == false
    end
  end

  # ============================================================================
  # union rule
  # ============================================================================

  describe "union rule" do
    setup %{tenant_id: tid} do
      Namespace.write(tid, %{
        "name" => "doc",
        "relations" => %{
          "viewer" => %{
            "union" => [
              %{"this" => %{}},
              %{"computed_userset" => %{"relation" => "editor"}}
            ]
          },
          "editor" => %{"this" => %{}}
        }
      })

      :ok
    end

    test "allows via direct tuple (first branch)", %{tenant_id: tid} do
      Tuples.write(tid, [
        %Tuple{namespace: "doc", object_id: "x", relation: "viewer", subject: {:user, "alice"}}
      ])

      result = Check.check(tid, "doc", "x", "viewer", {:user, "alice"})
      assert result.allowed == true
    end

    test "allows via computed_userset (second branch)", %{tenant_id: tid} do
      Tuples.write(tid, [
        %Tuple{namespace: "doc", object_id: "x", relation: "editor", subject: {:user, "alice"}}
      ])

      result = Check.check(tid, "doc", "x", "viewer", {:user, "alice"})
      assert result.allowed == true
    end

    test "denies when neither branch matches", %{tenant_id: tid} do
      result = Check.check(tid, "doc", "x", "viewer", {:user, "alice"})
      assert result.allowed == false
    end
  end

  # ============================================================================
  # intersection rule
  # ============================================================================

  describe "intersection rule" do
    setup %{tenant_id: tid} do
      Namespace.write(tid, %{
        "name" => "doc",
        "relations" => %{
          "viewer" => %{
            "intersection" => [
              %{"this" => %{}},
              %{"computed_userset" => %{"relation" => "trusted"}}
            ]
          },
          "trusted" => %{"this" => %{}}
        }
      })

      :ok
    end

    test "allows when both conditions are met", %{tenant_id: tid} do
      Tuples.write(tid, [
        %Tuple{namespace: "doc", object_id: "x", relation: "viewer", subject: {:user, "alice"}},
        %Tuple{namespace: "doc", object_id: "x", relation: "trusted", subject: {:user, "alice"}}
      ])

      result = Check.check(tid, "doc", "x", "viewer", {:user, "alice"})
      assert result.allowed == true
    end

    test "denies when only first condition is met", %{tenant_id: tid} do
      Tuples.write(tid, [
        %Tuple{namespace: "doc", object_id: "x", relation: "viewer", subject: {:user, "alice"}}
      ])

      result = Check.check(tid, "doc", "x", "viewer", {:user, "alice"})
      assert result.allowed == false
    end

    test "denies when only second condition is met", %{tenant_id: tid} do
      Tuples.write(tid, [
        %Tuple{namespace: "doc", object_id: "x", relation: "trusted", subject: {:user, "alice"}}
      ])

      result = Check.check(tid, "doc", "x", "viewer", {:user, "alice"})
      assert result.allowed == false
    end

    test "denies when neither condition is met", %{tenant_id: tid} do
      result = Check.check(tid, "doc", "x", "viewer", {:user, "alice"})
      assert result.allowed == false
    end
  end

  # ============================================================================
  # exclusion rule
  # ============================================================================

  describe "exclusion rule" do
    setup %{tenant_id: tid} do
      Namespace.write(tid, %{
        "name" => "doc",
        "relations" => %{
          "viewer" => %{
            "exclusion" => %{
              "base" => %{"this" => %{}},
              "subtract" => %{"computed_userset" => %{"relation" => "blocked"}}
            }
          },
          "blocked" => %{"this" => %{}}
        }
      })

      :ok
    end

    test "allows when base matches and subtract does not", %{tenant_id: tid} do
      Tuples.write(tid, [
        %Tuple{namespace: "doc", object_id: "x", relation: "viewer", subject: {:user, "alice"}}
      ])

      result = Check.check(tid, "doc", "x", "viewer", {:user, "alice"})
      assert result.allowed == true
    end

    test "denies when base matches and subtract also matches", %{tenant_id: tid} do
      Tuples.write(tid, [
        %Tuple{namespace: "doc", object_id: "x", relation: "viewer", subject: {:user, "alice"}},
        %Tuple{namespace: "doc", object_id: "x", relation: "blocked", subject: {:user, "alice"}}
      ])

      result = Check.check(tid, "doc", "x", "viewer", {:user, "alice"})
      assert result.allowed == false
    end

    test "denies when base does not match", %{tenant_id: tid} do
      result = Check.check(tid, "doc", "x", "viewer", {:user, "alice"})
      assert result.allowed == false
    end
  end

  # ============================================================================
  # 3-level hierarchy integration
  # ============================================================================

  describe "3-level hierarchy (user → group → folder → doc)" do
    setup %{tenant_id: tid} do
      # user is member of group
      Namespace.write(tid, %{
        "name" => "group",
        "relations" => %{
          "member" => %{"this" => %{}}
        }
      })

      # folder: viewer = tuple_to_userset(parent, member) where parent is a group.
      # So members of the parent group become viewers of the folder.
      Namespace.write(tid, %{
        "name" => "folder",
        "relations" => %{
          "viewer" => %{
            "tuple_to_userset" => %{
              "tupleset_relation" => "parent",
              "computed_userset_relation" => "member"
            }
          },
          "parent" => %{"this" => %{}}
        }
      })

      # doc: viewer = tuple_to_userset(parent, viewer) where parent is a folder
      Namespace.write(tid, %{
        "name" => "doc",
        "relations" => %{
          "viewer" => %{
            "tuple_to_userset" => %{
              "tupleset_relation" => "parent",
              "computed_userset_relation" => "viewer"
            }
          }
        }
      })

      # alice is member of group:eng
      Tuples.write(tid, [
        %Tuple{
          namespace: "group",
          object_id: "eng",
          relation: "member",
          subject: {:user, "alice"}
        }
      ])

      # folder:project has parent group:eng — so members of eng are viewers of project
      Tuples.write(tid, [
        %Tuple{
          namespace: "folder",
          object_id: "project",
          relation: "parent",
          subject: {:userset, "group", "eng", "member"}
        }
      ])

      # doc:readme has parent folder:project — so viewers of project are viewers of readme
      Tuples.write(tid, [
        %Tuple{
          namespace: "doc",
          object_id: "readme",
          relation: "parent",
          subject: {:userset, "folder", "project", "member"}
        }
      ])

      :ok
    end

    test "alice can view doc:readme through 3-level chain", %{tenant_id: tid} do
      result = Check.check(tid, "doc", "readme", "viewer", {:user, "alice"})
      assert result.allowed == true
    end

    test "bob cannot view doc:readme (not in group)", %{tenant_id: tid} do
      result = Check.check(tid, "doc", "readme", "viewer", {:user, "bob"})
      assert result.allowed == false
    end

    test "resolution path is returned for the 3-level check", %{tenant_id: tid} do
      result = Check.check(tid, "doc", "readme", "viewer", {:user, "alice"})
      assert result.allowed == true
      assert length(result.path) > 0

      # The path should contain various rule types
      path_rules = Enum.map(result.path, & &1.rule)
      assert "tuple_to_userset" in path_rules
    end
  end

  # ============================================================================
  # Runtime cycle detection (through tuple store, not config relations)
  # ============================================================================

  describe "runtime cycle detection" do
    setup %{tenant_id: tid} do
      # Self-referential tuple_to_userset: doc:viewer resolves by finding
      # parent tuples and checking viewer on each parent. If a tuple's
      # parent is itself, we get a runtime cycle.
      write_result =
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

      assert {:ok, _} = write_result, "write failed: #{inspect(write_result)}"

      # Create a self-referential tuple: doc:x has parent doc:x#viewer
      # This creates a runtime cycle because resolving viewer on doc:x
      # will look at parent tuples, find this one, and recurse on doc:x#viewer
      Tuples.write(tid, [
        %Tuple{
          namespace: "doc",
          object_id: "x",
          relation: "parent",
          subject: {:userset, "doc", "x", "viewer"}
        }
      ])

      :ok
    end

    test "returns false with cycle in path on runtime cycle", %{tenant_id: tid} do
      assert {:ok, _} = Namespace.get(tid, "doc"), "config not found"
      result = Check.check(tid, "doc", "x", "viewer", {:user, "alice"})
      assert result.allowed == false
      path_rules = Enum.map(result.path, & &1.rule)
      assert "cycle" in path_rules
    end
  end

  # ============================================================================
  # Edge cases
  # ============================================================================

  describe "edge cases" do
    setup %{tenant_id: tid} do
      Namespace.write(tid, %{
        "name" => "doc",
        "relations" => %{
          "viewer" => %{"this" => %{}}
        }
      })

      :ok
    end

    test "undefined namespace returns false", %{tenant_id: tid} do
      result = Check.check(tid, "nonexistent", "x", "viewer", {:user, "alice"})
      assert result.allowed == false
    end

    test "undefined relation returns false", %{tenant_id: tid} do
      result = Check.check(tid, "doc", "x", "nonexistent", {:user, "alice"})
      assert result.allowed == false
    end
  end
end
