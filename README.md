# omarchy-lark-battery

Battery level of the **Hollyland Lark M2** wireless microphones in the
[Omarchy](https://omarchy.org/) bar.

A microphone icon sits in the bar. Click it and a panel opens with the battery
of each transmitter, read live from the USB receiver.

- **Mic 1 / Mic 2:** percentage and a bar each. Transmitters that are off (in
  the charging case) show as "Off".
- **Low battery:** the icon and the bar turn red and you get a notification.
- **Icon states:** normal when a mic is on, dimmed when both are off, hidden
  when the receiver is unplugged.

## Install

1. Install the plugin:

   ```bash
   omarchy plugin add https://github.com/rinku64/omarchy-lark-battery.git --enable --yes
   ```

2. Allow your user to read the receiver. This needs root, so a plugin can't
   do it for you. Read the rule first, it's three lines:

   ```bash
   cat ~/.config/omarchy/plugins/rinku.lark-battery/70-hollyland-lark.rules
   ```

   Then install it:

   ```bash
   sudo install -m644 -o root -g root ~/.config/omarchy/plugins/rinku.lark-battery/70-hollyland-lark.rules /etc/udev/rules.d/
   sudo udevadm control --reload && sudo udevadm trigger --subsystem-match=hidraw
   ```

   Unplug and plug the receiver again if the panel shows a permission error.

3. Move the icon wherever you like:

   ```bash
   omarchy bar move rinku.lark-battery --section right
   ```

Remove it with `omarchy plugin remove rinku.lark-battery` and, if you want,
`sudo rm /etc/udev/rules.d/70-hollyland-lark.rules`.

### Upgrading from 1.x

Version 2.0.0 only changes the plugin's name: its id went from
`soradev.lark-battery` to `rinku.lark-battery`, because the author renamed
their GitHub account. Nothing else changed, and the udev rule is the same, so
you do not need to install it again. Because the id is different, Omarchy sees
a new plugin, so:

```bash
omarchy plugin remove soradev.lark-battery
omarchy plugin add https://github.com/rinku64/omarchy-lark-battery.git --enable --yes
omarchy bar move rinku.lark-battery --section right
```

## Settings

Edit the widget's entry in `~/.config/omarchy/shell.json`:

| Key | Default | Meaning |
|---|---|---|
| `interval` | `600` | Seconds between background reads (60–3600). Only runs while the receiver is plugged in and drives the low-battery alert. Opening the panel always reads live. |
| `lowThreshold` | `15` | Battery percentage at or below which it turns red and notifies. |

## How it works

`lark-battery` (Python, no dependencies) finds the receiver's `hidraw` node by
vendor ID `3547`, sends the heartbeat command and prints JSON. The widget runs
it when the panel opens, on a slow timer, and when `udevadm monitor` reports a
hidraw device coming or going.

You can run it by hand:

```bash
./lark-battery
# {"present": true, "tx": [{"connected": false, "battery": 0}, {"connected": true, "battery": 89}]}
```

## Security

- **Read-only.** The only thing ever sent to the receiver is one fixed
  heartbeat query. No firmware, pairing or settings commands exist in the code.
- **No root at runtime.** Everything runs as your user. Root is only used once,
  by you, to copy the udev rule.
- **Narrow permission.** The udev rule matches only Lark M2 receivers
  (`3547:0007`, `3547:0008`) and only their HID node, and grants access to the
  user logged in at the seat (`uaccess`). Any program running as that user can
  talk to the receiver, which is what reading it without root requires.
- **No network, no shell.** Nothing is downloaded or sent anywhere. Commands are
  started with fixed argument lists, never through a shell, and the helper runs
  Python in isolated mode (`-I`), ignoring `PYTHONPATH` and user site packages.
- **Untrusted input is checked.** Replies from the receiver are validated
  (sync bytes, source, command, length) and the widget re-checks the helper's
  output (types, 0–100 range, at most two transmitters, plain-text only).
- **You run my code.** Like any Omarchy plugin, it runs inside your shell
  session with your user's permissions. Read the three files before installing,
  and `omarchy plugin update` pulls whatever is on `main`. Tagged releases are
  the reviewed versions.

To report a vulnerability, see [SECURITY.md](SECURITY.md).

## Compatibility

Tested with a Lark M2 receiver (`3547:0008`) on Omarchy. `3547:0007` is a Lark
M2 variant documented with the same protocol. The code assumes two
transmitters. Other Hollyland receivers aren't supported.

## Credits

The USB protocol comes from other people's reverse engineering:

- [larkctl](https://github.com/blchinezu/larkctl)
- [lark-m2-macos](https://github.com/bluecoconut/lark-m2-macos)

Not affiliated with Hollyland.

## License

[MIT](LICENSE)
