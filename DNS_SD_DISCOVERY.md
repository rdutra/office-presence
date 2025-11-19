# DNS-SD Device Discovery

## Overview

The scanner now uses **DNS Service Discovery (DNS-SD)** via mDNS/Bonjour to identify devices using **persistent identifiers** instead of relying solely on MAC addresses.

## Quick Start

**To enable DNS-SD scanning:**

```bash
# 1. Setup passwordless sudo for nmap
./bin/setup_sudo_nmap.sh

# 2. Run migration to add new columns
bundle exec ruby bin/migrate_dns_sd.rb

# 3. Restart server to start using DNS-SD
./bin/server_restart.sh

# 4. Watch logs to see device discovery
tail -f logs/scanner.log
```

## Why This Change?

**Problem:** Wi-Fi MAC addresses change when devices connect through different access points/repeaters, making it impossible to reliably track the same device.

**Solution:** Use service identifiers that remain constant:
- **AirPlay Device ID** - Persistent identifier used by AirPlay
- **Bluetooth Address (rpBA)** - Hardware address used for Continuity features
- **Hostname** - Human-readable device name

## How It Works

### 1. DNS-SD Scan Command
```bash
sudo nmap -sU -p 5353 --script=dns-service-discovery 192.168.12.0/24
```

This discovers services on the network including:
- AirPlay (port 7000)
- Printer services (IPP/IPPS)
- Companion Link (Apple Continuity)

### 2. Extracted Information

For each device, we extract:

| Field | Description | Example | Priority |
|-------|-------------|---------|----------|
| **device_id** | AirPlay Device ID or Bluetooth Address | `EE:8C:24:FF:02:D6` | Primary identifier |
| **hostname** | Device hostname from mDNS | `MacBook-Pro-de-Victoria` | Display name |
| **ip** | Current IP address | `192.168.12.51` | Network location |
| **mac** | Wi-Fi MAC address | `02:8D:0D:16:99:A9` | Fallback identifier |

### 3. Identifier Priority

1. **device_id** (from AirPlay `deviceid=` field)
   - Most persistent
   - Survives Wi-Fi roaming
   - Used as primary key if available

2. **rpBA** (from companion-link, fallback)
   - Bluetooth hardware address
   - Also very persistent
   - Used if deviceid not found

3. **mac** (Wi-Fi MAC, last resort)
   - Changes with roaming
   - Only used if no service ID available

## Database Schema

### New Columns

```ruby
db.alter_table(:devices) do
  add_column :hostname, String      # e.g., "MacBook-Pro-de-Victoria"
  add_column :device_id, String     # e.g., "EE:8C:24:FF:02:D6"
end
```

## Database Schema

### Columns

```ruby
db.create_table(:devices) do
  String :mac, primary_key: true      # Current MAC address (primary key)
  String :ip                          # Current IP address
  String :last_seen_utc               # Last seen timestamp
  String :hostname                    # mDNS hostname (e.g., "MacBook-Pro-de-Victoria")
  String :device_id                   # Persistent AirPlay/Bluetooth ID
end
```

### Tracking Strategy

**Persistent Identifier Priority:**
1. **device_id** - AirPlay Device ID or Bluetooth rpBA (most persistent)
2. **hostname** - Human-readable device name
3. **mac** - Wi-Fi MAC address (changes with network roaming)

**How it works:**
- Each device is stored with its current MAC as the primary key
- `device_id` is stored as a **separate column** for persistent tracking
- When a device roams and gets a new MAC, the system detects it by `device_id` and **updates the MAC** in place
- This ensures the same database record tracks the device consistently

**Example Timeline:**
```
Day 1: Device connects to AP1
  mac: 02:8D:0D:16:99:A9
  device_id: 5E:8B:7C:71:69:75
  hostname: MacBook-Pro-de-Victoria

Day 2: Device roams to AP2 (new MAC)
  mac: 0A:1B:2C:3D:4E:5F  ← Updated
  device_id: 5E:8B:7C:71:69:75  ← Same!
  hostname: MacBook-Pro-de-Victoria

→ Same database record, MAC updated automatically
```

## Migration

### For Existing Installations

```bash
# Run the migration script
bundle exec ruby bin/migrate_dns_sd.rb

# Restart the server
./bin/server_restart.sh
```

The migration:
- Adds new columns to existing database
- Preserves all existing data
- Next scan will populate the new fields

### For New Installations

No action needed - the schema is created automatically.

## Benefits

✅ **Persistent Tracking** - Device identity survives Wi-Fi roaming  
✅ **Better UX** - Shows human-readable hostnames  
✅ **More Reliable** - AirPlay/Bluetooth IDs don't change  
✅ **Backward Compatible** - Falls back to MAC for non-Apple devices  

## Limitations

### Requires sudo

The DNS-SD scan requires root privileges:
```bash
sudo nmap -sU -p 5353 --script=dns-service-discovery ...
```

**Solutions:**
1. Run the scanner as root
2. Configure sudoers to allow nmap without password
3. Use setuid on nmap binary (security risk)

### Apple Devices Only

AirPlay Device ID and Bluetooth addresses are primarily available on:
- macOS devices
- iOS/iPadOS devices
- Apple TV

**For non-Apple devices:**
- Falls back to MAC address
- Still works, just less persistent

### Scan Time

DNS-SD scans take longer (~60-90 seconds vs 30-60 seconds).

## Configuration

### Passwordless Sudo Setup

The DNS-SD scan requires sudo privileges. To avoid password prompts, run the setup script:

```bash
./bin/setup_sudo_nmap.sh
```

This configures `/etc/sudoers.d/nmap` to allow passwordless sudo for nmap only. You'll be asked for your password **once** during setup.

**Manual setup:**
```bash
# Find nmap path
which nmap
# Output: /usr/local/bin/nmap (or similar)

# Add to sudoers (replace YOUR_USERNAME and path)
echo "YOUR_USERNAME ALL=(ALL) NOPASSWD: /usr/local/bin/nmap" | sudo tee /etc/sudoers.d/nmap
sudo chmod 0440 /etc/sudoers.d/nmap
```

### Scanner Configuration

The scan is configured in `lib/office_presence/scanner.rb`:

```ruby
def run_nmap(subnet)
  cmd = ["sudo", "nmap", "-sU", "-p", "5353", 
         "--script=dns-service-discovery", subnet]
  # ...
end
```

## Troubleshooting

### "Permission denied" errors

Ensure nmap can run with sudo:
```bash
# Test manually
sudo nmap -sU -p 5353 --script=dns-service-discovery 192.168.12.0/24
```

### No device_id found

Some devices may not advertise AirPlay or Companion services:
- Check if device has AirPlay enabled
- Check if device has Bluetooth/Continuity enabled
- System will fall back to MAC address

### Hostname showing as nil

Device may not be advertising hostname via mDNS:
- Check if device has Bonjour/mDNS enabled
- Some devices use IP-based hostnames
- Not critical - device tracking still works

## Example Output

### Before (MAC-based)
```
Device: 02:8D:0D:16:99:A9
IP: 192.168.12.51
```

### After (DNS-SD)
```
Device: MacBook-Pro-de-Victoria
ID: EE:8C:24:FF:02:D6
IP: 192.168.12.51
MAC: 02:8D:0D:16:99:A9
```

## References

- [RFC 6763 - DNS-Based Service Discovery](https://tools.ietf.org/html/rfc6763)
- [Apple Bonjour Overview](https://developer.apple.com/bonjour/)
- [Nmap NSE Scripts](https://nmap.org/nsedoc/scripts/dns-service-discovery.html)
