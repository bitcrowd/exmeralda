defmodule Exmeralda.MigrationHelper do
  def env do
    compile_env = if Code.ensure_loaded?(Mix), do: Mix.env(), else: nil

    case System.get_env("MIX_ENV") do
      nil -> compile_env || :prod
      env -> String.to_atom(env)
    end
  end
end
