# Clinical Workstation Provisioner

A one-click `.bat` installer that provisioned ambulatory-site workstations for Epic EHR access over Citrix:

1. Confirms administrator rights
2. Downloads the Citrix client
3. Silent-installs it with the StoreFront account preconfigured (clinicians never type a server address)
4. Applies Windows network tuning for clinical Epic use (tweaks borrowed from Chris Titus Tech's Windows Utility)
5. Strips Windows telemetry (also borrowed from Chris Titus Tech's Windows Utility)
6. Tests connectivity to the Epic host and the StoreFront endpoint
7. Cleans up and logs everything

## The story

Written ~2016–2018 at MemorialCare, where I was a clinical training specialist. Ambulatory sites needed Citrix stood up by hand, machine by machine. This script turned it into one double-click: install, configure, tune, test. No other clinical training specialist had automated it.

## The reconstruction

The original file is lost — it never made it off a work machine into a personal backup. This repo is a faithful reconstruction built from the author's memory in 2026.

- Blocks tagged **[ORIGINAL]** are as remembered: the one-click flow, the Citrix download, the silent install with store preconfiguration, the automatic network tuning, the telemetry stripping, the configure-and-test loop.
- Blocks tagged **[RECONSTRUCTED]** fill gaps with standard Citrix/Epic deployment practice of the era: the exact installer flags, the verification method, the specific `netsh` tweaks, the telemetry-removal commands, the HTTPS reachability check.
- The network-improvement and telemetry-removal sections were borrowed from **Chris Titus Tech's Ultimate Windows Utility** ([winutil](https://github.com/ChrisTitusTech/winutil), MIT licensed) — per the author's recollection; the exact borrowed lines are reconstructed as standard equivalents.

## Usage

1. Edit the `CONFIG` block at the top of `setup-clinical-workstation.bat` — installer URL, store name/URL, Epic host.
2. Right-click → **Run as administrator**.
3. Read the log at `%TEMP%\clinical-workstation-setup.log`.

## Disclaimer

This is a historical reconstruction, not a drop-in deployment tool. Validate every default — installer sources, store URLs, and especially the network tweaks — against current Epic and Citrix guidance before real use.
