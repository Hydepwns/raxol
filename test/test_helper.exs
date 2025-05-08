Application.ensure_all_started(:mox)

ExUnit.start(
  before_suite: fn -> Mox.setup() end,
  after_suite: fn -> Mox.teardown() end
)
