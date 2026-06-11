defmodule ZevalCore.Tuples.ParserTest do
  use ExUnit.Case, async: true
  alias ZevalCore.Tuples.Parser
  alias ZevalCore.Tuples.Tuple

  describe "parse/1 - user subjects" do
    test "parses a direct user tuple" do
      assert {:ok, %Tuple{}} = Parser.parse("doc:readme#viewer@alice")
    end

    test "extracts namespace, object, relation, and user" do
      assert {:ok, tuple} = Parser.parse("doc:readme#viewer@alice")
      assert tuple.namespace == "doc"
      assert tuple.object_id == "readme"
      assert tuple.relation == "viewer"
      assert tuple.subject == {:user, "alice"}
    end

    test "handles namespaced object with dots" do
      assert {:ok, tuple} = Parser.parse("org:my-org#member@bob")
      assert tuple.namespace == "org"
      assert tuple.object_id == "my-org"
      assert tuple.relation == "member"
      assert tuple.subject == {:user, "bob"}
    end

    test "handles complex object IDs with hyphens and dots" do
      assert {:ok, tuple} = Parser.parse("doc:v1.2.3#viewer@alice")
      assert tuple.object_id == "v1.2.3"
    end

    test "handles underscore in names" do
      assert {:ok, tuple} = Parser.parse("namespace_1:object_1#relation_1@user_1")
      assert tuple.namespace == "namespace_1"
      assert tuple.object_id == "object_1"
      assert tuple.relation == "relation_1"
      assert tuple.subject == {:user, "user_1"}
    end

    test "handles email-style user IDs" do
      assert {:ok, tuple} = Parser.parse("doc:readme#viewer@alice@example.com")
      assert tuple.subject == {:user, "alice@example.com"}
    end
  end

  describe "parse/1 - userset subjects" do
    test "parses a userset tuple" do
      assert {:ok, tuple} = Parser.parse("doc:readme#viewer@group:eng#member")
      assert tuple.namespace == "doc"
      assert tuple.object_id == "readme"
      assert tuple.relation == "viewer"
      assert tuple.subject == {:userset, "group", "eng", "member"}
    end

    test "parses userset with complex names" do
      assert {:ok, tuple} = Parser.parse("repo:my-project#admin@team:sre#lead")
      assert tuple.subject == {:userset, "team", "sre", "lead"}
    end
  end

  describe "parse/1 - errors" do
    test "rejects missing @ separator" do
      assert {:error, msg} = Parser.parse("doc:readme#viewer")
      assert msg =~ "@"
    end

    test "rejects empty object part" do
      assert {:error, msg} = Parser.parse("@alice")
      assert msg =~ "malformed"
    end

    test "rejects missing #" do
      assert {:error, msg} = Parser.parse("doc:readme@alice")
      assert msg =~ "#"
    end

    test "rejects missing :" do
      assert {:error, msg} = Parser.parse("readme#viewer@alice")
      assert msg =~ ":"
    end

    test "rejects non-string input" do
      assert {:error, msg} = Parser.parse(nil)
      assert msg =~ "string"
    end

    test "rejects empty string" do
      assert {:error, msg} = Parser.parse("")
      assert msg =~ "malformed"
    end

    test "rejects userset with missing #" do
      assert {:error, msg} = Parser.parse("doc:readme#viewer@group:eng")
      assert msg =~ "#"
    end
  end
end