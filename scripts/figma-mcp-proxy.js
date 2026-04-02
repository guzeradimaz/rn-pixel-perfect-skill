#!/usr/bin/env node
'use strict';

/**
 * MCP Figma Server Proxy with auto-restart.
 *
 * Wraps figma-mcp-go (@vkhanhqui/figma-mcp-go) — a Figma MCP server
 * that reads data via Figma Desktop plugin bridge, bypassing API rate limits.
 * This proxy detects crashes and restarts the server automatically,
 * replaying the MCP init handshake so Claude Code never sees the interruption.
 *
 * Prerequisites:
 *   1. Figma Desktop app running
 *   2. figma-mcp-go plugin installed and active in the Figma file
 *      (Plugins → Development → Import plugin from manifest)
 *
 * Usage in ~/.claude/settings.json:
 *
 *   "figma-mcp-go": {
 *     "command": "node",
 *     "args": ["~/.claude/scripts/figma-mcp-proxy.js"]
 *   }
 *
 * No API key needed — data is read via plugin bridge, not REST API.
 * All extra CLI args are forwarded to @vkhanhqui/figma-mcp-go as-is.
 */

const { spawn } = require('child_process');

// ─── Config ─────────────────────────────────────────────
const MAX_RESTARTS = 10;
const BASE_DELAY_MS = 2000;        // 2s initial, grows with backoff
const MAX_DELAY_MS = 10000;        // 10s cap
const STABLE_AFTER_MS = 60_000;    // reset counter after 1 min of uptime

// ─── State ──────────────────────────────────────────────
let child = null;
let childAlive = false;
let restartCount = 0;
let lastSpawnTime = 0;
let shuttingDown = false;

// Cache raw init messages from Claude Code for replay on restart.
// MCP handshake: client sends "initialize" request → server responds →
// client sends "notifications/initialized" notification → ready.
let initRequestBuf = null;
let initNotifyBuf = null;

// Messages that arrived while the child was dead — flush after restart.
let pendingWrites = [];

// ─── Helpers ────────────────────────────────────────────
const log = (msg) => process.stderr.write(`[figma-mcp-proxy] ${msg}\n`);

function writeToChild(data) {
  if (childAlive && child?.stdin?.writable) {
    try {
      child.stdin.write(data);
      return true;
    } catch {
      return false;
    }
  }
  return false;
}

// ─── Spawn / Restart ────────────────────────────────────
function spawnServer() {
  const now = Date.now();
  if (now - lastSpawnTime > STABLE_AFTER_MS) {
    restartCount = 0; // server was stable — reset counter
  }
  lastSpawnTime = now;

  // Forward all CLI args after our script to the real server
  const serverArgs = [
    '-y', '@vkhanhqui/figma-mcp-go',
    ...process.argv.slice(2),
  ];

  log(restartCount > 0
    ? `Restarting server (attempt ${restartCount}/${MAX_RESTARTS})...`
    : 'Starting server...');

  child = spawn('npx', serverArgs, {
    stdio: ['pipe', 'pipe', 'inherit'], // inherit stderr for server logs
    env: process.env,
  });
  childAlive = true;

  // Pipe server stdout → Claude Code
  child.stdout.on('data', (chunk) => {
    try {
      process.stdout.write(chunk);
    } catch {
      // Claude Code closed the pipe — shut down
      shutdown();
    }
  });

  child.on('error', (err) => {
    log(`Server error: ${err.message}`);
    childAlive = false;
    if (!shuttingDown) scheduleRestart();
  });

  child.on('close', (code, signal) => {
    childAlive = false;
    if (shuttingDown) return;
    if (code === 0 && !signal) {
      log('Server exited cleanly.');
      shutdown();
      return;
    }
    log(`Server crashed (code=${code}, signal=${signal})`);
    scheduleRestart();
  });

  // Flush any data that arrived while the child was down
  if (pendingWrites.length > 0) {
    log(`Flushing ${pendingWrites.length} queued message(s)...`);
    for (const buf of pendingWrites) writeToChild(buf);
    pendingWrites = [];
  }
}

function scheduleRestart() {
  child = null;
  childAlive = false;
  restartCount++;

  if (restartCount > MAX_RESTARTS) {
    log(`Max restarts (${MAX_RESTARTS}) exceeded. Giving up.`);
    process.exit(1);
  }

  const delay = Math.min(BASE_DELAY_MS * restartCount, MAX_DELAY_MS);
  log(`Will restart in ${delay}ms...`);

  setTimeout(() => {
    spawnServer();
    replayInit();
  }, delay);
}

function replayInit() {
  if (!initRequestBuf) return;

  log('Replaying MCP init handshake...');
  writeToChild(initRequestBuf);

  if (initNotifyBuf) {
    // Small delay so server processes "initialize" before "initialized"
    setTimeout(() => writeToChild(initNotifyBuf), 200);
  }
}

// ─── stdin from Claude Code ─────────────────────────────
process.stdin.on('data', (chunk) => {
  const text = chunk.toString();

  // Cache init handshake messages for replay on restart.
  // MCP uses newline-delimited JSON-RPC over stdio.
  // "initialize" — the first request from client.
  // "notifications/initialized" — confirmation after server responds.
  if (text.includes('"method"') && text.includes('"initialize"')) {
    if (text.includes('notifications/initialized') || text.includes('initialized"')) {
      // Could be the "initialized" notification — check more carefully
      if (text.includes('notifications/initialized')) {
        initNotifyBuf = Buffer.from(chunk);
      } else if (!text.includes('notifications')) {
        // Pure "initialize" request (not "initialized")
        initRequestBuf = Buffer.from(chunk);
      }
    } else {
      initRequestBuf = Buffer.from(chunk);
    }
  }

  // Forward to child or queue
  if (!writeToChild(chunk)) {
    pendingWrites.push(Buffer.from(chunk));
  }
});

process.stdin.on('end', () => shutdown());

// ─── Graceful shutdown ──────────────────────────────────
function shutdown() {
  if (shuttingDown) return;
  shuttingDown = true;
  if (child && !child.killed) {
    child.kill('SIGTERM');
  }
  setTimeout(() => process.exit(0), 500);
}

process.on('SIGTERM', shutdown);
process.on('SIGINT', shutdown);

// ─── Start ──────────────────────────────────────────────
spawnServer();
