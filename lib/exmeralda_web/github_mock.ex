defmodule ExmeraldaWeb.GithubMock do
  @moduledoc """
  Mock GitHub OAuth adapter for development and testing.
  """

  @behaviour Assent.Strategy

  @impl true
  def authorize_url(_config) do
    {:ok,
     %{
       url: "http://localhost:4000/auth/github/callback?code=mock_code",
       session_params: %{"state" => "mock_state"}
     }}
  end

  @impl true
  def callback(config, %{"code" => "mock_code"}) do
    %{"state" => "mock_state"} = config[:session_params]

    user_info = %{
      "sub" => "123",
      "name" => "Mock User",
      "email" => "test@bitcrowd.io",
      "picture" => "https://via.placeholder.com/150",
      "profile" => "http://github.com/bitcrowd"
    }

    {:ok, %{user: user_info}}
  end

  def callback(_config, _params) do
    {:error, "Invalid mock callback"}
  end
end
