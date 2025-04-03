defmodule ExmeraldaWeb.UserLive.AcceptTerms do
  use ExmeraldaWeb, :live_view

  alias Exmeralda.Accounts

  defmodule Terms do
    use Ecto.Schema
    import Ecto.Changeset

    embedded_schema do
      field :terms_accepted, :boolean
    end

    def changeset(params) do
      %__MODULE__{} |> cast(params, [:terms_accepted]) |> validate_acceptance(:terms_accepted)
    end
  end

  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:form, Terms.changeset(%{}) |> to_form())

    {:ok, socket}
  end

  def handle_event("accept", params, socket) do
    socket =
      params
      |> Map.get("terms")
      |> Terms.changeset()
      |> Ecto.Changeset.apply_action(:accept)
      |> case do
        {:ok, _} ->
          user = socket.assigns.current_user |> Accounts.accept_terms!()

          socket
          |> assign(:current_user, user)
          |> push_navigate(to: ~p"/chat/start")

        {:error, changeset} ->
          assign(socket, :form, changeset |> to_form())
      end

    {:noreply, socket}
  end

  def render(assigns) do
    ~H"""
    <.hero_layout>
      <div class="text-center flex flex-col gap-8">
        <h1 class="text-5xl font-bold">Terms and Conditions</h1>
        <img
          src={~p"/images/logo-exmeralda.svg"}
          width="523"
          height="516"
          alt="Exmeralda logo, with stylised circuit board tracks surrounding a central node"
          class="max-w-xs py-5"
        />
        <div class="card bg-base-100 w-full shrink-0 shadow-2xl">
          <div class="card-body">
            <div role="alert" class="alert alert-info">
              <.icon name="hero-information-circle" />
              <span>Please accept the terms of service to continue.</span>
            </div>
            <iframe class="w-full h-96" src="/terms" title="Terms of service"></iframe>
            <.simple_form for={@form} phx-submit="accept">
              <.input
                type="checkbox"
                field={@form[:terms_accepted]}
                label="I agree to the Terms and Conditions"
              />
              <p></p>
              <:actions>
                <.button class="btn-primary">Continue</.button>
              </:actions>
            </.simple_form>
          </div>
        </div>
      </div>
    </.hero_layout>
    """
  end
end
