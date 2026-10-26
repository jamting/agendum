# OTP's tools application (`:xref`, read by the architecture test) is left
# off the code path by Mix, because the program does not use it. It is put
# there before any test file is compiled: added later, in the test itself,
# the compiler sometimes saw `:xref` as undefined, and the warning failed
# `mix check` on some runs with every test passing.
Mix.ensure_application!(:tools)

# the 2^24 bijection test takes a while: `mix test --include exhaustive`;
# every run's seed and failures are also kept in tmp/check/ (Agendum.TestLog)
ExUnit.start(exclude: [:exhaustive], formatters: [ExUnit.CLIFormatter, Agendum.TestLog])
