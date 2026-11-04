# Testing standards

How testing is done in this repo. Every testing skill reads this file first, and it wins over their defaults. A line left as `ask` means the agent asks the user before it acts on it.

Test surface: the demo module in `demo/`, played on the stock NWN:EE client with no client extender, and with the built hak's files copied into the game's `development` folder
Boot command: `just demo <game folder> <game user folder>` (builds the overrides and the demo module, and stages them)
Test props: `demo/` and the game's `development` folder; throwaway scripts go in the system temp folder
Never holds test props: `nss/`, `shaders/`, `tools/` and any release asset
Commit test cruft: no
Test kinds: unit (`just test`: the tests in `tests/`; the compile tests need the game data, from the game folder or `NWN_ROOT`, which CI fetches; runs in CI); compile (`just compile`: every `.nss` through the NWScript compiler, runs in CI); live (a person in the demo module, see Live checks; never in CI, because CI has no copy of the game)
Mutation: by hand on the changed Python lines (flip a comparison, drop a branch), rerun `just test`, and report killed and surviving counts in the pull request body
Metrics: none
Live checks: 1. Run `just demo <game folder> <game user folder>`. 2. Start the stock client and load the demo module. 3. Follow the check's steps in the pull request body. 4. Read `logs/nwengineLog.txt` in the game's user folder for `failed to compile`. 5. Report what showed, with a screenshot
