# Puma configuration
bind "tcp://0.0.0.0:9292"

# Project root
root = File.expand_path("..", __dir__)

# Logging
stdout_redirect "#{root}/logs/puma_stdout.log", "#{root}/logs/puma_stderr.log", true

# PID file
pidfile "#{root}/tmp/pids/puma.pid"

# State file
state_path "#{root}/tmp/pids/puma.state"

# Workers and threads
workers 2
threads 1, 6

# Preload application
preload_app!