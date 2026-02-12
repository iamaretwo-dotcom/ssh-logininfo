# ssh-logininfo

System overview banner displayed on SSH login. Pure bash, no dependencies.

![screenshot](https://github.com/iamaretwo-dotcom/ssh-logininfo/raw/master/screenshot.png)

## What it shows

- System stats (OS, uptime, CPU, memory, disk, IP)
- Listening web services (port, process, pid)
- Last 5 logins
- Failed SSH attempts (24h) with commands to view details
- Pending package updates
- Docker container count (if available)

## Install

```bash
git clone https://github.com/iamaretwo-dotcom/ssh-logininfo.git ~/ssh-logininfo
~/ssh-logininfo/install.sh
```

## Uninstall

```bash
~/ssh-logininfo/install.sh --uninstall
```

## Manual run

```bash
~/ssh-logininfo/sysinfo.sh
~/ssh-logininfo/sysinfo.sh --no-color   # plain text, good for piping
```

## How it works

The install script adds one line to `~/.profile`:

```bash
[[ -n "${SSH_CONNECTION:-}" && -t 0 ]] && ~/ssh-logininfo/sysinfo.sh
```

This only triggers on interactive SSH sessions — local terminals and scripts are unaffected. No root required.
