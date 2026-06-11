defmodule ZevalCore.NamespaceTest do
  use ExUnit.Case, async: false

  alias ZevalCore.{Repo, Namespace}
  alias ZevalCore.Namespace.Cache
  alias Ecto.UUID

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
    Cache.flush_all()

    # Create a tenant first — namespace configs reference it
    tenant_id = UUID.generate()
    tenant_bin = Ecto.UUID.dump!(tenant_id)
    Repo.insert_all("tenants", [%{id: tenant_bin, name: "test-tenant-#{System.unique_integer([:positive])}"}])

    on_exit(fn ->
      Repo.delete_all(ZevalCore.Namespace.NamespaceConfig)
      Repo.delete_all("tenants")
      Cache.flush_all()
    end)

    {:ok, tenant_id: tenant_id}
  end

  defp valid_doc_config do
    %{
      "name" => "doc",
      "relations" => %{
        "viewer" => %{
          "union" => [
            %{"this" => %{}},
            %{"computed_userset" => %{"relation" => "editor"}}
          ]
        },
        "editor" => %{
          "union" => [
            %{"this" => %{}},
            %{"computed_userset" => %{"relation" => "owner"}}
          ]
        },
        "owner" => %{"this" => %{}}
      }
    }
  end

  describe "write/2" do
    test "writes a valid namespace config", %{tenant_id: tid} do
      assert {:ok, config} = Namespace.write(tid, valid_doc_config())
      assert config.name == "doc"
      assert config.version == 1
      assert config.tenant_id == tid
      assert is_map(config.config)
    end

    test "updates existing config and bumps version", %{tenant_id: tid} do
      assert {:ok, v1} = Namespace.write(tid, valid_doc_config())
      assert v1.version == 1

      assert {:ok, v2} = Namespace.write(tid, valid_doc_config())
      assert v2.version == 2
      assert v2.id == v1.id
    end

    test "rejects invalid config", %{tenant_id: tid} do
      assert {:error, _} = Namespace.write(tid, %{"relations" => %{}})
    end

    test "rejects cycle", %{tenant_id: tid} do
      cycle = %{
        "name" => "cycle",
        "relations" => %{
          "a" => %{"computed_userset" => %{"relation" => "b"}},
          "b" => %{"computed_userset" => %{"relation" => "a"}}
        }
      }

      assert {:error, reason} = Namespace.write(tid, cycle)
      assert reason =~ "circular"
    end
  end

  describe "get/2" do
    test "returns written config", %{tenant_id: tid} do
      Namespace.write(tid, valid_doc_config())
      assert {:ok, config} = Namespace.get(tid, "doc")
      assert config.name == "doc"
    end

    test "returns not_found for missing config", %{tenant_id: tid} do
      assert {:error, :not_found} = Namespace.get(tid, "nonexistent")
    end

    test "caches on read and hits ETS on second call", %{tenant_id: tid} do
      {:ok, _} = Namespace.write(tid, valid_doc_config())
      Cache.flush_all()

      assert {:ok, config1} = Namespace.get(tid, "doc")

      cached = Cache.get(tid, "doc")
      assert cached != nil

      Repo.delete_all(ZevalCore.Namespace.NamespaceConfig)

      assert {:ok, config2} = Namespace.get(tid, "doc")
      assert config2.name == "doc"
      assert config2.id == config1.id
    end
  end

  describe "list/1" do
    test "lists all configs for tenant", %{tenant_id: tid} do
      Namespace.write(tid, valid_doc_config())

      group_config = %{
        "name" => "group",
        "relations" => %{
          "member" => %{"this" => %{}}
        }
      }

      Namespace.write(tid, group_config)

      configs = Namespace.list(tid)
      assert length(configs) == 2
      names = Enum.map(configs, & &1.name) |> Enum.sort()
      assert names == ["doc", "group"]
    end

    test "returns empty list for tenant with no configs", %{tenant_id: tid} do
      assert Namespace.list(tid) == []
    end

    test "only returns configs for the specified tenant", %{tenant_id: tid} do
      Namespace.write(tid, valid_doc_config())

      other_tid = UUID.generate()
      other_bin = Ecto.UUID.dump!(other_tid)
      Repo.insert_all("tenants", [%{id: other_bin, name: "other-tenant-#{System.unique_integer([:positive])}"}])

      Namespace.write(other_tid, %{
        "name" => "other",
        "relations" => %{"x" => %{"this" => %{}}}
      })

      configs = Namespace.list(tid)
      assert length(configs) == 1
      assert hd(configs).name == "doc"
    end
  end

  describe "delete/2" do
    test "deletes a config", %{tenant_id: tid} do
      Namespace.write(tid, valid_doc_config())
      assert :ok = Namespace.delete(tid, "doc")
      assert {:error, :not_found} = Namespace.get(tid, "doc")
    end

    test "removes from cache on delete", %{tenant_id: tid} do
      {:ok, _} = Namespace.write(tid, valid_doc_config())
      {:ok, _} = Namespace.get(tid, "doc")
      assert Cache.get(tid, "doc") != nil

      Namespace.delete(tid, "doc")
      assert Cache.get(tid, "doc") == nil
    end

    test "returns error for nonexistent", %{tenant_id: tid} do
      assert {:error, :not_found} = Namespace.delete(tid, "nonexistent")
    end
  end
end
