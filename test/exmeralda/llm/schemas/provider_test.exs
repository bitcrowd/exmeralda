defmodule Exmeralda.LLM.ProviderTest do
  use Exmeralda.DataCase
  alias Exmeralda.LLM.Provider

  describe "changeset/1" do
    test "validates required fields" do
      %{}
      |> Provider.changeset()
      |> refute_changeset_valid()
      |> assert_required_error_on(:type)
      |> assert_required_error_on(:name)
    end

    test "validates endpoint config is given when type openai" do
      %{type: :openai, name: "together_ai"}
      |> Provider.changeset()
      |> refute_changeset_valid()
      |> assert_required_error_on(:config)

      %{type: :openai, name: "together_ai", config: %{}}
      |> Provider.changeset()
      |> refute_changeset_valid()
      |> assert_error_on(:config, ["openai provider needs endpoint config"])

      %{type: :openai, name: "together_ai", config: %{"endpoint" => "not a url"}}
      |> Provider.changeset()
      |> refute_changeset_valid()
      |> assert_error_on(:config, ["endpoint must be a valid url"])

      %{type: :openai, name: "together_ai", config: %{"endpoint" => "https://example.com"}}
      |> Provider.changeset()
      |> assert_changeset_valid()
    end

    test "validates type name uniqueness" do
      insert(:provider, type: :mock, name: "provider-name")

      assert {:error, changeset} =
               %{type: :mock, name: "provider-name"}
               |> Provider.changeset()
               |> Repo.insert()

      assert_error_on(changeset, :type, ["has already been taken", :unique])
    end

    test "returns a changeset" do
      for type <- [:ollama, :mock] do
        %{type: type, name: "provider-name"}
        |> Provider.changeset()
        |> assert_changeset_valid()
        |> assert_changes(:type, type)
        |> assert_changes(:name, "provider-name")
      end
    end
  end
end
