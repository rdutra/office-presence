# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("lib", __dir__)

require "office_presence/web_app"

run OfficePresence::WebApp
