# OTP's tools application (`:xref`, read by the architecture test) is left
# off the code path by Mix, because the program does not use it. It is put
# there before any test file is compiled: added later, in the test itself,
# the compiler sometimes saw `:xref` as undefined, and the warning failed
# `mix check` on some runs with every test passing.
Mix.ensure_application!(:tools)

# the 2^24 bijection test takes a while: `mix test --include exhaustive`;
# every run's seed and failures are also kept in tmp/check/ (Agendum.TestLog)
#
# Lotus's starter applications (Planner, Information Sifter …) are Lotus's
# files: the public copy leaves them out (meeting 2026-10-28-5, § 7), and
# the tests tagged :lotus_starters run only where they are.
lotus_starters = if File.exists?("test/fixtures/ag/PLANNER.AG"), do: [], else: [:lotus_starters]

ExUnit.start(
  exclude: [:exhaustive | lotus_starters],
  formatters: [ExUnit.CLIFormatter, Agendum.TestLog]
)
