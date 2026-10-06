#!/usr/bin/env zsh
# Thin wrapper: delegates all install logic to install.sh.
script_dir="${0:A:h}"
exec bash "$script_dir/install.sh" "$@"
