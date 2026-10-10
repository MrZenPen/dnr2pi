# Duke Nukem 1+2 Remastered on Raspberry Pi 5

This is the initial controller-only release. It patches a legally obtained original Evercade ARM executable to run natively on a Raspberry Pi 5. It does not include the Evercade executable or game archives. Only the scripts are provided for patching.

This was done as a proof of concept to show it's possible to patch out the hardware checks for the Evercade console and determine the libraries needed to run the game on other ARM devices, such as the Raspberry Pi 5.

This may work on other Raspberry Pi devices, like the 4th gen and 3rd gen, but this is untested. If you want to test this on your own Pi devices and you run into issues, use ChatGPT Codex to attach the project files and game files for context and assist with further troubleshooting. 

This script also patches the executable to use the ingame assets in 1080p mode. (HUD and main menu elements have assets in various resolutions, so this script makes sure to use the highest resolution assets.)

The tested platform is Raspberry Pi OS Desktop 32-bit on a Raspberry Pi 5 with 8 GB RAM. `uname -m` may report `aarch64`, but `getconf LONG_BIT` must report `32`.

## Important limitations

- Keyboard controls are not available in this initial release.
- An external controller is required. Testing used an Xbox One controller over USB.
- Connect the display to HDMI port 1—the micro-HDMI connector nearest the USB-C power connector.
- Start the game from a text console because it uses SDL's direct KMS/DRM backend.

## 1. Prepare Raspberry Pi OS

Use Raspberry Pi Imager to write **Raspberry Pi OS (32-bit) with desktop** to the SD card. In Imager customization, use `dnr2pi` as the username example, choose your own password, configure Wi-Fi and locale settings, and enable SSH.

Boot the Pi with the display connected to HDMI port 1, then run:

```bash
sudo apt update
sudo apt full-upgrade -y
sudo reboot
```

Verify the system:

```bash
uname -m
getconf LONG_BIT
cat /etc/os-release
```

## 2. Install runtime packages

```bash
sudo apt update
sudo apt install -y \
  alsa-utils coreutils openssh-server pipewire pipewire-alsa wireplumber \
  libasound2t64 libdbus-1-3 libdrm2 libegl1 libfreetype6 libgbm1 \
  libgl1 libgles1 libgles2 libogg0 libopengl0 libpng16-16t64 \
  libtheora0 libudev1 zlib1g
sudo systemctl enable --now ssh
sudo usermod -aG audio,video,render,input dnr2pi
sudo reboot
```

On older Raspberry Pi OS releases, use `libasound2` instead of `libasound2t64` and `libpng16-16` instead of `libpng16-16t64` if required.

## 3. Transfer the files

```bash
mkdir -p /home/dnr2pi/duke-remastered/uranium
mkdir -p /home/dnr2pi/duke-remastered/logs
```

Copy these files from the legally obtained Evercade image into `/home/dnr2pi/duke-remastered/uranium/`:

```text
RigelEngine_StaticSDL2
data.duke
music.duke
misc.duke
```

These files can be found in `/<Duke Nukem Remastered rom path>/uranium`

Copy these release files into `/home/dnr2pi/duke-remastered/`:

```text
patch-evercade-for-pi.sh
start-duke-remastered.sh
```

Optionally copy `gamecontrollerdb.txt` from the cartridge to that same directory.

For FileZilla, WinSCP or your preferred FTP utility, use SFTP, port 22, host `dnr2pi.local`, and username `dnr2pi`. Do not use FTP or port 21. Use the Pi's address from `hostname -I` if the `.local` name does not resolve.

## 4. Patch the executable

```bash
cd /home/dnr2pi/duke-remastered
sed -i 's/\r$//' patch-evercade-for-pi.sh start-duke-remastered.sh
chmod +x patch-evercade-for-pi.sh start-duke-remastered.sh
./patch-evercade-for-pi.sh
```

The original remains untouched. The verified output is `uranium/RigelEngine_StaticSDL2.pi`. The patch bypasses the Evercade hardware gate and selects the correct HDMI/UI tier for Pi HDMI port 1.

## 5. Test audio

```bash
speaker-test -D pipewire -c 2 -t wav
```

Press `Ctrl+C` to stop. To remove a stale manually selected PipeWire sink:

```bash
wpctl clear-default
systemctl --user restart wireplumber pipewire pipewire-pulse
```

## 6. Start the game

Connect the controller, press `Ctrl+Alt+F3`, log in as `dnr2pi`, and run:

```bash
cd /home/dnr2pi/duke-remastered
./start-duke-remastered.sh
```

Exit the game before returning to the desktop with `Ctrl+Alt+F2` or, on some installations, `Ctrl+Alt+F1`.

## Troubleshooting

### HDMI port 1 is disconnected

```bash
for f in /sys/class/drm/card*-HDMI-A-*/status; do
  printf '%s: ' "$f"
  cat "$f"
done
```

Power down and move the cable to HDMI port 1 if `card1-HDMI-A-1` is disconnected.

### No audio

```bash
systemctl --user status pipewire wireplumber --no-pager
aplay -L | grep -A2 pipewire
speaker-test -D pipewire -c 2 -t wav
```

### `/dev/uinput` troubleshooting

The initial release does not require uinput, but these complete steps are included for users preparing or diagnosing the controls update. The game binary patcher is unrelated to uinput.

```bash
sudo modprobe uinput
echo uinput | sudo tee /etc/modules-load.d/dnr2pi-uinput.conf
echo 'KERNEL=="uinput", SUBSYSTEM=="misc", GROUP="input", MODE="0660", OPTIONS+="static_node=uinput"' | \
  sudo tee /etc/udev/rules.d/70-dnr2pi-uinput.rules
sudo usermod -aG input "$USER"
sudo udevadm control --reload-rules
sudo udevadm trigger --subsystem-match=misc
sudo reboot
```

After reboot:

```bash
id -nG
lsmod | grep uinput
ls -l /dev/uinput
test -r /dev/uinput && test -w /dev/uinput && \
  echo "uinput access: OK" || echo "uinput access: FAILED"
```

Expected ownership is `root input` with group read/write permission. If necessary, apply the immediate correction:

```bash
sudo chgrp input /dev/uinput
sudo chmod 660 /dev/uinput
```

### Logs

```bash
cat /home/dnr2pi/duke-remastered/logs/duke-remastered.log
ldd /home/dnr2pi/duke-remastered/uranium/RigelEngine_StaticSDL2.pi
```
