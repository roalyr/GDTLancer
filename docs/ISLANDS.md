# Evolution islands: more cores, more laptops

One Godot process runs the whole simulation on one CPU core. Islands are several evolution runs side
by side, on this laptop and on others in the local network. Each segment works like this:
1. Every island flies the same save for the same simulated hours, each with its own random seed.
2. This laptop (the **master**) collects their saves.
3. It merges them: genome records add up, and each niche keeps the fittest genome.
4. It appends their life logs to the era's log and backs up.
5. The next segment starts from the merged save.

The other laptops (the **workers**) need only an SSH server and the master's key. The master
sends them everything else: Godot (the master's own 3.6.2 x11 binary), the project files including
the `.import` cache, and the save. No editor, no git and no install of Godot on the workers.

Godot runs with `--no-window` but still needs an X display. On a worker it borrows the desktop of
the user the master logs in as (`DISPLAY=:0`). So a worker must stay **logged in to its desktop**,
which a live session does by itself (user `demo`). The headless server build would need no display,
but its dummy renderer crashes: a segfault about 100 simulated seconds into a run.

Commands, from the project root on the master:

| Command | What it does |
|---|---|
| `python3 tools/devtool/islands.py check` | Is every worker reachable? How many cores? |
| `python3 tools/devtool/islands.py push` | Send Godot and the project to every worker (only what changed) |
| `python3 tools/devtool/islands.py segment` | One segment on every island, then merge |
| `python3 tools/devtool/islands.py run 6` | Six segments, one after another |
| `python3 tools/devtool/islands.py stop` | Every island saves and ends; the run stops after the merge |

The settings live in `.dev/islands.json` on the master (see step 4).

---

## 1. On the master (this laptop)

These steps were checked on `mx-x230-1` on 2026-11-08: it already has a key
(`~/.ssh/id_ed25519`), and `rsync` and Avahi (`.local` names) are running. On a fresh master:

1. Open a terminal.
2. Make a key, if `ls ~/.ssh/id_ed25519.pub` says there is none:
   ```
   ssh-keygen -t ed25519
   ```
   Press Enter at every question. A passphrase is optional; with one, run `ssh-add` once per login
   so the islands can log in without asking.
3. Check that rsync is there: `rsync --version`. If it is not: `sudo apt install rsync`.
4. Find the master's own address, to recognise the network: `ip -4 addr`. This laptop is
   `192.168.31.101`, so the workers will be `192.168.31.x`.

## 2a. Quick way: MX Linux live USB sessions

For laptops booted from an MX Linux 23 live USB, one script does all of step 2 and 3.
1. On the master, build the kit:
   ```
   python3 tools/devtool/islands.py usb-kit .dev/islands_usb
   ```
   This writes `.dev/islands_usb/` with four things:
   - `islands_worker_setup.sh`;
   - `master_key.pub`, this laptop's public key;
   - `debs/`, the SSH server packages, so no internet is needed;
   - an empty `workers/`.
2. Copy that folder onto a **writable** part of the stick: a Ventoy stick (the ISO is a file there), or
   a second partition. A stick made by writing the ISO straight onto it is read-only. The script
   still works from it, but each worker's report goes to `/tmp`, and its SSH identity changes every
   boot: then mark that host `"live": true` on the master (step 4).
3. Boot each worker from the stick (user `demo`, password `demo`) and connect it to the network.
4. Open a terminal in the kit folder (e.g. `cd /media/demo/<stick>/islands_usb`) and run:
   ```
   sudo bash islands_worker_setup.sh
   ```
   It does six things:
   - names the laptop `mx-worker-<id>`, after its network card, since every live session is called
     the same;
   - installs and starts the SSH server;
   - keeps the laptop's SSH host keys on the stick, so it has the same identity every boot;
   - lets the master's key in;
   - turns off sleep and lid suspend;
   - prints a report, saved as `workers/<name>.txt` on the stick, ending with the line to paste into
     the master's `.dev/islands.json`.
5. A live session forgets everything at shutdown: run the script again after every boot. It takes
   a few seconds, and every step checks before it acts.

Then go to step 4 below. For an installed system, follow step 2 instead.

## 2. On each worker laptop (once, at the laptop)

1. Log in as the user who will run the islands. Any user will do; the islands live in its home
   folder, under `~/gdtl-island/`.
2. Install the SSH server and rsync:
   ```
   sudo apt update
   sudo apt install openssh-server rsync
   ```
3. Start the SSH server now and at every boot. MX Linux boots with sysvinit by default:
   ```
   sudo service ssh start
   sudo update-rc.d ssh enable
   ```
   (With systemd instead: `sudo systemctl enable --now ssh`.) Check it with
   `sudo service ssh status`, which should say "sshd is running".
4. Find the laptop's name and address:
   ```
   hostname
   ip -4 addr
   ```
   Write both down, e.g. `mx-t440` and `192.168.31.105`. On MX, Avahi usually answers the name
   with `.local` added (`mx-t440.local`), so the address may change without breaking anything. If
   `ping mx-t440.local` from the master does not answer, use the address instead, and give the
   laptop a fixed address in the router (a DHCP reservation) so it keeps it.
5. Count its cores: `nproc`. Plan one island per two of these (two on a 4-thread laptop).
6. Stop it sleeping. In MX Tweak or Xfce's **Power Manager**, while plugged in:
   - System sleep: **Never**;
   - Lid closed: **Switch off display**, not Suspend;
   - set Display to blank if you like, which does no harm.
7. If the firewall is on (`sudo ufw status` says "active"), let SSH in:
   ```
   sudo ufw allow ssh
   ```
8. Keep it on mains power while it works.

## 3. Give the master the key to each worker (at the master)

For each worker (with the user and name from step 2):

1. Copy the key over. It asks the worker user's password once:
   ```
   ssh-copy-id me@mx-t440.local
   ```
   The first time, it asks whether to trust the host key: type `yes`.
2. Check that the login needs no password now:
   ```
   ssh -o BatchMode=yes me@mx-t440.local 'echo ok; nproc'
   ```
   It should print `ok` and the core count, without asking anything. If it asks for a password,
   the key did not take: run step 1 again and look for errors.
3. Optional hardening, once the key works: on the worker, set `PasswordAuthentication no` in
   `/etc/ssh/sshd_config` and run `sudo service ssh restart`. Only keys can log in after that.

## 4. Tell the master about the workers

Write `.dev/islands.json` in the project. It is this machine's own and is not committed:
```json
{
  "local": 2,
  "hosts": [
    {"host": "mx-t440.local", "user": "me", "islands": 2},
    {"host": "192.168.31.107", "user": "me", "islands": 1}
  ],
  "hours": 1.2,
  "speed": 8
}
```
- `local`: islands on the master. Two suit this i5-3210M (2 cores, 4 threads).
- `islands` per host: about `nproc / 2`.
- `live` per host (optional): `true` for a live session whose SSH host keys change every boot. The
  master then does not check them, which is fine on a home network.
- `hours`: simulated hours per segment. With two islands per laptop, 1.2 h takes about 45 minutes.
  The file is reread before every segment, so it can be changed while a run goes on.
- `battery_hours` (optional): simulated hours per segment while the master's charger is off, so a
  blackout loses less.
- `godot` (optional): the Godot binary sent to the workers. The default is the master's `godot`
  on the PATH (the 3.6.2 x11 build), with links followed.

## 5. First run

```
python3 tools/devtool/islands.py check   # every worker reachable, its cores, "no-godot-yet", "display-ok"
python3 tools/devtool/islands.py push    # about 230 MB the first time, seconds after that
python3 tools/devtool/islands.py segment
```
Every segment pushes again first, so the workers always run exactly the master's files, edits
included. Watch the master's terminal. It reports each island when it is done, then the merge
("MERGE ok ...: N lives ended"), the lives appended to the era's log, and the backup
(`evolution/backups/islands_t<hours>h.sav`, the newest three kept).

## What happens when something goes wrong

- **A worker is off, asleep or out of Wi-Fi when a segment starts.** It is left out; the others run.
- **A worker drops mid-segment.** After 10 minutes without word, its island is left out of that
  merge. It loses that one segment, nothing else.
- **The master loses power.** The workers finish their segment and stop. The master's save is the
  last merged one (written whole, then swapped in, the old one kept as `.bak`). Run the segment
  again: the islands start over from that save.
- **You want to stop.** Run `islands.py stop`, or press STOP on the debug overlay. Every island saves
  and ends, the merge still runs, then the run stops.
- **The new-era flow** waits while islands run: evolution's `status.json` says "running".

## What the workers keep

Under `~/gdtl-island/`:
- `godot`: the master's Godot binary;
- `project/`: the files;
- `islands/island<K>/`: each island's save, console log and life log, replaced every segment.

Godot also makes an empty `~/.local/share/godot/app_userdata/GDTLancer-rev/` there. To remove it
all: `rm -rf ~/gdtl-island ~/.local/share/godot/app_userdata/GDTLancer-rev`.
