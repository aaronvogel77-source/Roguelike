---
name: deploy
description: Test, version, log, commit, push and watch the GitHub Pages deploy of Arcana. Use after finishing any change the player should test in the browser.
---

# Deploy Arcana

Only for this repository. Pushes go to the development branch only; never force-push, never open a pull request unless the user asks.

1. **Import and test** (from the repository root):
   ```bash
   godot --headless --import >/dev/null 2>&1
   timeout 300 godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit 2>&1 | grep -E "Passing Tests|Failing Tests|^Tests|SCRIPT ERROR|at line"
   ```
   All tests must pass. After editing `translations/strings.csv` the import step is required.
   Tests with animations must wait generously (CI machines are slower than local runs).
2. **Version:** raise `config/version` in `project.godot` (feature = minor, fix = patch).
3. **Decision log:** append one row to the table at the end of `GAME_DESIGN.md`
   (`| date | what changed (version) | reason | rejected alternatives |`).
4. **Commit** with the attribution lines from the session's system reminder.
5. **Push** with retries:
   ```bash
   for i in 1 2 3 4; do git push -q origin claude/roguelike-dev-partner-nc1beo && break; sleep $((2**i)); done
   ```
6. **Watch the workflow** (read-only GitHub API, no token needed for this public repo):
   ```bash
   H=$(git rev-parse --short=7 HEAD)
   for i in $(seq 1 30); do
     r=$(curl -s "https://api.github.com/repos/aaronvogel77-source/Roguelike/actions/runs?branch=claude/roguelike-dev-partner-nc1beo&per_page=1" \
       | python3 -c "import json,sys;d=json.load(sys.stdin)['workflow_runs'][0];print(d['status'],d['conclusion'],d['head_sha'][:7])")
     case "$r" in "completed success $H"|"completed failure $H") echo $r; break;; esac; sleep 15
   done
   ```
7. **On failure:** read the failed job's log (GitHub MCP `get_job_logs` with `failed_only`), fix, repeat.
8. **Report in German** with the link https://aaronvogel77-source.github.io/Roguelike/ (add `?debug=1` for test tools),
   say what was verified in the browser and what was not.
