#!/bin/bash
# Firebase Sync Service Wrapper
# This script is used by launchd to run the scheduler

cd /Users/rodrigodutra/dev/personal/office-presence
exec bundle exec ruby bin/firebase_scheduler.rb
