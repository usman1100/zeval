defmodule ZevalCore.TuplesTest do
  use ExUnit.Case, async: false

  alias ZevalCore.{Repo, Tuples}
  alias ZevalCore.Tuples.{Tuple, Zookie}
  alias ZevalCore.Namespace.Cache
  alias Ecto.UUID

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
    Cache.flush_all()

    tenant_id = UUID.generate()
    tenant_bin = Ecto.UUID.dump!(tenant_id)
    Repo.insert_all("tenants", [%{id: tenant_bin, name: "tuple-test-#{System.unique_integer([:positive])}"}])

    # Write a basic namespace config so tuple operations make sense later
    # (not strictly needed for tuples itself, but check tests need it)

    on_exit(fn ->
      Repo.delete_all(Tuples.RelationTuple)
      Repo.delete_all("tenants")
      Cache.flush_all()
    end)

    {:ok, tenant_id: tenant_id}
  end

  describe "write/2" do
    test "writes a single user tuple", %{tenant_id: tid} do
      tuple = %Tuple{namespace: "doc", object_id: "readme", relation: "viewer", subject: {:user, "alice"}}
      assert {:ok, result} = Tuples.write(tid, [tuple])
      assert result.written == 1
      assert String.starts_with?(result.zookie, "zookie:")
    end

    test "writes a userset tuple", %{tenant_id: tid} do
      tuple = %Tuple{namespace: "doc", object_id: "readme", relation: "viewer", subject: {:userset, "group", "eng", "member"}}
      assert {:ok, result} = Tuples.write(tid, [tuple])
      assert result.written == 1
    end

    test "writes multiple tuples in one call", %{tenant_id: tid} do
      tuples = [
        %Tuple{namespace: "doc", object_id: "readme", relation: "viewer", subject: {:user, "alice"}},
        %Tuple{namespace: "doc", object_id: "readme", relation: "viewer", subject: {:user, "bob"}}
      ]

      assert {:ok, result} = Tuples.write(tid, tuples)
      assert result.written == 2
    end
  end

  describe "read/3" do
    setup %{tenant_id: tid} do
      Tuples.write(tid, [
        %Tuple{namespace: "doc", object_id: "readme", relation: "viewer", subject: {:user, "alice"}},
        %Tuple{namespace: "doc", object_id: "readme", relation: "viewer", subject: {:user, "bob"}},
        %Tuple{namespace: "doc", object_id: "readme", relation: "editor", subject: {:user, "alice"}},
        %Tuple{namespace: "org", object_id: "acme", relation: "member", subject: {:user, "carol"}}
      ])

      :ok
    end

    test "reads all tuples for a tenant", %{tenant_id: tid} do
      results = Tuples.read(tid)
      assert length(results) == 4
    end

    test "filters by namespace", %{tenant_id: tid} do
      results = Tuples.read(tid, %{namespace: "doc"})
      assert length(results) == 3
    end

    test "filters by namespace and object_id", %{tenant_id: tid} do
      results = Tuples.read(tid, %{namespace: "doc", object_id: "readme"})
      assert length(results) == 3
    end

    test "filters by namespace, object_id, and relation", %{tenant_id: tid} do
      results = Tuples.read(tid, %{namespace: "doc", object_id: "readme", relation: "editor"})
      assert length(results) == 1
      assert hd(results).subject == {:user, "alice"}
    end

    test "filters by subject (user)", %{tenant_id: tid} do
      results = Tuples.read(tid, %{subject: {:user, "alice"}})
      assert length(results) == 2
    end

    test "filters by subject (string user_id)", %{tenant_id: tid} do
      results = Tuples.read(tid, %{subject: "alice"})
      assert length(results) == 2
    end

    test "returns empty list for non-matching filter", %{tenant_id: tid} do
      results = Tuples.read(tid, %{namespace: "nonexistent"})
      assert results == []
    end
  end

  describe "delete/2" do
    setup %{tenant_id: tid} do
      Tuples.write(tid, [
        %Tuple{namespace: "doc", object_id: "readme", relation: "viewer", subject: {:user, "alice"}},
        %Tuple{namespace: "doc", object_id: "readme", relation: "viewer", subject: {:user, "bob"}}
      ])

      :ok
    end

    test "soft-deletes a tuple", %{tenant_id: tid} do
      assert {:ok, result} = Tuples.delete(tid, [
        %Tuple{namespace: "doc", object_id: "readme", relation: "viewer", subject: {:user, "alice"}}
      ])

      assert result.deleted == 1
    end

    test "deleted tuple no longer appears in reads", %{tenant_id: tid} do
      Tuples.delete(tid, [
        %Tuple{namespace: "doc", object_id: "readme", relation: "viewer", subject: {:user, "alice"}}
      ])

      results = Tuples.read(tid, %{namespace: "doc", object_id: "readme", relation: "viewer", subject: {:user, "alice"}})
      assert results == []
    end

    test "non-deleted tuples still appear after deleting others", %{tenant_id: tid} do
      Tuples.delete(tid, [
        %Tuple{namespace: "doc", object_id: "readme", relation: "viewer", subject: {:user, "alice"}}
      ])

      results = Tuples.read(tid, %{namespace: "doc", object_id: "readme", relation: "viewer", subject: {:user, "bob"}})
      assert length(results) == 1
    end
  end

  describe "zookie consistency" do
    test "read without zookie sees current state only", %{tenant_id: tid} do
      {:ok, _} = Tuples.write(tid, [
        %Tuple{namespace: "doc", object_id: "x", relation: "viewer", subject: {:user, "alice"}}
      ])

      Tuples.delete(tid, [
        %Tuple{namespace: "doc", object_id: "x", relation: "viewer", subject: {:user, "alice"}}
      ])

      # Without zookie, the deleted tuple should not appear
      results = Tuples.read(tid, %{namespace: "doc", object_id: "x"})
      assert results == []
    end

    test "read with zookie sees tuples that existed at snapshot time", %{tenant_id: tid} do
      {:ok, write_result} = Tuples.write(tid, [
        %Tuple{namespace: "doc", object_id: "y", relation: "viewer", subject: {:user, "alice"}}
      ])

      zookie = write_result.zookie

      Tuples.delete(tid, [
        %Tuple{namespace: "doc", object_id: "y", relation: "viewer", subject: {:user, "alice"}}
      ])

      # With zookie, should still see the deleted tuple
      results = Tuples.read(tid, %{namespace: "doc", object_id: "y"}, consistency: zookie)
      assert length(results) == 1
      assert hd(results).subject == {:user, "alice"}
    end

    test "read with pre-write zookie does not see later tuples", %{tenant_id: tid} do
      # Manually create a zookie with an explicit snapshot_at to avoid
      # microsecond-level timing issues
      past = DateTime.utc_now() |> DateTime.add(-1, :second)

      Zookie.mint_raw(tid, past, "zookie:deterministic-test")

      Tuples.write(tid, [
        %Tuple{namespace: "doc", object_id: "z", relation: "viewer", subject: {:user, "alice"}}
      ])

      # Read with the pre-dated zookie — should NOT see alice's tuple
      # because it was inserted after the snapshot
      results = Tuples.read(tid, %{namespace: "doc", object_id: "z"}, consistency: "zookie:deterministic-test")
      assert results == []

      # Write bob later
      Tuples.write(tid, [
        %Tuple{namespace: "doc", object_id: "z", relation: "viewer", subject: {:user, "bob"}}
      ])

      # Read without zookie — should see both
      results_no_zookie = Tuples.read(tid, %{namespace: "doc", object_id: "z"})
      assert length(results_no_zookie) == 2
    end

    test "write returns a usable zookie", %{tenant_id: tid} do
      {:ok, result} = Tuples.write(tid, [
        %Tuple{namespace: "doc", object_id: "a", relation: "viewer", subject: {:user, "alice"}}
      ])

      zookie = Tuples.Zookie.decode(result.zookie)
      assert zookie != nil
      assert zookie.tenant_id == tid
      assert not is_nil(zookie.snapshot_at)
    end
  end
end