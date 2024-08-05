import Config

config :logger, level: :warn

config :changeset_helpers,
  ecto_repos: [ChangesetHelpers.Repo]

config :changeset_helpers, ChangesetHelpers.Repo,
  username: "postgres",
  password: "postgres",
  database: "changeset_helpers",
  hostname: "localhost",
  pool: Ecto.Adapters.SQL.Sandbox,
  priv: "test/support"
