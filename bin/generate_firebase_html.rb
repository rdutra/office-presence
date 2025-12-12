#!/usr/bin/env ruby
# frozen_string_literal: true

# Firebase HTML Generator
# This script renders the dashboard_modern.erb template as static HTML for Firebase deployment
# It includes Firebase-specific JavaScript and CSS overrides for mobile scrolling

require "bundler/setup"
require "sinatra/base"
require "erb"
require "stringio"

# Define paths
SCRIPT_DIR = File.expand_path(__dir__)
PROJECT_DIR = File.expand_path("..", SCRIPT_DIR)
TEMPLATE_PATH = File.join(PROJECT_DIR, "views", "dashboard_modern.erb")
OUTPUT_PATH = File.join(PROJECT_DIR, "firebase_public", "index.html")

# Check if template exists
unless File.exist?(TEMPLATE_PATH)
  puts "❌ Error: Template not found at #{TEMPLATE_PATH}"
  exit 1
end

puts "=" * 60
puts "Generating Firebase HTML from ERB template"
puts "=" * 60
puts ""

# Create a minimal Sinatra app just for rendering
class TemplateRenderer < Sinatra::Base
  set :root, PROJECT_DIR
  set :views, File.join(PROJECT_DIR, "views")

  # Override erb helper to prevent it from trying to render partials
  def erb(template_name, options = {})
    # If it's the _registration partial, return empty string for Firebase mode
    return "" if template_name == :_registration

    # Otherwise use the default Sinatra erb rendering
    super
  end
end

# Render the ERB template using Sinatra's rendering engine
def render_template
  app = TemplateRenderer.new

  # Create a mock request for Sinatra
  env = {
    'REQUEST_METHOD' => 'GET',
    'PATH_INFO' => '/',
    'SCRIPT_NAME' => '',
    'rack.url_scheme' => 'http',
    'SERVER_NAME' => 'localhost',
    'SERVER_PORT' => '4567',
    'rack.input' => StringIO.new,
    'rack.errors' => $stderr
  }

  # Use Sinatra's template rendering directly
  app.settings.set :views, File.join(PROJECT_DIR, "views")

  # Render using ERB directly with the template
  template_content = File.read(TEMPLATE_PATH, encoding: 'UTF-8')

  # Create a context with the data the template expects
  context = Object.new
  context.define_singleton_method(:now) { Time.now }
  context.define_singleton_method(:mapped_present) { [] }
  context.define_singleton_method(:mapped_absent) { [] }
  context.define_singleton_method(:present_count) { 0 }
  context.define_singleton_method(:total_people) { 0 }
  context.define_singleton_method(:top_attendees) { [] }
  context.define_singleton_method(:daily_record) { 0 }
  context.define_singleton_method(:all_time_record) { 0 }
  context.define_singleton_method(:current_week_start) { "" }
  context.define_singleton_method(:current_week_end) { "" }
  context.define_singleton_method(:last_week_winner) { nil }
  context.define_singleton_method(:show_in_office_tile) { true }
  context.define_singleton_method(:show_registered_users_tile) { true }
  context.define_singleton_method(:show_today_record_tile) { true }
  context.define_singleton_method(:show_all_time_record_tile) { true }
  context.define_singleton_method(:template_key) { :modern }
  context.define_singleton_method(:firebase_mode) { true }

  # Define the erb helper method for the context
  context.define_singleton_method(:erb) do |partial_name|
    # Don't include the registration partial in Firebase mode
    ""
  end

  # Render the template with UTF-8 encoding
  erb_template = ERB.new(template_content, trim_mode: '-')
  erb_template.result(context.instance_eval { binding }).force_encoding('UTF-8')
end

# Render the ERB template
rendered_html = render_template

# Post-process the HTML to add Firebase-specific code
# 1. Remove the registration modal (not needed in Firebase mode)
# 2. Remove registration-related scripts
# 3. Add Firebase JavaScript and CSS overrides

# Remove registration modal
rendered_html = rendered_html.gsub(/<div id="registrationModal"[^>]*>.*?<\/div>\s*(?=<script)/m, '')

# Remove registration scripts
rendered_html = rendered_html.gsub(%r{<script src="/js/registration\.js"></script>\s*}, '')

# Add Firebase-specific styles before </head>
firebase_styles = <<~FIREBASE_CSS
  <style>
    .loading {
      text-align: center;
      padding: 2rem 1rem;
      font-size: 1.2rem;
      opacity: 0.85;
    }

    .error {
      display: none;
      background: rgba(239, 68, 68, 0.2);
      border: 2px solid rgba(239, 68, 68, 0.5);
      border-radius: 0.5rem;
      padding: 1rem;
      margin: 0 0 1rem 0;
      text-align: center;
    }

    /* Firebase embed overrides - enable scrolling on mobile */
    body {
      overflow-y: auto;
    }

    .container {
      height: auto;
      min-height: calc(100vh - 2rem);
    }

    @media (max-width: 768px) {
      .container {
        min-height: auto;
        padding-bottom: 2rem;
      }
    }

    /* Hide register button in Firebase mode */
    .register-button {
      display: none !important;
    }
  </style>
</head>
FIREBASE_CSS

rendered_html = rendered_html.sub("</head>", firebase_styles)

# Add loading and error states at the beginning of body
loading_html = <<~LOADING_HTML
<body>
  <div id="loading" class="loading">Loading dashboard data...</div>
  <div id="error" class="error"></div>

LOADING_HTML

rendered_html = rendered_html.sub("<body>\n", loading_html)

# Wrap the container div to be hidden initially
rendered_html = rendered_html.sub('<div class="container">', '<div class="container" id="dashboard" style="display: none;">')

# Remove timezone.js and dashboard.js, replace with Firebase script
rendered_html = rendered_html.gsub(%r{<script src="/js/timezone\.js"></script>\s*}, '')
rendered_html = rendered_html.gsub(%r{<script src="/js/dashboard\.js"></script>\s*}, '')

# Add Firebase JavaScript before closing body tag
firebase_script = File.read(File.join(SCRIPT_DIR, "firebase_dashboard_script.js"))

rendered_html = rendered_html.sub("</body>", "\n  <script type=\"module\">\n#{firebase_script}\n  </script>\n</body>")

# Write the output
File.write(OUTPUT_PATH, rendered_html)

puts "✓ Generated Firebase HTML at: #{OUTPUT_PATH}"
puts "  Template: #{TEMPLATE_PATH}"
puts "  Output size: #{rendered_html.bytesize} bytes"
puts ""
puts "=" * 60
