# SecFlow

**SecFlow** is a multi-layered security hardening framework that offers a step-by-step approach (Tier 1 → Tier 5+) to gradually increase your server’s security posture.

## Features

1. **Tier 1** – Basic firewall (UFW), new sudo user, simple kernel tuning.

2. **Tier 2** – Fail2Ban, optional passwordless SSH, additional kernel tuning.

3. **Tier 3** – Basic rate-limited Auditd, Rkhunter, Nginx.

4. **Tier 4** – Critical immutable files, LVM snapshot, AppArmor/SELinux.

5. **Tier 5** – Suricata IDS, Falco, honeypot integration, advanced logging.

Each layer logs its state and actions in the file `/etc/secure-me.json` (JSON format), so you can see which layer is loaded and what changes are made. Scripts can also automatically load missing sublayers.

## Usage

1. Clone the repository:
```bash
git clone https://github.com/imcanugur/SecFlow.git
