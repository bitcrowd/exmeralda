defmodule Exmeralda.Topics.LibraryTest do
  use Exmeralda.DataCase

  alias Exmeralda.Topics.Library

  describe "constraints" do
    test "unique on name & version" do
      insert(:library, name: "ecto", version: "1.0.0")
      insert(:library, name: "ecto", version: "1.0.1")
      insert(:library, name: "phoenix", version: "1.0.1")

      assert_raise(Ecto.ConstraintError, ~r/libraries_name_version/, fn ->
        insert(:library, name: "phoenix", version: "1.0.1")
      end)
    end
  end

  describe "changeset/2" do
    test "works with valid attrs" do
      Library.changeset(%Library{}, params_for(:library))
      |> assert_changeset_valid()
    end

    test "validates required field" do
      Library.changeset(%Library{}, %{})
      |> refute_changeset_valid()
      |> assert_required_error_on(:name)
      |> assert_required_error_on(:version)
    end

    test "validates names" do
      for name <- ~w(ecto phoenix_live_view absinthe_graphql my_lib123 nx) do
        assert Library.changeset(%Library{}, %{name: name, version: "1.0.0"}).valid?
      end

      for name <- ~w(_underscore_start 123numbersfirst s ends_with_ NOTEVENANAME $!@#) do
        cs = Library.changeset(%Library{}, %{name: name, version: "1.0.0"})
        refute cs.valid?
        assert_error_on(cs, :name, :format)
      end
    end

    test "validates version strings" do
      changeset =
        Library.changeset(%Library{}, %{
          name: "ecto",
          version: "xxx"
        })

      refute changeset.valid?
      assert_error_on(changeset, :version, :version)
    end
  end

  describe "set_dependencies_changeset/2" do
    test "casts embeds properly" do
      changeset =
        Library.set_dependencies_changeset(%Library{}, [
          %{
            name: "jason",
            version_requirement: "~> 1.0"
          },
          %{
            name: "telemetry",
            version_requirement: "~> 0.5 or ~> 1.0"
          }
        ])
        |> assert_changeset_valid()
        |> assert_changes(:dependencies)

      assert [jason, _telementry] = changeset.changes[:dependencies]

      assert jason
             |> assert_changes(:name, "jason")
             |> assert_changes(:version_requirement, "~> 1.0")
    end

    test "validates version embeds" do
      changeset =
        Library.set_dependencies_changeset(%Library{}, [
          %{
            name: "telemetry",
            version_requirement: "xxx"
          }
        ])

      refute changeset.valid?

      [telemetry] = changeset.changes[:dependencies]

      assert_error_on(telemetry, :version_requirement, :version_requirement)
    end
  end
end
