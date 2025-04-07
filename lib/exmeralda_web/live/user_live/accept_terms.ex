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
    <.navbar_layout user={@current_user}>
      <.hero_layout inside_navbar>
        <div class="items-center flex flex-col gap-8">
          <h1 class="text-5xl font-bold">Terms and Conditions</h1>
          <img
            src={~p"/images/logo-exmeralda.svg"}
            width="523"
            height="516"
            alt="Exmeralda logo, with stylised circuit board tracks surrounding a central node"
            class="max-w-xs py-5"
          />
          <div class="card bg-base-100 shrink-0 shadow-2xl w-full md:w-2/3">
            <div class="card-body text-left">
              <div role="alert" class="alert alert-info">
                <.icon name="hero-information-circle" />
                <span>Please accept the terms of service to continue.</span>
              </div>
              <ul class="flex flex-col gap-6 list-disc mx-6 my-4">
                <li>
                  <strong>Welcome to Exmeralda:</strong>
                  Exmeralda is your AI-powered assistant, provided  with love by bitcrowd,
                  designed to help you with interactive documentation for various open source software packages.
                </li>
                <li>
                  <strong>Your Privacy Matters:</strong>
                  To protect privacy, please don't input personal data into Exmeralda.
                  We do use your interactions to improve our service and help package creators, but rest assured,
                  data is anonymized. You can always opt out or request to delete your account at any time.
                </li>
                <li>
                  <strong>Using Exmeralda Responsibly:</strong>
                  You're welcome to use Exmeralda's content for internal business purposes. While we strive for accuracy,
                  keep in mind the occasional errors or third-party content we can't fully control. We'll always do our best
                  to provide reliable service, but can't guarantee perfection. Please be aware that the open source software
                  packages might have licence restrictions.
                </li>
                <li>
                  <strong>Keeping You in the Loop:</strong>
                  If our terms change significantly, we'll give you advance notice. And although it's rare, we might need
                  to suspend an account if it violates our guidelines. If any issues arise, German law applies, with Berlin
                  as the agreed place of jurisdiction.
                </li>
              </ul>
              <.simple_form for={@form} phx-submit="accept">
                <.input
                  type="checkbox"
                  field={@form[:terms_accepted]}
                  label={
                    raw(
                      "<span>I agree to the <a href=\"/terms\" target=\"_blank\" class=\"link\">Terms and Conditions</a></span>"
                    )
                  }
                />
                <:actions>
                  <.button class="btn-primary">Continue</.button>
                </:actions>
              </.simple_form>
            </div>
          </div>
        </div>
      </.hero_layout>
    </.navbar_layout>
    """
  end
end
