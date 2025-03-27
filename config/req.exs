import Config

if config_env() == :test do
  config :exmeralda,
    hex_req_options: [
      plug: {Req.Test, Exmeralda.HexMock}
    ]
end
