#!/bin/bash
# Makes this laptop an evolution island worker (docs/ISLANDS.md), for an MX Linux 23 live session
# (or an installed MX / Debian 12): SSH server, the master's key, no sleep, a name of its own, and a
# report of what the master needs to know. Run it from the USB kit folder that
# `python3 tools/devtool/islands.py usb-kit <folder>` made on the master:
#     sudo bash islands_worker_setup.sh
# (MX live: user demo, password demo.) Safe to run again: each step checks before it acts.
#
# The kit folder holds:
#   islands_worker_setup.sh   this script
#   master_key.pub            the master's public SSH key, let in for the worker's user
#   debs/                     openssh-server and the packages it needs, for a session without internet
#   workers/                  where this script writes each worker's report and keeps its SSH host
#                             keys (so a live session keeps the same identity every boot), if the
#                             USB is writable
set -u

KIT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
say() { printf '\n== %s\n' "$*"; }
note() { printf '   %s\n' "$*"; }
warn() { printf '   !! %s\n' "$*"; }

if [ "$(id -u)" -ne 0 ]; then
	echo "Run it as root: sudo bash $0"
	exit 1
fi
WORKER_USER="${SUDO_USER:-demo}"
if [ "$WORKER_USER" = "root" ]; then
	WORKER_USER="demo"
fi
HOME_DIR="$(getent passwd "$WORKER_USER" | cut -d: -f6)"
if [ -z "$HOME_DIR" ]; then
	echo "No user '$WORKER_USER' here: run it with sudo from the user who will run the islands."
	exit 1
fi

say "0. This machine"
ARCH="$(uname -m)"
note "user $WORKER_USER ($HOME_DIR), $ARCH, $(nproc) threads"
if [ "$ARCH" != "x86_64" ]; then
	warn "the island Godot is 64-bit x86: this machine cannot run it"
	exit 1
fi
MAC="$(cat /sys/class/net/*/address 2>/dev/null | grep -v '^00:00:00:00:00:00$' | sort | head -1)"
ID="$(echo "$MAC" | tr -d ':' | tail -c 7)"  # Last 6 hex digits of the first network card
[ -n "$ID" ] || ID="$(head -c 3 /dev/urandom | od -An -tx1 | tr -d ' \n')"
WRITABLE=0
if mkdir -p "$KIT/workers" 2>/dev/null && touch "$KIT/workers/.probe" 2>/dev/null; then
	rm -f "$KIT/workers/.probe"
	WRITABLE=1
	note "kit folder writable: the report and host keys go to $KIT/workers/"
else
	warn "the kit folder is read-only (an ISO written straight to the stick): the report goes to /tmp,"
	warn "and the host keys change every boot (set \"live\": true for this host on the master)"
fi

say "1. A name of its own"
# Every MX live session is called the same (mx1); the islands need each laptop apart on the network.
NAME="mx-worker-$ID"
if [ "$(hostname)" != "$NAME" ]; then
	OLD="$(hostname)"
	echo "$NAME" > /etc/hostname
	hostname "$NAME"
	if grep -q "127.0.1.1" /etc/hosts; then
		sed -i "s/^127\.0\.1\.1.*/127.0.1.1\t$NAME/" /etc/hosts
	else
		printf '127.0.1.1\t%s\n' "$NAME" >> /etc/hosts
	fi
	note "renamed $OLD -> $NAME"
	if pgrep -x avahi-daemon >/dev/null; then  # It announced the old name: tell it the new one
		avahi-set-host-name "$NAME" 2>/dev/null || service avahi-daemon restart >/dev/null 2>&1
	fi
else
	note "already $NAME"
	if pgrep -x avahi-daemon >/dev/null && ! avahi-resolve -n "$NAME.local" >/dev/null 2>&1; then
		avahi-set-host-name "$NAME" 2>/dev/null || service avahi-daemon restart >/dev/null 2>&1
	fi
fi

say "2. SSH server"
# Installed means the files are there, not what dpkg says: an MX live system can list openssh-server as
# installed with its /etc files gone (no sshd_config, no init script), and dpkg never puts back a config
# file that was deleted unless told to (--force-confmiss).
ssh_whole() { [ -x /usr/sbin/sshd ] && [ -f /etc/ssh/sshd_config ] && [ -f /usr/share/openssh/sshd_config ]; }
if ssh_whole && dpkg-query -W -f='${Status}' openssh-server 2>/dev/null | grep -q "install ok installed"; then
	note "openssh-server installed"
else
	note "openssh-server missing or incomplete ($(dpkg-query -W -f='${Status}' openssh-server 2>/dev/null || echo 'not known')): installing"
	if ls "$KIT"/debs/*.deb >/dev/null 2>&1; then
		note "from the kit (no internet needed)"
		dpkg -i --force-confmiss --force-confnew "$KIT"/debs/*.deb 2>&1 | grep -iE "error|warn" | sed 's/^/      /'
		dpkg --configure -a --force-confmiss >/dev/null 2>&1 || true
	fi
	if ! ssh_whole; then
		note "from the internet (apt)"
		apt-get update -qq && DEBIAN_FRONTEND=noninteractive apt-get install -y -qq --reinstall \
			-o Dpkg::Options::=--force-confmiss -o Dpkg::Options::=--force-confnew openssh-server openssh-sftp-server
	fi
	if [ ! -f /etc/ssh/sshd_config ] && [ -f /usr/share/openssh/sshd_config ]; then
		cp /usr/share/openssh/sshd_config /etc/ssh/sshd_config  # The package's own default, as its install would write it
		note "sshd_config put back from the package's default"
	fi
	if [ -x /usr/sbin/sshd ] && [ -f /etc/ssh/sshd_config ]; then
		note "openssh-server installed"
	else
		warn "openssh-server is still incomplete (sshd: $([ -x /usr/sbin/sshd ] && echo there || echo missing), sshd_config: $([ -f /etc/ssh/sshd_config ] && echo there || echo missing))"
		warn "connect to the internet and run this again, or send this screen to the master's user"
		exit 1
	fi
fi
# Host keys: the kit's for this laptop if it has them (the same identity every boot), else new ones
# (kept in the kit for next time).
KEYS="$KIT/workers/hostkeys-$ID"
if [ "$WRITABLE" = 1 ] && ls "$KEYS"/ssh_host_*_key >/dev/null 2>&1; then
	cp "$KEYS"/ssh_host_* /etc/ssh/
	chmod 600 /etc/ssh/ssh_host_*_key
	chmod 644 /etc/ssh/ssh_host_*_key.pub
	note "host keys from the kit (this laptop's own)"
else
	ssh-keygen -A >/dev/null
	if [ "$WRITABLE" = 1 ]; then
		mkdir -p "$KEYS" && cp /etc/ssh/ssh_host_* "$KEYS"/ && note "host keys made and kept in the kit"
	fi
fi
mkdir -p /run/sshd && chmod 755 /run/sshd
rm -f /etc/ssh/sshd_not_to_be_run
if command -v systemctl >/dev/null 2>&1 && [ -d /run/systemd/system ]; then
	systemctl enable --now ssh >/dev/null 2>&1 || systemctl restart ssh >/dev/null 2>&1
elif [ -x /etc/init.d/ssh ]; then
	update-rc.d ssh enable >/dev/null 2>&1 || true
	/etc/init.d/ssh restart >/dev/null 2>&1 || /etc/init.d/ssh start >/dev/null 2>&1
fi
listening() { ss -ltn 2>/dev/null | grep -qE '[:.]22[[:space:]]'; }
if ! listening; then
	# The service did not bring it up (an MX live session can refuse: sshd_not_to_be_run, no /run/sshd): start it directly
	/usr/sbin/sshd 2>&1 | sed 's/^/   sshd: /'
	sleep 1
fi
if listening; then
	note "sshd is listening on port 22"
else
	warn "sshd is NOT listening on port 22. What it says:"
	/usr/sbin/sshd -t 2>&1 | sed 's/^/      /'
	warn "send this screen to the master's user"
	exit 1
fi
if command -v ufw >/dev/null 2>&1 && ufw status 2>/dev/null | grep -q "Status: active"; then
	ufw allow ssh >/dev/null && note "firewall: ssh let in"
fi

say "3. The master's key"
if [ -f "$KIT/master_key.pub" ]; then
	install -d -m 700 -o "$WORKER_USER" -g "$WORKER_USER" "$HOME_DIR/.ssh"
	touch "$HOME_DIR/.ssh/authorized_keys"
	if grep -qF "$(cat "$KIT/master_key.pub")" "$HOME_DIR/.ssh/authorized_keys"; then
		note "already let in"
	else
		cat "$KIT/master_key.pub" >> "$HOME_DIR/.ssh/authorized_keys"
		note "let in: $(cut -d' ' -f3 "$KIT/master_key.pub")"
	fi
	chown "$WORKER_USER:$WORKER_USER" "$HOME_DIR/.ssh/authorized_keys"
	chmod 600 "$HOME_DIR/.ssh/authorized_keys"
else
	warn "no master_key.pub in the kit: run 'ssh-copy-id $WORKER_USER@$NAME.local' on the master instead"
fi

say "4. No sleep, no lid suspend"
# elogind (MX's session manager) would suspend on the lid; the Xfce power manager on idle.
for CONF in /etc/elogind/logind.conf /etc/systemd/logind.conf; do
	[ -f "$CONF" ] || continue
	for KEY in HandleLidSwitch HandleLidSwitchExternalPower HandleLidSwitchDocked HandleSuspendKey IdleAction; do
		sed -i "/^#\?$KEY=/d" "$CONF"
		echo "$KEY=ignore" >> "$CONF"
	done
	note "$CONF: lid, suspend key and idle ignored"
done
pkill -HUP -x elogind-daemon 2>/dev/null || pkill -HUP -x elogind 2>/dev/null || true
USER_DISPLAY="$(ps -u "$WORKER_USER" -o pid= | while read -r PID; do tr '\0' '\n' < /proc/"$PID"/environ 2>/dev/null | grep '^DISPLAY='; done | head -1 | cut -d= -f2)"
if [ -n "$USER_DISPLAY" ] && command -v xfconf-query >/dev/null 2>&1; then
	as_user() { sudo -u "$WORKER_USER" env DISPLAY="$USER_DISPLAY" DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$(id -u "$WORKER_USER")/bus" "$@"; }
	for PROP in inactivity-on-ac inactivity-on-battery; do
		as_user xfconf-query -c xfce4-power-manager -p /xfce4-power-manager/$PROP -n -t int -s 0 2>/dev/null
	done
	for PROP in lid-action-on-ac lid-action-on-battery; do
		as_user xfconf-query -c xfce4-power-manager -p /xfce4-power-manager/$PROP -n -t uint -s 0 2>/dev/null  # 0: switch off the display
	done
	as_user xfconf-query -c xfce4-power-manager -p /xfce4-power-manager/presentation-mode -n -t bool -s true 2>/dev/null
	as_user xset s off -dpms 2>/dev/null
	note "Xfce power manager: never sleeps, the lid only switches the display off (presentation mode on)"
else
	warn "no desktop session found for $WORKER_USER: set Power Manager to never sleep by hand"
fi
if [ -d /sys/class/power_supply ] && grep -qs "^0$" /sys/class/power_supply/A*/online; then
	warn "running on battery: plug it in for long runs"
fi

say "5. Report"
IPS="$(ip -4 -o addr show scope global | awk '{print $4}' | cut -d/ -f1 | paste -sd' ')"
THREADS="$(nproc)"
ISLANDS=$(( THREADS / 2 ))
[ "$ISLANDS" -ge 1 ] || ISLANDS=1
MEM_MB="$(free -m | awk '/^Mem/{print $2}')"
CPU="$(grep -m1 'model name' /proc/cpuinfo | cut -d: -f2 | sed 's/^ *//')"
LIVE=false
{ [ -d /live/boot-dev ] || [ -d /live/aufs ] || grep -qs "boot=live\|bdir=\|from=" /proc/cmdline; } && LIVE=true  # MX (antiX) live system
[ "$WRITABLE" = 1 ] && [ "$LIVE" = true ] && LIVE_KEYS="kept in the kit" || LIVE_KEYS="as installed"
REPORT_DIR="$KIT/workers"
[ "$WRITABLE" = 1 ] || REPORT_DIR="/tmp"
REPORT="$REPORT_DIR/$NAME.txt"
LIVE_FLAG=false
[ "$LIVE" = true ] && [ "$WRITABLE" != 1 ] && LIVE_FLAG=true  # Host keys new every boot: the master must not pin them
cat > "$REPORT" <<EOF
name:      $NAME  (also $NAME.local)
address:   $IPS
user:      $WORKER_USER
cpu:       $CPU
threads:   $THREADS  -> $ISLANDS island(s)
memory:    $MEM_MB MB
live:      $LIVE  (host keys $LIVE_KEYS)
mac:       $MAC
when:      $(date '+%Y-%m-%d %H:%M')

For the master's .dev/islands.json "hosts":
    {"host": "$NAME.local", "user": "$WORKER_USER", "islands": $ISLANDS, "live": $LIVE_FLAG}
Check from the master:
    ssh -o BatchMode=yes $WORKER_USER@$NAME.local 'echo ok; nproc'
EOF
chmod 644 "$REPORT"
cat "$REPORT"
note "saved to $REPORT"
if [ "$LIVE" = true ]; then
	note "a live session forgets all this at shutdown: run this script again after every boot"
fi
