#!/bin/bash
# Start Teedy on Railway: sizes the JVM to the service's real limits, waits for
# Postgres, sets the generated admin password on first boot, then runs Jetty as PID 1.
set -euo pipefail

log() { echo "[railway-start] $*"; }

# --- admin password (first boot only: Teedy changes it only while it is still the default "admin") ---
if [ -z "${ADMIN_PASSWORD:-}" ]; then
  log "ADMIN_PASSWORD is empty; refusing to start with Teedy's default admin/admin login." >&2
  exit 1
fi
DOCS_ADMIN_PASSWORD_INIT="$(java -Xmx32m -XX:TieredStopAtLevel=1 -cp '/opt/railway:/opt/railway/lib/*' HashPassword)"
export DOCS_ADMIN_PASSWORD_INIT
unset ADMIN_PASSWORD

# --- CPU and memory from the cgroup, not the host (Railway hosts show 32+ CPUs) ---
cpus=2
if [ -r /sys/fs/cgroup/cpu.max ]; then
  read -r quota period < /sys/fs/cgroup/cpu.max || true
  if [ "${quota:-max}" != "max" ] && [ -n "${period:-}" ]; then
    cpus=$(( (quota + period - 1) / period ))
  fi
fi
[ "$cpus" -lt 1 ] && cpus=1
[ "$cpus" -gt 4 ] && cpus=4

mem_mb=0
if [ -r /sys/fs/cgroup/memory.max ]; then
  m=$(cat /sys/fs/cgroup/memory.max)
  [ "$m" != "max" ] && mem_mb=$(( m / 1048576 ))
fi
if [ -n "${TEEDY_HEAP_MB:-}" ]; then
  heap=$TEEDY_HEAP_MB
elif [ "$mem_mb" -le 0 ] || [ "$mem_mb" -ge 4096 ]; then
  heap=1024                       # upstream's own default (-Xmx1g)
else
  heap=$(( mem_mb * 40 / 100 ))   # leave room for metaspace, code, malloc and the tesseract/ffmpeg processes
  # Under 900 MB OCR is switched off (see below), so the heap can take half of the memory.
  [ "$mem_mb" -lt 900 ] && heap=$(( mem_mb / 2 ))
  [ "$heap" -lt 160 ] && heap=160
fi
# Small plans (under 1.5 GB): C1 JIT only, a smaller code cache and two malloc arenas keep
# the JVM's native memory down so OCR jobs fit next to it.
jit_opts="-XX:ReservedCodeCacheSize=64m"
if [ "$mem_mb" -gt 0 ] && [ "$mem_mb" -lt 1536 ]; then
  jit_opts="-XX:TieredStopAtLevel=1 -XX:ReservedCodeCacheSize=32m"
fi
export MALLOC_ARENA_MAX="${MALLOC_ARENA_MAX:-2}"
log "cgroup: ${cpus} CPU, memory limit ${mem_mb:-0} MB (0 = none); Java heap ${heap} MB"

# --- database ---
if [ -n "${DATABASE_URL:-}" ]; then
  hp="${DATABASE_URL#jdbc:postgresql://}"; hp="${hp%%/*}"
  host="${hp%:*}"; port="${hp##*:}"; [ "$port" = "$hp" ] && port=5432
  log "waiting for Postgres at ${host}:${port}"
  for i in $(seq 1 90); do
    if (exec 3<>"/dev/tcp/${host}/${port}") 2>/dev/null; then break; fi
    if [ "$i" -eq 90 ]; then log "Postgres did not answer in 3 minutes" >&2; exit 1; fi
    sleep 2
  done
fi
export DATABASE_POOL_SIZE="${DATABASE_POOL_SIZE:-5}"

# --- public URL used in e-mails and share links ---
if [ -z "${DOCS_BASE_URL:-}" ] && [ -n "${RAILWAY_PUBLIC_DOMAIN:-}" ]; then
  export DOCS_BASE_URL="https://${RAILWAY_PUBLIC_DOMAIN}"
fi

mkdir -p /data

# --- OCR memory guard: OCR of one scanned page needs about 0.6 GB (see OcrGuard.java) ---
ocr_mode=large
if [ "$mem_mb" -gt 0 ] && [ "$mem_mb" -lt 900 ]; then ocr_mode=small; fi
if [ -n "${DATABASE_URL:-}" ]; then
  java -Xmx24m -Xss256k -XX:TieredStopAtLevel=1 -XX:+UseSerialGC -cp '/opt/railway:/opt/railway/lib/*' OcrGuard "$ocr_mode" &
fi

exec java \
  -Dfile.encoding=UTF-8 \
  -Xms64m -Xmx${heap}m \
  -Xss512k \
  -XX:MaxMetaspaceSize=128m \
  ${jit_opts} \
  -XX:MaxDirectMemorySize=64m \
  -XX:+UseSerialGC \
  -XX:ActiveProcessorCount=${cpus} \
  -XX:+ExitOnOutOfMemoryError \
  -Djava.awt.headless=true \
  -jar /opt/jetty/start.jar \
  jetty.http.port="${PORT:-8080}" \
  jetty.threadPool.maxThreads=50
