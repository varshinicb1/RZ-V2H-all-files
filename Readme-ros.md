

---

# ROS 2 Humble on RZ/V2H via Docker — End‑to‑End Guide

This guide shows you how to set up **everything** required to:

1. Build two Docker images

   * a “host‑side” image for development and simulation
   * a “target‑side” ARM 64 image that runs on the **RZ/V2H EVK**
2. Copy the target image to a micro‑SD card
3. Launch ROS 2 nodes on both host and target
4. Recover cleanly from the common errors encountered during the process

> **Status** – verified July 2025 on Ubuntu 22.04.5 LTS.

---

## 1. Bill of materials

| Item                                | Notes                            |
| ----------------------------------- | -------------------------------- |
| **Ubuntu 22.04 LTS** host PC        | ≥ 100 GB free disk, ≥ 16 GB RAM  |
| **RZ/V2H EVK** + 32 GB micro‑SD     | AI SDK pre‑flashed image is fine |
| Stable Internet connection          | Docker layers ≈ 6 GB download    |
| USB‑UART cable and Ethernet cable   | For console and LAN              |
| **(Optional)** camera, HDMI monitor | For sample apps                  |

---

## 2. Host‑side prerequisites

### 2.1 System update and packages

```bash
sudo apt update && sudo apt upgrade -y
sudo apt install -y \
    git curl wget gpg lsb-release \
    build-essential ca-certificates \
    python3-pip tree tmux \
    qemu-user-static xz-utils
```

### 2.2 Install Docker Engine & CLI

```bash
# Add Docker’s official GPG key and repository
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
  sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
echo \
  "deb [arch=$(dpkg --print-architecture) \
  signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list >/dev/null

sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin
```

### 2.3 Add your user to the `docker` group

```bash
sudo usermod -aG docker $USER
# Important: re‑login (or `exec su - $USER`) before continuing
```

### 2.4 Enable BuildKit (faster, resumable)

```bash
echo 'export DOCKER_BUILDKIT=1' >> ~/.bashrc
source ~/.bashrc
```

---

## 3. Create workspace

```bash
mkdir -p ~/rzv2h_ros2_docker
cd ~/rzv2h_ros2_docker
git clone https://github.com/renesas-rz/rzv2h_ros2.git
cd rzv2h_ros2/rzv2-ros-docker
```

**Folder structure**

```
rzv2h_ros2_docker/
└── rzv2h_ros2/
    └── rzv2-ros-docker/
        ├── Dockerfile_for_pc
        └── Dockerfile_for_rzv2h
```

Verify with `tree -L 2`.

---

## 4. Quick system check script (optional but recommended)

Create `scripts/host_check.sh`:

```bash
#!/usr/bin/env bash
set -e
echo "=== Basic OS info ==="
lsb_release -a
uname -a
echo; echo "=== Disk ==="
df -h /
echo; echo "=== Memory ==="
free -h
echo; echo "=== Docker ==="
docker --version
echo; echo "=== Groups ==="
id
echo; echo "=== LD_LIBRARY_PATH ==="
[[ -z "$LD_LIBRARY_PATH" ]] && echo "<empty>" || echo "$LD_LIBRARY_PATH"
```

Run:

```bash
bash scripts/host_check.sh
```

If `LD_LIBRARY_PATH` is **not empty**, run:

```bash
unset LD_LIBRARY_PATH
```

(See troubleshooting #1 below.)

---

## 5. Build the development‑host image

```bash
cd ~/rzv2h_ros2_docker/rzv2h_ros2/rzv2-ros-docker

# download layers / build (≈ 10 min on fast network)
docker build -f Dockerfile_for_pc -t humble .
```

*The command is resumable.*
If the laptop sleeps or the network drops, just run the same `docker build` again.

---

## 6. Run the development container

```bash
# Allow X11 forwarding once per login
xhost +local:

docker run -it --rm \
       --net host \
       --ipc host \
       --privileged \
       -e DISPLAY=$DISPLAY \
       -v /tmp/.X11-unix:/tmp/.X11-unix \
       --name humble_dev \
       humble
```

Inside the container you get a ROS 2 Humble workspace ready for simulation.

---

## 7. Build the RZ/V2H ARM64 image

### 7.1 Install qemu (already done in §2.1)

### 7.2 Build

```bash
docker build --platform linux/arm64 \
       -f Dockerfile_for_rzv2h \
       -t rzv2h_humble .
```

### 7.3 Save to SD card

```bash
docker save rzv2h_humble | gzip > /media/$USER/root/rzv2h_humble_image.tar.gz
sync
```

*(The SD already holds the Yocto AI‑SDK image you flashed earlier.)*

---

## 8. Load and run on the EVK

On the EVK serial console:

```bash
systemctl restart docker     # start daemon if not active
docker load --input /root/rzv2h_humble_image.tar.gz
export WAYLAND_DISPLAY=wayland-0
docker run -itd \
       --net host --privileged \
       -e WAYLAND_DISPLAY=$WAYLAND_DISPLAY \
       -v $XDG_RUNTIME_DIR/$WAYLAND_DISPLAY:/tmp/runtime-root/$WAYLAND_DISPLAY \
       --name rzv2h_humble_container \
       rzv2h_humble
```

You can now enter the container and launch ROS 2 nodes:

```bash
docker exec -it rzv2h_humble_container bash
ros2 run demo_nodes_cpp talker
```

On the PC side, in `humble_dev`, run the listener:

```bash
ros2 run demo_nodes_cpp listener
```

---

## 9. Keeping long builds alive (laptop lid / power)

* Use **tmux** or **screen** on the host:

  ```bash
  sudo apt install -y tmux
  tmux new -s dockerbuild
  # run docker build inside
  ```
* Disable automatic suspend while on AC:
  `Settings ▶ Power ▶ Blank Screen = Never`
* Docker BuildKit will always resume already‑downloaded layers.

---

## 10. Troubleshooting

| Symptom                                                    | Fix                                                                                                                         |                                                                     |
| ---------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------- |
| `Your environment is misconfigured, unset LD_LIBRARY_PATH` | `unset LD_LIBRARY_PATH`; make sure **not** to source Poky or SDK scripts in your default shell when working on the host     |                                                                     |
| TLS handshake timeout while pulling `ubuntu:22.04`         | Retry `docker build`; or set a mirror: \`echo '{ "registry-mirrors": \["[https://mirror.gcr.io](https://mirror.gcr.io)"] }' | sudo tee /etc/docker/daemon.json && sudo systemctl restart docker\` |
| Disk full under `/var/lib/docker`                          | `docker system prune -af` or move Docker data root to a larger partition (`/etc/docker/daemon.json`)                        |                                                                     |
| `permission denied /var/run/docker.sock`                   | Re‑login after adding user to `docker` group                                                                                |                                                                     |
| Slow GUI over X11                                          | Use LAN, or switch to Wayland ↔ X11 as needed (`WAYLAND_DISPLAY`)                                                           |                                                                     |
| Laptop sleeps mid‑build                                    | Use `tmux`, disable suspend, or keep on AC                                                                                  |                                                                     |

---

## 11. Environment variables summary

| Variable                                | Purpose               | Where to set                 |
| --------------------------------------- | --------------------- | ---------------------------- |
| `DOCKER_BUILDKIT=1`                     | resumable builds      | `~/.bashrc`                  |
| `DISPLAY=:0`                            | X11 forwarding        | host shell                   |
| `WAYLAND_DISPLAY=wayland-0`             | Weston/Wayland on EVK | EVK shell                    |
| `RMW_IMPLEMENTATION=rmw_cyclonedds_cpp` | ROS 2 middleware      | inside containers (optional) |
| `ROS_DOMAIN_ID=<n>`                     | isolate ROS 2 network | same value on host and EVK   |

---

## 12. Cleaning up

```bash
# On host
docker container prune -f
docker image prune -af   # removes dangling and unused images

# Remove the workspace if you need space
rm -rf ~/rzv2h_ros2_docker
```

---

### Appendix A — Full host‑check script

```bash
#!/usr/bin/env bash
set -eu

echo "=== Host System ==="
lsb_release -a
uname -a

echo; echo "=== Memory ==="
free -h

echo; echo "=== Disk ==="
df -h /

echo; echo "=== Required commands ==="
for cmd in git curl docker tmux qemu-aarch64; do
  command -v $cmd >/dev/null && echo "✔ $cmd" || echo "✘ $cmd MISSING"
done

echo; echo "=== Docker info ==="
docker --version
docker info --format '{{.ServerVersion}}'

echo; echo "=== Groups ==="
id

echo; echo "=== LD_LIBRARY_PATH ==="
[[ -z "$LD_LIBRARY_PATH" ]] && echo "<empty>" || echo "$LD_LIBRARY_PATH"
```

Save as `scripts/host_check.sh` and run any time:

```bash
bash scripts/host_check.sh > host_report.md
```

Attach `host_report.md` to bug reports or GitHub issues.

---

**You’re ready!** Clone this repo, follow the steps, and enjoy ROS 2 Humble on the RZ/V2H.
