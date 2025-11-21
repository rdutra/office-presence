require "sequel"
require "logger"
require_relative "lib/office_presence/services/device_identity_service"
require_relative "lib/office_presence/database"

# Setup in-memory DB
db = Sequel.sqlite
OfficePresence::Database.ensure_schema(db)

# Create service
service = OfficePresence::Services::DeviceIdentityService.new(db)

# Setup test data
old_mac = "11:11:11:11:11:11"
new_mac = "22:22:22:22:22:22"
device_id = "unique-device-id"

# 1. Create existing device (old_mac)
db[:devices].insert(
  mac: old_mac,
  ip: "192.168.1.10",
  last_seen_utc: "2023-01-01T10:00:00Z",
  hostname: "old-host",
  device_id: device_id
)
db[:people].insert(mac: old_mac, person: "Alice", visible: true)
db[:attendance].insert(mac: old_mac, date: "2023-01-01", first_seen_utc: "2023-01-01T10:00:00Z", last_seen_utc: "2023-01-01T18:00:00Z")

# 2. Create temporary new device (new_mac) - simulating it was just discovered
db[:devices].insert(
  mac: new_mac,
  ip: "192.168.1.20",
  last_seen_utc: "2023-01-02T10:00:00Z",
  hostname: "new-host",
  device_id: nil # new discovery might not have associated it yet, or it might have
)
# Simulate some attendance for new_mac too
db[:attendance].insert(mac: new_mac, date: "2023-01-02", first_seen_utc: "2023-01-02T10:00:00Z", last_seen_utc: "2023-01-02T10:05:00Z")

puts "--- Before Migration ---"
puts "Devices: #{db[:devices].count}"
puts "People: #{db[:people].count}"
puts "Attendance: #{db[:attendance].count}"
puts "Old MAC Device: #{db[:devices].where(mac: old_mac).first.inspect}"
puts "New MAC Device: #{db[:devices].where(mac: new_mac).first.inspect}"

# 3. Run Migration
puts "\n--- Running Migration ---"
existing_record = db[:devices].where(mac: old_mac).first
service.migrate_identity(
  existing_record: existing_record,
  new_mac: new_mac,
  ip: "192.168.1.20",
  hostname: "new-host",
  last_seen_utc: "2023-01-02T10:00:00Z"
)

puts "\n--- After Migration ---"
puts "Devices: #{db[:devices].count}"
puts "People: #{db[:people].count}"
puts "Attendance: #{db[:attendance].count}"

old_dev = db[:devices].where(mac: old_mac).first
new_dev = db[:devices].where(mac: new_mac).first
person = db[:people].where(mac: new_mac).first
attendance_count = db[:attendance].where(mac: new_mac).count

puts "Old MAC Device exists?: #{!old_dev.nil?}"
puts "New MAC Device exists?: #{!new_dev.nil?}"
puts "New MAC Device IP: #{new_dev[:ip]}"
puts "Person moved to New MAC?: #{!person.nil? && person[:person] == 'Alice'}"
puts "Attendance moved to New MAC?: #{attendance_count == 2}"

if old_dev.nil? && !new_dev.nil? && new_dev[:mac] == new_mac && !person.nil? && attendance_count == 2
  puts "\nSUCCESS: Migration worked correctly."
else
  puts "\nFAILURE: Migration failed."
end
