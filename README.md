# lidawake

![Three colorful agents working around a closed laptop. Close the lid. Keep the work going.](assets/hero.png)

Keep a MacBook running with its lid closed while turning off the display.
`lidawake` is a small zsh script that uses tools included with macOS. Run it
in Terminal or start an optional background service managed by `launchd`.

| 🌙 Closed lid | 🔋 Battery limit | ⚙️ Background service |
| --- | --- | --- |
| Keep the system awake and turn off the display. | Restore normal sleep at your chosen battery level. | Start, check, and stop a session without keeping Terminal open. |

The script restores normal sleep when you stop it or the configured limit is
reached. Screen locking is controlled by macOS Lock Screen settings.

> **Hardware safety:** The Mac remains active and can generate heat with its
> lid closed. Use it where air can circulate; avoid an enclosed bag while a
> session is running. See [Apple's temperature guidance](https://support.apple.com/en-ie/102336).

## Quick start

1. Download or clone this repository and open Terminal in its directory.
2. In **System Settings → Lock Screen**, set **Require password after screen
   saver begins or display is turned off** to **Immediately**. Verify that
   turning the display off asks for your password when you wake it.
3. Check that system sleep is enabled before starting. If it is disabled,
   restore the existing power setting first.
4. Check the current state and start a session:

   ```sh
   ./lidawake status
   sudo ./lidawake
   ```

Keep this Terminal command running. Press **Control-C** to stop the session.
`sudo` is required because the script changes system power settings; read
[`lidawake`](lidawake) before running it with administrator privileges.

By default, a session has no time limit and ends when battery charge reaches
10%. Edit [`lidawake.conf`](lidawake.conf) to change either setting:

```text
DURATION_MINUTES=infinite
BATTERY_FLOOR_PERCENT=10
```

| Setting | Values | Effect |
| --- | --- | --- |
| `DURATION_MINUTES` | `infinite` or `1`–`1440` | Maximum session length; `infinite` has no timer. |
| `BATTERY_FLOOR_PERCENT` | `1`–`99` | At or below this charge, restore normal sleep and exit, including on external power. |

Use plain `KEY=VALUE` lines. Blank lines and lines starting with `#` are
allowed. The script rejects missing, duplicate, unknown, and invalid settings;
it reads the file as data and does not execute it as shell code.

For a one-time override, run `sudo ./lidawake run 30 20` or
`sudo ./lidawake run infinite 20`. `./lidawake status` shows the values from
the config file, the current battery charge, lid state, and system sleep state.

## Background service

Start a managed session when you want to close Terminal after setup:

```sh
sudo ./lidawake service start
./lidawake service status
sudo ./lidawake service stop
```

`start` installs root-owned copies of the script and current config under
`/Library/Application Support/lidawake`, loads a `launchd` job, and starts it.
The service log is `/var/log/lidawake.log`. `stop` unloads the job, restores
normal sleep, and removes the installed copies. Stop and start again after
editing `lidawake.conf`; a running service uses the copy made at startup.

The service **does not start automatically after reboot** and is not restarted
after a crash or battery cutoff. If `service status` reports recovery needed,
run `sudo ./lidawake service stop`. This also handles a service that exited
without restoring sleep. A forced kill, crash, or power loss can still leave
sleep disabled until recovery runs. The service mode needs administrator
privileges to install and control its system job.

## Stop and recover

- Press **Control-C** in the Terminal running `lidawake` to restore normal
  sleep. A finite timer or the battery threshold will also stop the session.
- If the process was forcibly killed or the Mac crashed, normal sleep might
  remain disabled. After reopening the Mac, check `./lidawake status`. If the
  `lidawake` session has stopped but sleep is still disabled, run
  `sudo ./lidawake restore`. This changes the system-wide sleep setting.
- `restore` changes the system sleep setting; it does not stop a running
  `lidawake` process. Stop that process first, or it can disable sleep again.

The password prompt depends on the [macOS Lock Screen setting](https://support.apple.com/en-gb/guide/mac-help/-mh11784/mac).

## How it works and limitations

The script uses `pmset -a disablesleep 1` to keep the system awake, reads the
lid state with `ioreg`, and calls `pmset displaysleepnow` after the lid closes.
It polls battery charge and restores `disablesleep 0` when the session exits
normally. It refuses to start when system sleep is already disabled. Turning
off the display can also turn off a connected external monitor.

The `disablesleep` setting and the `ioreg` lid property are not documented in
the macOS `pmset` manual and could change with macOS updates. The behavior was
physically checked on an Apple Silicon Mac running macOS 26.6.1; other Macs
and macOS versions need their own closed-lid test. A process killed with
`SIGKILL`, a crash, or power loss cannot run the cleanup code.

## Development

Run the config and command-line checks without `sudo`:

```sh
sh tests/config.sh
sh tests/service.sh
/bin/zsh tests/service_cleanup.zsh
/bin/zsh -n lidawake
/bin/zsh -n service-control
```

These checks do not change system power settings. A physical closed-lid test
is still needed to verify power behavior on a particular Mac.

Licensed under [MIT](LICENSE).
