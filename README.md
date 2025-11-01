# DNS-VPN-Toggle Magisk Module

Automatically toggles Private DNS mode between "off" and your saved "provider hostname" when any VPN connects/disconnects—polls all common interface names (tunN, pppN, wgN, clat0, swlan0, vnicN, epN, etc). No UI/config required. Original code, MIT license.

## Features
- Maximal reliability: polls all common VPN interface names
- Android 9+ (Pie, API 28+) required
- Efficient, polling every 0.8s
- Full log at /data/adb/modules/dnsvpntoggle/service.log

## Installation
1. Flash ZIP in Magisk Manager and reboot
2. The module monitors VPN state and toggles Private DNS automatically
3. Your current provider hostname (set via Android settings at any time) will be restored after VPN disconnects

## License
MIT
Author: iddqd87
