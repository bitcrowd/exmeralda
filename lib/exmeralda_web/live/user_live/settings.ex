defmodule ExmeraldaWeb.UserLive.Settings do
  use ExmeraldaWeb, :live_view

  alias Exmeralda.Accounts

  def render(assigns) do
    ~H"""
    <.navbar_layout user={@current_user}>
      <.hero_layout inside_navbar>
        <div class="card card-border bg-base-100 w-96">
          <div class="card-body">
            <h2 class="card-title">{gettext("Settings")}</h2>
            <p>
              {gettext(
                "You can change your email address here. Your avatar and name can only be changed at your login provider."
              )}
            </p>

            <div class="flex items-center">
              <div class="avatar p-5 mr-5 flex-none">
                <div class="ring-primary ring-offset-base-100 w-24 rounded-full ring ring-offset-2">
                  <img src={@current_user.avatar_url} />
                </div>
              </div>
              <div class="flex-1">
                <div>{@current_user.name}</div>
                <div>{@current_user.email}</div>
              </div>
            </div>
            <.simple_form
              :let={f}
              for={@email_form}
              id="email_form"
              phx-change="validate_email"
              phx-submit="update_email"
            >
              <.input label={gettext("E-Mail")} type="email" field={f[:email]} />
              <:actions>
                <a href={~p"/chat/start"} class="btn btn-soft">Back</a>
                <.button class="btn-primary">Save</.button>
              </:actions>
            </.simple_form>
          </div>
        </div>
      </.hero_layout>
    </.navbar_layout>
    """
  end

  def mount(_params, _session, socket) do
    user = socket.assigns.current_user
    email_form = Accounts.change_user_email(user) |> to_form()

    socket =
      socket
      |> assign(:email_form, email_form)

    {:ok, socket}
  end

  def handle_event("validate_email", params, socket) do
    email_changeset =
      Accounts.change_user_email(socket.assigns.current_user, params)
      |> Map.put(:action, :validate)
      |> to_form()

    socket =
      socket
      |> assign(:email_form, to_form(email_changeset))

    {:noreply, socket}
  end

  def handle_event("update_email", params, socket) do
    socket =
      case Accounts.update_user_email(socket.assigns.current_user, params) do
        {:ok, _user} ->
          socket
          |> put_flash(:info, gettext("Settings saved!"))
          |> push_navigate(to: ~p"/chat/start")

        {:error, changeset} ->
          socket
          |> assign(:email_form, changeset |> to_form())
      end

    {:noreply, socket}
  end
end
