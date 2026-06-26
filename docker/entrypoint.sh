#!/bin/sh
set -eu

mkdir -p log tmp/pids

exec "$@"
