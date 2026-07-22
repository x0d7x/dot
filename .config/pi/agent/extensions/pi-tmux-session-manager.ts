/**
 * pi-tmux-session-manager — Pi extension
 *
 * Watches Pi's lifecycle events and publishes a small, privacy-safe state file
 * per session that the tmux-side manager (`pi-tmux`) reads for discovery,
 * status, and last-activity. It also emits deduplicated desktop notifications
 * on status transitions (waiting / error / optional done) — event-driven, no
 * daemon, no polling.
 *
 * Install:  place this file in your Pi extensions dir, e.g.
 *             ~/.config/pi/agent/extensions/pi-tmux-session-manager.ts
 *           (run `pi-tmux install-extension` to do it automatically)
 * Then reload pi (`/reload`) or restart it.
 *
 * State files: $XDG_STATE_HOME/pi-tmux-session-manager/agents/<session-id>.json
 * Config:      $XDG_CONFIG_HOME/pi-tmux-session-manager/config.json
 *
 * Env overrides: PSM_STATE_DIR, PSM_CONFIG_DIR, PSM_NOTIFY_SEND, PSM_DEBUG.
 *
 * Only metadata is written — never prompts, messages, tool args, or credentials.
 */
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { mkdirSync, readFileSync, writeFileSync, renameSync, readdirSync, existsSync } from "node:fs";
import { join, dirname, basename } from "node:path";
import { homedir } from "node:os";
import { execFile, execFileSync } from "node:child_process";

const APP = "pi-tmux-session-manager";

// Paths (must mirror scripts/helpers.sh)
function stateRoot(): string {
  if (process.env.PSM_STATE_DIR) return process.env.PSM_STATE_DIR;
  if (process.env.XDG_STATE_HOME) return join(process.env.XDG_STATE_HOME, APP);
  return join(homedir(), ".local", "state", APP);
}
function configRoot(): string {
  if (process.env.PSM_CONFIG_DIR) return process.env.PSM_CONFIG_DIR;
  if (process.env.XDG_CONFIG_HOME) return join(process.env.XDG_CONFIG_HOME, APP);
  return join(homedir(), ".config", APP);
}
const agentsDir = join(stateRoot(), "agents");
const configFile = join(configRoot(), "config.json");

// Tiny config reader
interface Config {
  enabled: boolean;
  notify_on_waiting: boolean;
  notify_on_error: boolean;
  notify_on_done: boolean;
  notify_on_blocked: boolean;
  notification_backend: "auto" | "notify-send" | "bell" | "off";
  terminal_bell: boolean;
  min_attention_duration_ms: number;
}
function defaultConfig(): Config {
  return {
    enabled: true,
    notify_on_waiting: true,
    notify_on_error: true,
    notify_on_done: false,
    notify_on_blocked: true,
    notification_backend: "auto",
    terminal_bell: true,
    min_attention_duration_ms: 5000,
  };
}
function readConfig(): Config {
  const cfg = defaultConfig();
  try {
    const raw = readFileSync(configFile, "utf8");
    const data = JSON.parse(raw) as Partial<Config>;
    if (typeof data.enabled === "boolean") cfg.enabled = data.enabled;
    if (typeof data.notify_on_waiting === "boolean") cfg.notify_on_waiting = data.notify_on_waiting;
    if (typeof data.notify_on_error === "boolean") cfg.notify_on_error = data.notify_on_error;
    if (typeof data.notify_on_done === "boolean") cfg.notify_on_done = data.notify_on_done;
    if (typeof data.notify_on_blocked === "boolean") cfg.notify_on_blocked = data.notify_on_blocked;
    if (data.notification_backend === "auto" || data.notification_backend === "notify-send" || data.notification_backend === "bell" || data.notification_backend === "off") {
      cfg.notification_backend = data.notification_backend;
    }
    if (typeof data.terminal_bell === "boolean") cfg.terminal_bell = data.terminal_bell;
    if (typeof data.min_attention_duration_ms === "number" && data.min_attention_duration_ms >= 0) {
      cfg.min_attention_duration_ms = data.min_attention_duration_ms;
    }
  } catch {
    // no/invalid config -> defaults
  }
  return cfg;
}

// Debug log (opt-in)
function debugLog(msg: string): void {
  if (process.env.PSM_DEBUG !== "1") return;
  try {
    mkdirSync(stateRoot(), { recursive: true });
    writeFileSync(join(stateRoot(), "extension.log"), `${new Date().toISOString()} ${msg}\n`, { flag: "a" });
  } catch {
    /* never throw from logging */
  }
}

// In-memory session state
interface AgentState {
  schema: number;
  session_id: string | null;
  session_file: string | null;
  session_name: string | null;
  pid: number;
  cwd: string;
  status: "working" | "waiting" | "idle" | "error" | "blocked";
  alive: boolean;
  started_at: number;
  updated_at: number;
  last_activity_at: number | null;
  last_user_input_at: number | null;
  last_error_at: number | null;
  has_worked: boolean;
  last_stop_reason: string | null;
  is_blocked: boolean;
  blocked_at: number | null;
  blocked_reason: "question" | "permission" | null;
  notify: { last_sent_status: string | null; last_sent_at: number | null };
}

let st: AgentState = {
  schema: 1,
  session_id: null,
  session_file: null,
  session_name: null,
  pid: process.pid,
  cwd: process.cwd(),
  status: "idle",
  alive: true,
  started_at: Date.now(),
  updated_at: Date.now(),
  last_activity_at: null,
  last_user_input_at: null,
  last_error_at: null,
  has_worked: false,
  last_stop_reason: null,
  is_blocked: false,
  blocked_at: null,
  blocked_reason: null,
  notify: { last_sent_status: null, last_sent_at: null },
};

let agentActive = false;
let blockedCount = 0; // concurrent blockers (question dialog + permission dialogs)
let dirty = false;
let flushTimer: NodeJS.Timeout | null = null;
let writeChain: Promise<void> = Promise.resolve();
let lastWriteAt = 0;
const ACTIVITY_WRITE_THROTTLE_MS = 1000;

// deriveStatus(): priority blocked > working > error > waiting > idle
function deriveStatus(): AgentState["status"] {
  if (st.is_blocked) return "blocked";
  if (agentActive) return "working";
  if (st.last_error_at !== null && (st.last_user_input_at === null || st.last_error_at > st.last_user_input_at)) {
    return "error";
  }
  if (st.has_worked) return "waiting";
  return "idle";
}

// Blocked state: the agent is waiting on the USER (a question dialog or a
// permission dialog), not on the model. Counted so overlapping dialogs cannot
// leave the state stuck — blocked stays until every blocker is released.
function block(reason: "question" | "permission"): void {
  blockedCount += 1;
  st.is_blocked = true;
  st.blocked_at = Date.now();
  st.blocked_reason = reason;
  st.last_activity_at = st.blocked_at;
  maybeNotify("blocked");
  touch(true);
}

function release(): void {
  if (blockedCount > 0) blockedCount -= 1;
  if (blockedCount > 0) return;
  st.is_blocked = false;
  st.blocked_at = null;
  st.blocked_reason = null;
  // re-arm notifications: a fresh question/permission must notify again
  st.notify.last_sent_status = null;
  touch(true);
}

// Force-unblock: the user typed something or a new turn started — whatever
// was blocking is considered answered.
function forceUnblock(): void {
  blockedCount = 0;
  st.is_blocked = false;
  st.blocked_at = null;
  st.blocked_reason = null;
  st.notify.last_sent_status = null;
}

// State file I/O (atomic, serialized, throttled for activity)
function serializeState(): string {
  return JSON.stringify(
    {
      schema: st.schema,
      session_id: st.session_id,
      session_file: st.session_file,
      session_name: st.session_name,
      pid: st.pid,
      cwd: st.cwd,
      status: deriveStatus(),
      alive: st.alive,
      started_at: st.started_at,
      updated_at: Date.now(),
      last_activity_at: st.last_activity_at,
      last_user_input_at: st.last_user_input_at,
      last_error_at: st.last_error_at,
      has_worked: st.has_worked,
      last_stop_reason: st.last_stop_reason,
      is_blocked: st.is_blocked,
      blocked_at: st.blocked_at,
      blocked_reason: st.blocked_reason,
      notify: st.notify,
    },
    null,
    2,
  );
}

function writeStateNow(): void {
  if (!st.session_id) return;
  try {
    mkdirSync(agentsDir, { recursive: true, mode: 0o700 });
    const file = join(agentsDir, `${st.session_id}.json`);
    const tmp = join(agentsDir, `.${st.session_id}.tmp.${process.pid}`);
    writeFileSync(tmp, serializeState(), { mode: 0o600 });
    renameSync(tmp, file);
    dirty = false;
    lastWriteAt = Date.now();
  } catch (err) {
    debugLog(`write failed: ${String(err)}`);
  }
}

function scheduleFlush(): void {
  if (flushTimer) return;
  flushTimer = setTimeout(() => {
    flushTimer = null;
    if (dirty) writeStateNow();
  }, ACTIVITY_WRITE_THROTTLE_MS);
  flushTimer.unref?.();
}

// touch(immediate): activity or state changed
function touch(immediate = false): void {
  dirty = true;
  if (immediate) {
    writeStateNow();
  } else {
    scheduleFlush();
  }
}

// Notifications (event-driven, deduplicated)
let notifySendPath: string | null | undefined;
function resolveNotifySend(): string | null {
  if (notifySendPath !== undefined) return notifySendPath;
  if (process.env.PSM_NOTIFY_SEND) {
    notifySendPath = process.env.PSM_NOTIFY_SEND;
    return notifySendPath;
  }
  try {
    notifySendPath = execFileSync("command", ["-v", "notify-send"], { encoding: "utf8" }).trim() || null;
    return notifySendPath;
  } catch {
    notifySendPath = null;
    return notifySendPath;
  }
}

// Stable numeric notification id per session (notify-send -r replaces).
function notifyId(): number {
  if (!st.session_id) return Math.floor(Math.random() * 0x7fffffff);
  let h = 0;
  for (const ch of st.session_id) h = (h * 31 + ch.charCodeAt(0)) >>> 0;
  return (h % 0x7fffffff) + 1;
}

function projectLabel(): string {
  if (st.session_name) return st.session_name;
  const b = basename(st.cwd || "");
  return b || st.cwd || "pi";
}

// Best-effort tmux location (TMUX_PANE is exported by tmux into panes).
function tmuxLoc(): string {
  const pane = process.env.TMUX_PANE;
  if (!pane || !process.env.TMUX) return "";
  try {
    return execFileSync("tmux", ["display-message", "-p", "-t", pane, "#{session_name}:#{window_index}.#{pane_index}"], {
      encoding: "utf8",
      timeout: 2000,
    }).trim();
  } catch {
    return "";
  }
}

// ringBell — terminal bell with kitty's bell sound. The agent often runs in a
// pi-* session with NO attached client, so a BEL written to the pane's pty
// only sets a tmux flag and never reaches the user's terminal. Instead we ring
// every attached tmux client (their terminal emulator plays the bell sound),
// falling back to our own controlling tty. PSM_BELL_DEV overrides the target.
function ringBell(): void {
  const dev = process.env.PSM_BELL_DEV;
  if (dev) {
    try {
      writeFileSync(dev, "\x07");
    } catch {
      /* ignore */
    }
    return;
  }
  let rung = false;
  try {
    const out = execFileSync("tmux", ["list-clients", "-F", "#{client_tty}"], {
      encoding: "utf8",
      timeout: 2000,
    });
    for (const line of out.split("\n")) {
      const tty = line.trim();
      if (!/^\/dev\/(pts|tty)\d/.test(tty)) continue;
      try {
        writeFileSync(tty, "\x07");
        rung = true;
      } catch {
        /* skip un-writable tty */
      }
    }
  } catch {
    // tmux unavailable or no server — fall through to our own tty
  }
  if (!rung) {
    try {
      writeFileSync("/dev/tty", "\x07");
    } catch {
      debugLog("no controlling tty; skipping terminal bell");
    }
  }
}

function sendNotification(kind: "waiting" | "error" | "done" | "blocked"): void {
  const cfg = readConfig();
  if (cfg.notification_backend === "off") return;
  if (cfg.terminal_bell) ringBell();
  if (cfg.notification_backend === "bell") return; // terminal bell only
  const notify = resolveNotifySend();
  if (!notify) {
    debugLog("notify-send not found; skipping notification");
    return;
  }
  const project = projectLabel();
  const dir = st.cwd || "";
  const loc = tmuxLoc();
  let title: string;
  let body: string;
  let icon = "dialog-information";
  if (kind === "error") {
    title = "Pi agent error";
    icon = "dialog-error";
    body = `${project} · ${loc || "tmux"}\n${dir}\nThe agent encountered an error and needs your attention.`;
  } else if (kind === "done") {
    title = "Pi agent completed";
    body = `${project} · ${loc || "tmux"}\n${dir}\nThe current task has completed.`;
  } else if (kind === "blocked") {
    // Privacy-safe: never include the question text, tool args, or file paths.
    title = "Pi agent needs your attention";
    icon = "dialog-question";
    body =
      st.blocked_reason === "permission"
        ? `${project} · ${loc || "tmux"}\n${dir}\nThe agent needs your permission to continue.`
        : `${project} · ${loc || "tmux"}\n${dir}\nThe agent asked you a question and is waiting for your answer.`;
  } else {
    title = "Pi agent waiting for input";
    icon = "dialog-warning";
    body = `${project} · ${loc || "tmux"}\n${dir}\nPi finished a task and is waiting for your input.`;
  }
  execFile(notify, ["-a", "pi", "-i", icon, "-r", String(notifyId()), "-t", "10000", title, body], (err) => {
    if (err) debugLog(`notify-send failed: ${err.message}`);
  });
}

// Notify on a transition into an attention status, honoring dedup + config.
function maybeNotify(next: AgentState["status"]): void {
  const cfg = readConfig();
  if (!cfg.enabled) return;
  if (next === st.notify.last_sent_status) return; // dedup: no state change, no notification

  const attentionDuration = Date.now() - (st.last_user_input_at ?? st.started_at);
  if (next === "waiting") {
    const ok = cfg.notify_on_waiting || cfg.notify_on_done;
    if (!ok) return;
    if (attentionDuration < cfg.min_attention_duration_ms) {
      debugLog("settled too quickly; skipping waiting notification");
      return;
    }
    if (cfg.notify_on_waiting && cfg.notify_on_done && st.last_stop_reason === "stop") {
      sendNotification("done");
      sendNotification("waiting");
    } else if (cfg.notify_on_done && st.last_stop_reason === "stop") {
      sendNotification("done");
    } else if (cfg.notify_on_waiting) {
      sendNotification("waiting");
    } else {
      return;
    }
    st.notify = { last_sent_status: "waiting", last_sent_at: Date.now() };
  } else if (next === "blocked") {
    if (!cfg.notify_on_blocked) return;
    sendNotification("blocked");
    st.notify = { last_sent_status: "blocked", last_sent_at: Date.now() };
  } else if (next === "error") {
    if (!cfg.notify_on_error) return;
    sendNotification("error");
    st.notify = { last_sent_status: "error", last_sent_at: Date.now() };
  } else {
    // working/idle transitions never notify; reset the dedup marker so the
    // next attention transition fires again (WAITING→WORKING→WAITING).
    st.notify.last_sent_status = null;
  }
}

// Event wiring
export default function (pi: ExtensionAPI): void {
  debugLog("extension loaded");

  pi.on("session_start", (event, ctx) => {
    try {
      const sid = ctx.sessionManager.getSessionId();
      const sfile = ctx.sessionManager.getSessionFile() ?? null;
      const prev = sid && existsSync(join(agentsDir, `${sid}.json`))
        ? (JSON.parse(readFileSync(join(agentsDir, `${sid}.json`), "utf8")) as Partial<AgentState>)
        : null;

      st.session_id = sid ?? null;
      st.session_file = sfile;
      st.session_name = ctx.sessionManager.getSessionName() ?? null;
      st.cwd = ctx.cwd || process.cwd();
      st.started_at = prev?.started_at ?? Date.now();
      st.notify = prev?.notify ?? { last_sent_status: null, last_sent_at: null };
      st.last_user_input_at = null;
      st.last_error_at = null;
      st.has_worked = prev?.has_worked ?? false;
      blockedCount = 0;
      st.is_blocked = false;
      st.blocked_at = null;
      st.blocked_reason = null;
      agentActive = false;
      touch(true);
      debugLog(`session_start id=${sid} file=${sfile} cwd=${st.cwd}`);
    } catch (err) {
      debugLog(`session_start error: ${String(err)}`);
    }
  });

  pi.on("session_info_changed", (event) => {
    try {
      st.session_name = event.name ?? null;
      touch(true);
    } catch (err) {
      debugLog(`session_info_changed error: ${String(err)}`);
    }
  });

  pi.on("input", () => {
    try {
      st.last_user_input_at = Date.now();
      forceUnblock(); // the user is present; whatever was blocked is answered
      touch();
    } catch (err) {
      debugLog(`input error: ${String(err)}`);
    }
  });

  pi.on("agent_start", () => {
    try {
      agentActive = true;
      st.has_worked = true;
      st.last_error_at = null;
      st.last_activity_at = Date.now();
      forceUnblock(); // a new turn implies the user already engaged
      maybeNotify("working"); // resets dedup marker
      touch(true);
    } catch (err) {
      debugLog(`agent_start error: ${String(err)}`);
    }
  });

  pi.on("message_end", (event) => {
    try {
      const m = event.message as { role?: string; stopReason?: string; errorMessage?: string };
      st.last_activity_at = Date.now();
      if (m?.role === "assistant") {
        st.last_stop_reason = m.stopReason ?? null;
        if (m.stopReason === "error" || m.errorMessage) {
          st.last_error_at = Date.now();
          if (!agentActive) maybeNotify("error");
        }
      }
      touch();
    } catch (err) {
      debugLog(`message_end error: ${String(err)}`);
    }
  });

  // auto_retry_* are emitted by the runtime (agent-session.js) but not yet in
  // the typed event union of this pi version — subscribe via a cast.
  (pi.on as any)("auto_retry_start", () => {
    try {
      agentActive = true;
      touch();
    } catch (err) {
      debugLog(`auto_retry_start error: ${String(err)}`);
    }
  });

  (pi.on as any)("auto_retry_end", (event: { success?: boolean }) => {
    try {
      if (event.success === false) {
        st.last_error_at = Date.now();
        agentActive = false;
        maybeNotify("error");
        touch(true);
      } else {
        touch();
      }
    } catch (err) {
      debugLog(`auto_retry_end error: ${String(err)}`);
    }
  });

  pi.on("agent_settled", () => {
    try {
      agentActive = false;
      st.last_activity_at = Date.now();
      const next = deriveStatus();
      maybeNotify(next);
      touch(true);
      debugLog(`agent_settled -> ${next}`);
    } catch (err) {
      debugLog(`agent_settled error: ${String(err)}`);
    }
  });

  for (const evt of ["turn_start", "turn_end", "tool_execution_update", "message_update"] as const) {
    // the union of event names is wider than any single overload — cast
    pi.on(evt as any, () => {
      try {
        st.last_activity_at = Date.now();
        touch();
      } catch {
        /* ignore */
      }
    });
  }

  // tool_execution_start/end: an `ask_user_question` call blocks until the
  // user answers (the tool awaits the question UI), so the agent is BLOCKED.
  pi.on("tool_execution_start" as any, (event: { toolName?: string }) => {
    try {
      st.last_activity_at = Date.now();
      if (event?.toolName === "ask_user_question") {
        block("question");
      } else {
        touch();
      }
    } catch {
      /* ignore */
    }
  });
  pi.on("tool_execution_end" as any, (event: { toolName?: string }) => {
    try {
      st.last_activity_at = Date.now();
      if (event?.toolName === "ask_user_question") {
        release();
      } else {
        touch();
      }
    } catch {
      /* ignore */
    }
  });

  // permission-gate (or any extension publishing permission:* events): the
  // confirmation dialog blocks the tool until the user decides.
  const eventBus = (pi as any).events as { on?: (ch: string, cb: (data: unknown) => void) => void } | undefined;
  if (eventBus?.on) {
    eventBus.on("permission:ask", (data) => {
      try {
        debugLog(`permission:ask ${JSON.stringify(data)}`);
        block("permission");
      } catch {
        /* ignore */
      }
    });
    eventBus.on("permission:resolved", () => {
      try {
        release();
      } catch {
        /* ignore */
      }
    });
  }

  pi.on("session_shutdown", () => {
    try {
      st.alive = false;
      writeStateNow();
    } catch (err) {
      debugLog(`session_shutdown error: ${String(err)}`);
    }
  });
}
