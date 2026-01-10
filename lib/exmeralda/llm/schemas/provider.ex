defmodule Exmeralda.LLM.Provider do
  @moduledoc """
  A provider is a third-party providing access to AI models.
  """
  use Exmeralda.Schema

  @derive {
    Flop.Schema,
    filterable: [],
    sortable: [:inserted_at],
    default_limit: 20,
    default_order: %{
      order_by: [:inserted_at],
      order_directions: [:desc]
    }
  }

  schema "providers" do
    field :type, Ecto.Enum, values: [:ollama, :openai, :mock]
    field :name, :string
    field :config, :map
    field :deletable, :boolean, virtual: true

    timestamps()
  end

  @attrs [:type, :name, :config]
  def changeset(attrs) do
    %__MODULE__{}
    |> cast(attrs, @attrs)
    |> validate_required([:type, :name])
    |> unique_constraint(:type, name: :providers_type_name_index)
    |> maybe_validate_endpoint_config()
  end

  defp maybe_validate_endpoint_config(changeset) do
    if get_change(changeset, :type) == :openai do
      changeset
      |> validate_required([:config])
      |> validate_endpoint()
    else
      changeset
    end
  end

  defp validate_endpoint(changeset) do
    validate_change(changeset, :config, fn :config, config ->
      if endpoint = Map.get(config, "endpoint") do
        validate_url(endpoint)
      else
        [config: "openai provider needs endpoint config"]
      end
    end)
  end

  defp validate_url(endpoint) do
    uri = URI.parse(endpoint)

    if !is_nil(uri.scheme) && uri.host =~ ".",
      do: [],
      else: [config: "endpoint must be a valid url"]
  end
end
