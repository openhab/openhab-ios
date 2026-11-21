# Unused xcstrings candidates

These keys were not found in any first-party Swift/ObjC source file
(search path: all directories, `--include=*.swift *.m *.intentdefinition`).
They are candidates for deletion from `Localizable.xcstrings`.

**Before deleting:** verify in Xcode that "References to this key could not be
found in source code" still appears for each key after a fresh build. Some keys
that use `${variable}` syntax may be AppShortcut phrase templates declared in
AppIntents metadata and therefore not literal Swift strings.

Generated: 2026-08-15 (branch `menustructure_refactoring_clean`)

---

## Snake_case legacy keys (old UIKit settings era)

- `active_url`
- `always_allow_webrtc`
- `always_send_credentials`
- `app_version`
- `application_settings`
- `certificate_import_password`
- `certificate_import_text`
- `certificate_import_title`
- `clear_image_cache`
- `clear_web_cache`
- `connecting_discovered`
- `connecting_local`
- `connecting_remote`
- `copy_label`
- `crash_detected`
- `demo_mode`
- `disable_idle_timeout`
- `discovering_oh`
- `empty.itemname`
- `empty.itemorhome`
- `empty_sitemap`
- `icon_type`
- `ignore_ssl_certificates`
- `network_not_available`
- `no_connection_will_reconnect`
- `oh_secret`
- `oh_uuid`
- `oh_version`
- `openhab_connection`
- `real_time_sliders`
- `remote_url_not_configured`
- `running_demo_mode`
- `select_sitemap`
- `show_search_field`
- `ssl_certificate_error`
- `sync_prefs`
- `unknownState`

## Format/template strings with no code reference

- `%@ Settings`
- `%@ value`
- `%@: %@ %@`
- `%lld`
- `%lldK`
- `Added: %@`
- `Brightness: %.2f`
- `Cannot connect — retrying in %llds`
- `Clock Size: %@`
- `Clock Size: %lld %%`
- `Command Item %@`
- `Command failed: %@`
- `Command failures: %lld`
- `Decrease %@`
- `Delete '%@'?`
- `Delete home '%@'?`
- `Dim Level: %@`
- `Dim Level: %lld %%`
- `Enter a new name for the home '%@'`
- `Fade Duration: %@ s`
- `Hue: %.2f`
- `Idle Interval: %lld s`
- `Increase %@`
- `Invalid value %lld for %@ (0-100)`
- `Invalid value: %@ for %@ must be HSB (0-360,0-100,0-100)`
- `Item '%@' is not in home '%@'`
- `Item '%@' not found`
- `Lowers by %@`
- `Movement Interval: %lld s`
- `Pick a Color`
- `Queued commands: %lld`
- `Raises by %@`
- `Relative Date: %@`
- `Relative Date: %lld %%`
- `Rename '%@'`
- `Restore Brightness: %@`
- `Restore Brightness: %lld %%`
- `Saturation: %.2f`
- `Select a home for '%@'`
- `Sending commands: %lld`
- `Sent %@ to %@`
- `Sent location %lf, %lf to %@`
- `Sent the color value of %@ to %@`
- `Sent the date %@ to %@`
- `Sent the number %lf to %@`
- `Sent the string %@ to %@`
- `Sent the value of %lld to %@`
- `Sitemap: %@`
- `Size: %llu MB`
- `The URL is invalid. Please check the format (e.g., http://192.168.2.1:8080 or http://[::1]:8080 for IPv6).`
- `The URL is invalid. Please check the format (e.g., http://192.168.2.1:8080).`
- `The state of %@ is %@`
- `The state of %@ was set to %@`
- `Unexpected error: %@`

## AppShortcut phrase templates (verify before deleting)

These use `${variable}` AppIntents interpolation syntax and may not appear as
literal strings in Swift source. Confirm in the Shortcuts app that they are
not surfaced before removing.

- `Get ${itemEntity} State`
- `Send ${action} to ${itemEntity}`
- `Set ${itemEntity} to ${latitude}, ${longitude}`
- `Set ${itemEntity} to ${value}`
- `Set ${itemEntity} to ${value} (HSB)`
- `Set active home to ${home}`
- `Set the state of ${itemEntity} to ${state}`
