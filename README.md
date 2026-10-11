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
   omarchy plugin add https://github.com/soradev64/omarchy-lark-battery.git --enable --yes
   ```

2. Allow your user to read the receiver (needs root, so a plugin can't do it
   for you):

   ```bash
   sudo install -m644 ~/.config/omarchy/plugins/*lark-battery/70-hollyland-lark.rules /etc/udev/rules.d/
   sudo udevadm control --reload && sudo udevadm trigger --subsystem-match=hidraw
   ```

   Unplug and plug the receiver again if the panel shows a permission error.

3. Move the icon wherever you like:

   ```bash
   omarchy bar move soradev.lark-battery --section right
   ```

Remove it with `omarchy plugin remove soradev.lark-battery` and, if you want,
`sudo rm /etc/udev/rules.d/70-hollyland-lark.rules`.

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

## Compatibility

Tested only with a Lark M2 receiver (`3547:0008`) on Omarchy. The code assumes
two transmitters. Other Hollyland receivers may use a different protocol.

## Credits

The USB protocol comes from other people's reverse engineering:

- [larkctl](https://github.com/blchinezu/larkctl)
- [lark-m2-macos](https://github.com/bluecoconut/lark-m2-macos)

Not affiliated with Hollyland.

## License

[MIT](LICENSE)
