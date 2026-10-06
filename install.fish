#!/usr/bin/env fish
# Thin wrapper: delegates all install logic to install.sh.
set -l script_dir (dirname (status -f))
exec bash "$script_dir/install.sh" $argv
