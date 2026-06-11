defmodule ZevalCore.Namespace.RuleValidatorTest do
  use ExUnit.Case, async: true
  alias ZevalCore.Namespace.RuleValidator

  describe "validate/1 - individual rules" do
    test "this rule" do
      assert {:ok, %{"this" => %{}}} = RuleValidator.validate(%{"this" => %{}})
    end

    test "this rule with wrong value" do
      assert {:error, msg} = RuleValidator.validate(%{"this" => 42})
      assert msg =~ "this"
    end

    test "computed_userset rule" do
      assert {:ok, %{"computed_userset" => %{"relation" => "owner"}}} =
               RuleValidator.validate(%{"computed_userset" => %{"relation" => "owner"}})
    end

    test "computed_userset rule missing relation" do
      assert {:error, msg} = RuleValidator.validate(%{"computed_userset" => %{}})
      assert msg =~ "computed_userset"
    end

    test "tuple_to_userset rule" do
      assert {:ok, rule} =
               RuleValidator.validate(%{
                 "tuple_to_userset" => %{
                   "tupleset_relation" => "parent",
                   "computed_userset_relation" => "viewer"
                 }
               })

      assert rule["tuple_to_userset"]["tupleset_relation"] == "parent"
      assert rule["tuple_to_userset"]["computed_userset_relation"] == "viewer"
    end

    test "tuple_to_userset rule missing fields" do
      assert {:error, _} =
               RuleValidator.validate(%{"tuple_to_userset" => %{"tupleset_relation" => "parent"}})
    end

    test "union rule with children" do
      assert {:ok, rule} =
               RuleValidator.validate(%{
                 "union" => [%{"this" => %{}}, %{"computed_userset" => %{"relation" => "editor"}}]
               })

      assert length(rule["union"]) == 2
      assert Enum.at(rule["union"], 0)["this"] == %{}
    end

    test "union rule with invalid child" do
      assert {:error, msg} =
               RuleValidator.validate(%{
                 "union" => [%{"this" => %{}}, %{"garbage" => 1}]
               })

      assert msg =~ "union"
    end

    test "intersection rule with children" do
      assert {:ok, rule} =
               RuleValidator.validate(%{
                 "intersection" => [%{"this" => %{}}, %{"this" => %{}}]
               })

      assert length(rule["intersection"]) == 2
    end

    test "exclusion rule" do
      assert {:ok, rule} =
               RuleValidator.validate(%{
                 "exclusion" => %{
                   "base" => %{"this" => %{}},
                   "subtract" => %{"this" => %{}}
                 }
               })

      assert rule["exclusion"]["base"]["this"] == %{}
      assert rule["exclusion"]["subtract"]["this"] == %{}
    end

    test "exclusion rule with invalid base" do
      assert {:error, _} =
               RuleValidator.validate(%{
                 "exclusion" => %{"base" => %{"garbage" => 1}, "subtract" => %{"this" => %{}}}
               })
    end

    test "unknown rule type" do
      assert {:error, msg} = RuleValidator.validate(%{"garbage" => 1})
      assert msg =~ "unknown" or msg =~ "malformed"
    end

    test "non-map input" do
      assert {:error, _} = RuleValidator.validate("not a map")
    end

    test "empty map" do
      assert {:error, msg} = RuleValidator.validate(%{})
      assert msg =~ "empty"
    end
  end

  describe "validate_config/1 - full configs" do
    test "valid config with multiple relations" do
      config = %{
        "name" => "doc",
        "relations" => %{
          "viewer" => %{"this" => %{}},
          "editor" => %{"computed_userset" => %{"relation" => "owner"}},
          "owner" => %{"this" => %{}}
        }
      }

      assert {:ok, validated} = RuleValidator.validate_config(config)
      assert validated["name"] == "doc"
      assert map_size(validated["relations"]) == 3
    end

    test "missing name returns error" do
      assert {:error, _} = RuleValidator.validate_config(%{"relations" => %{}})
    end

    test "missing relations returns error" do
      assert {:error, _} = RuleValidator.validate_config(%{"name" => "doc"})
    end

    test "invalid relation rule returns error with context" do
      config = %{
        "name" => "doc",
        "relations" => %{
          "viewer" => %{"garbage" => 1}
        }
      }

      assert {:error, msg} = RuleValidator.validate_config(config)
      assert msg =~ "viewer"
    end

    test "nested union with computed_userset" do
      config = %{
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
      }

      assert {:ok, _} = RuleValidator.validate_config(config)
    end
  end

  describe "cycle detection" do
    test "simple cycle: viewer->editor->viewer" do
      config = %{
        "name" => "doc",
        "relations" => %{
          "viewer" => %{"computed_userset" => %{"relation" => "editor"}},
          "editor" => %{"computed_userset" => %{"relation" => "viewer"}}
        }
      }

      assert {:error, msg} = RuleValidator.validate_config(config)
      assert msg =~ "circular"
      assert msg =~ "viewer"
    end

    test "self-loop: viewer->viewer" do
      config = %{
        "name" => "doc",
        "relations" => %{
          "viewer" => %{"computed_userset" => %{"relation" => "viewer"}}
        }
      }

      assert {:error, msg} = RuleValidator.validate_config(config)
      assert msg =~ "circular"
      assert msg =~ "viewer"
    end

    test "no cycle: simple chain viewer->editor->owner" do
      config = %{
        "name" => "doc",
        "relations" => %{
          "viewer" => %{"computed_userset" => %{"relation" => "editor"}},
          "editor" => %{"computed_userset" => %{"relation" => "owner"}},
          "owner" => %{"this" => %{}}
        }
      }

      assert {:ok, _} = RuleValidator.validate_config(config)
    end

    test "cycle through union" do
      config = %{
        "name" => "doc",
        "relations" => %{
          "viewer" => %{
            "union" => [
              %{"this" => %{}},
              %{"computed_userset" => %{"relation" => "editor"}}
            ]
          },
          "editor" => %{"computed_userset" => %{"relation" => "viewer"}}
        }
      }

      assert {:error, msg} = RuleValidator.validate_config(config)
      assert msg =~ "circular"
    end

    test "no cycle: acyclic config" do
      config = %{
        "name" => "doc",
        "relations" => %{
          "viewer" => %{"this" => %{}},
          "editor" => %{"this" => %{}},
          "owner" => %{"this" => %{}}
        }
      }

      assert {:ok, _} = RuleValidator.validate_config(config)
    end
  end
end
