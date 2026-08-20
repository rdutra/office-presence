# frozen_string_literal: true

require "thread"

module OfficePresence
  module Services
    class Announcer
      @queue = Queue.new
      @worker = nil
      @mutex = Mutex.new

      class << self
        def announce(mac, db, logger)
          start_worker(db, logger)
          @queue << mac
        end

        private

        def start_worker(db, logger)
          @mutex.synchronize do
            return if @worker && @worker.alive?

            @worker = Thread.new do
              loop do
                mac = @queue.pop
                begin
                  process_announcement(mac, db, logger)
                rescue StandardError => e
                  logger.error "Announcer error: #{e.class}: #{e.message}"
                end
              end
            end
          end
        end

        def process_announcement(mac, db, logger)
          person = db[:people].where(mac: mac).first
          return unless person

          name = person[:person]
          return if name.nil? || name.empty? || name.start_with?("Anonymous")

          logger.info "Announcing arrival for: #{name}"

          play_intro(logger)

          audio_filename = person[:audio_filename]
          if audio_filename && !audio_filename.empty?
            audio_path = File.join(OfficePresence::ROOT, 'public', 'audio', audio_filename)
            if File.exist?(audio_path)
              system("afplay '#{audio_path}'")
              return
            else
              logger.warn "Audio file not found: #{audio_path}, falling back to TTS"
            end
          end

          # Fallback to Text-to-Speech
          system("say '#{name}'")
        end

        def play_intro(logger)
          intros_dir = File.join(OfficePresence::ROOT, 'public', 'audio', 'intros')
          return unless Dir.exist?(intros_dir)

          intros = Dir.glob(File.join(intros_dir, '*.*')).reject { |f| File.directory?(f) }
          return if intros.empty?

          intro = intros.sample
          system("afplay '#{intro}'")
        end
      end
    end
  end
end
