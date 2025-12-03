# frozen_string_literal: true

require "dotenv"

module OfficePresence
  ROOT = File.expand_path("..", __dir__)
  DATA_DIR = File.join(ROOT, "data")
  DB_PATH = File.join(DATA_DIR, "presence.sqlite")
  MIGRATIONS_DIR = File.join(ROOT, "db/migrations")

  Dotenv.load(File.join(ROOT, ".env")) if File.exist?(File.join(ROOT, ".env"))
end

require_relative "office_presence/utils"
require_relative "office_presence/config"
require_relative "office_presence/database"
require_relative "office_presence/scanner"
