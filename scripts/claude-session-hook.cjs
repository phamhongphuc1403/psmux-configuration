#!/usr/bin/env node
/**
 * claude-session-hook.cjs - Claude Code SessionStart / SessionEnd hook
 *
 * Records which Claude session runs in which psmux pane, so a restore can
 * reopen it with `claude --resume <id>`. Keyed by session and pane, since
 * psmux runs a server per session and pane ids repeat across them
 * (PSMUX_SESSION=main, TMUX_PANE=%4 -> claude-main_4.json):
 *   SessionStart -> write ~/.psmux/pane-state/live/claude-main_4.json ({session_id, cwd})
 *   SessionEnd   -> delete it, so a pane where Claude was quit comes back as a shell
 * SessionStart fires again on /clear and resume, so the file always holds the
 * pane's current session.
 *
 * Outside psmux (no TMUX_PANE) it does nothing. It always exits 0 so it can
 * never block Claude.
 */
const fs = require('fs');
const os = require('os');
const path = require('path');

const pane = process.env.TMUX_PANE;
const session = process.env.PSMUX_SESSION;
if (!pane || !session) process.exit(0);

const dir = path.join(os.homedir(), '.psmux', 'pane-state', 'live');
const file = path.join(dir, `claude-${session.replace(/\W/g, '_')}_${pane.replace(/\W/g, '')}.json`);

let input = '';
process.stdin.setEncoding('utf8');
process.stdin.on('data', (chunk) => { input += chunk; });
process.stdin.on('end', () => {
  try {
    const data = JSON.parse(input);
    if (data.hook_event_name === 'SessionEnd') {
      // /clear ends one session and starts another; SessionStart rewrites the file.
      if (data.reason !== 'clear') fs.rmSync(file, { force: true });
      return;
    }
    if (!data.session_id) return;
    fs.mkdirSync(dir, { recursive: true });
    fs.writeFileSync(file, JSON.stringify({ session_id: data.session_id, cwd: data.cwd || process.cwd() }));
  } catch {
    // Never block Claude over bookkeeping.
  }
});
