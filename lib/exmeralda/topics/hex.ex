defmodule Exmeralda.Topics.Hex do
  @base_url "https://repo.hex.pm"

  def docs(name, version) do
    hex_fetch("/docs/#{name}-#{version}.tar.gz")
  end

  def tarball(name, version) do
    hex_fetch("/tarballs/#{name}-#{version}.tar")
  end

  def list do
    hex_fetch("/versions")
  end

  defp hex_fetch(url) do
    [base_url: @base_url, url: url]
    |> Keyword.merge(Application.get_env(:exmeralda, :hex_req_options, []))
    |> Req.new()
    |> ReqHex.attach()
    |> Req.get!()
    |> case do
      %Req.Response{status: 200, body: body} -> {:ok, body}
      %Req.Response{status: 404} -> {:error, {:repo_not_found, url}}
      response -> {:error, {:hex_fetch_error, response}}
    end
  end
end
