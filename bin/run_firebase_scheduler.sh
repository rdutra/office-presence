#!/bin/bash
# Firebase Sync Service Wrapper
# This script is used by launchd to run the scheduler

cd /Users/rodrigodutra/dev/personal/office-presence

using_wrapper=0
if [ -f ".ruby-version" ]; then
  ruby_version="$(tr -d '[:space:]' < .ruby-version)"
  wrapper_dir="$HOME/.rvm/wrappers/ruby-$ruby_version"
  if [ -d "$wrapper_dir" ]; then
    export PATH="$wrapper_dir:$PATH"
    using_wrapper=1
  fi
fi

if [ -s "$HOME/.rvm/scripts/rvm" ] && [ "$using_wrapper" -eq 0 ]; then
  # shellcheck disable=SC1090
  source "$HOME/.rvm/scripts/rvm"
  rvm use . > /dev/null 2>&1 || true
fi

exec bundle exec ruby bin/firebase_scheduler.rb
