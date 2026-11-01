#!/usr/bin/env bash
# Runs zonetool.exe inside the shadow workspace under Wine (GE-Proton's wine), memory-capped.
# Wine needs *some* display to build its desktop, so it runs on a private headless gamescope
# X server: nothing is ever shown on the real desktop.
# Usage: run-zonetool.sh -verifyzone patch_mp_zombie_h2o
#        run-zonetool.sh -dumpzone common_mp
#        run-zonetool.sh -buildzone exo_weapons_all
# Env:   MEM (default 8G), TIMEOUT seconds (default 3600), WINEDEBUG (default -all),
#        WRAP (debug prefix, e.g. WRAP="strace -f -o /tmp/st.log -e trace=%file"),
#        CRASH_HOLD=N (after a ZoneTool crash keep the dead-but-alive process around until $WS/crash-release
#        exists or N seconds passed, so an ancestor shell can read its memory; see dump-crash.sh).
#        CMDS=<file> (with no zonetool args) = console mode: feed the file's lines to ZoneTool's console, see below.
# A crash shows up as a "[run-zonetool] zonetool.exe crashed: <zip>" line on stderr plus a new
# minidumps/zonetool-crash-*.zip. gamescope swallows the exit status, so it cannot be used to detect it.
# An engine "Fatal Error" dialog is screenshotted to logs/fatal-*.png (path printed on stderr), then dismissed.
# Zones that reference assets of other zones need those loaded first, e.g. (the order ZoneTool's dumpmap uses):
#        run-zonetool.sh -loadzone patch_common_mp -loadzone common_mp -loadzone techsets_common_core_mp -dumpzone mp_zombie_h2o
set -euo pipefail

WS="${WS:-$HOME/zonetool-workspace}"
GE="${GE:-$HOME/.local/share/Steam/compatibilitytools.d/GE-Proton11-11-x86_64}"
MEM="${MEM:-8G}"
TIMEOUT="${TIMEOUT:-3600}"   # seconds; systemd kills the whole scope (wine daemons included) after this

export WINEPREFIX="$WS/pfx" WINEARCH=win64 WINEDEBUG="${WINEDEBUG:--all}"
# d3d11/dxgi come from DXVK (copied next to the exe); the renderer itself is never started.
export WINEDLLOVERRIDES="mscoree,mshtml=;winemenubuilder.exe=d;d3d11,dxgi=n"

if [ "${1:-}" = "--inner" ]; then
  shift
  cd "$WS"
  # The wine child must not find the real compositor's Wayland socket (default name in XDG_RUNTIME_DIR),
  # so it gets an empty runtime dir; gamescope and systemd-run keep the real one.
  mkdir -p -m 700 "$WS/xdg"
  # zonetool.exe block-buffers stdout and quick_exit()s without flushing, so a redirected log loses its tail
  # (or all of it for short runs). Running it on a pty makes the Windows CRT line-buffer instead.
  # shellcheck disable=SC2206
  INNER=$(printf '%q ' env -u WAYLAND_DISPLAY "XDG_RUNTIME_DIR=$WS/xdg" ${WRAP:-} nice -n 10 "$GE/files/bin/wine" zonetool.exe "$@")
  # The wide window keeps long asset names on one line.
  CHILD=(script -qefc "stty cols 2000 rows 50 2>/dev/null; exec $INNER" /dev/null)

  # A ZoneTool crash writes minidumps/zonetool-crash-*.zip and then blocks forever in a modal MessageBox, which
  # on a headless run looks exactly like a hang. Watch for a new crash zip, optionally keep the process alive for
  # a while (CRASH_HOLD) so that dump-crash.sh can read its memory, then stop the run.
  crash_baseline=$(find "$WS/minidumps" -maxdepth 1 -name '*.zip' 2>/dev/null | wc -l)
  crashed=""
  fatal_shot=""

  if [ -n "${CMDS:-}" ]; then
    # Console mode (no command-line args): the lines of $CMDS are typed into ZoneTool's console once its prompt is
    # up. Only the console has a type filter ("dumpzone s1 <zone> <type,type,...>"); the command line does not.
    # gamescope does not forward stdin, and input sent before the console exists gets lost, hence the feeder.
    # The feeder keeps the input open on purpose (EOF would end the console), so end $CMDS with "quit".
    # It is its own job reading through a FIFO, not the left side of a pipeline: bash's "wait" on a pipeline member
    # waits for the whole pipeline, which would never end.
    mkdir -p "$WS/logs"
    ptylog="$WS/logs/.pty.out"
    cmdfifo="$WS/logs/.cmds.fifo"
    rm -f "$ptylog" "$cmdfifo"
    mkfifo "$cmdfifo"
    CHILD=(script -qefc "stty cols 2000 rows 50 2>/dev/null; exec $INNER" "$ptylog")
    (
      for _ in $(seq 1 900); do
        grep -q 'initialization complete' "$ptylog" 2>/dev/null && break
        sleep 1
      done
      sleep 2
      # Wine's console takes Enter as CR; a bare LF is just a character in the input line.
      sed 's/\r$//; s/$/\r/' "$CMDS"
      exec sleep infinity
    ) > "$cmdfifo" &
    feeder=$!
    "${CHILD[@]}" < "$cmdfifo" &
  else
    feeder=""
    "${CHILD[@]}" &
  fi
  wpid=$!
  seen=0
  while kill -0 "$wpid" 2>/dev/null; do
    if pgrep -u "$(id -u)" -x zonetool.exe >/dev/null; then
      seen=1
    elif [ "$seen" = 1 ]; then
      break
    fi
    # The engine reports a fatal asset error (e.g. a missing default asset) in a modal "Fatal Error" dialog and
    # waits for OK forever. Save a screenshot of it (the text is not in the log), then press Enter: the
    # engine exits right after.
    if [ -z "$fatal_shot" ]; then
      fwin=$(xdotool search --onlyvisible --name '^(Fatal Error|Error)$' 2>/dev/null | head -n1 || true)
      if [ -n "$fwin" ]; then
        mkdir -p "$WS/logs"
        fatal_shot="$WS/logs/fatal-$(date +%H%M%S).png"
        ffmpeg -hide_banner -loglevel error -f x11grab -window_id "$fwin" -draw_mouse 0 -i "$DISPLAY" -frames:v 1 \
          -vf scale=iw*3:ih*3:flags=neighbor "$fatal_shot" || fatal_shot="(screenshot failed)"
        echo "[run-zonetool] zonetool.exe hit a fatal-error dialog, screenshot: $fatal_shot" >&2
        xdotool key Return || true
        sleep 2
      fi
    fi
    if [ "$(find "$WS/minidumps" -maxdepth 1 -name '*.zip' 2>/dev/null | wc -l)" -gt "$crash_baseline" ]; then
      sleep 2
      crashed=$(find "$WS/minidumps" -maxdepth 1 -name '*.zip' -printf '%T@ %p\n' | sort -n | tail -n1 | cut -d' ' -f2-)
      echo "[run-zonetool] zonetool.exe crashed: $crashed" >&2
      if [ -n "${CRASH_HOLD:-}" ]; then
        for _ in $(seq 1 "$CRASH_HOLD"); do
          [ -e "$WS/crash-release" ] && break
          sleep 1
        done
      fi
      "$GE/files/bin/wineserver" -k || true
      break
    fi
    sleep 1
  done

  # zonetool.exe is gone but wine's service processes can deadlock on teardown and keep the launcher
  # alive; give it a moment, then shut the prefix down.
  for _ in 1 2 3 4 5 6 7 8 9 10; do
    kill -0 "$wpid" 2>/dev/null || break
    sleep 1
  done
  if kill -0 "$wpid" 2>/dev/null; then
    echo "[run-zonetool] zonetool.exe exited but wine did not; running wineserver -k" >&2
    "$GE/files/bin/wineserver" -k || true
    sleep 2
    kill -0 "$wpid" 2>/dev/null && kill "$wpid" || true
  fi
  rc=0
  wait "$wpid" || rc=$?
  if [ -n "${feeder:-}" ]; then
    kill "$feeder" 2>/dev/null || true
    rm -f "$WS/logs/.cmds.fifo"
  fi
  # Wine sometimes leaves a zombie winedevice.exe whose helper threads never exit; gamescope's reaper then waits
  # forever (until TIMEOUT). Everything is in the log by now, so SIGKILL whatever is left in this scope except
  # this script, its reaper and gamescope.
  keep=" $$ $PPID $(ps -o ppid= -p "$PPID" 2>/dev/null | tr -d ' ') "
  mapfile -t scope_pids < "/sys/fs/cgroup$(sed -n 's/^0:://p' /proc/self/cgroup)/cgroup.procs" 2>/dev/null || scope_pids=()
  for pid in "${scope_pids[@]}"; do
    case "$keep" in *" $pid "*) ;; *) kill -9 "$pid" 2>/dev/null || true ;; esac
  done

  [ -n "$crashed" ] && exit 99
  exit "$rc"
fi

exec systemd-run --user --scope --quiet -p MemoryMax="$MEM" -p MemorySwapMax=0 \
  -p RuntimeMaxSec="$TIMEOUT" -p TimeoutStopSec=5 \
  gamescope --backend headless -W 1280 -H 720 -- "$(readlink -f "$0")" --inner "$@"
