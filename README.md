# Endpoint Security & Monitoring with Wazuh

**Internee.pk Cybersecurity Internship — Task: Implement Endpoint Security & Monitoring**
Author: Azka Sehar

A home-lab SOC built to protect endpoints from malware and unauthorized access, using **Wazuh 4.14** (SIEM + EDR), **Sysmon**, and **MalwareBazaar** threat intelligence.

---

## Objective

Protect Internee.pk's devices and servers from malware and unauthorized access.

| Deliverable | How it was done |
|---|---|
| Deploy EDR (Wazuh) | Wazuh 4.14 all-in-one server on Ubuntu, agent on Windows 10 |
| Monitor file integrity | Real-time FIM on `C:\InterneeData` (rules 554 / 550 / 553) |
| Monitor user activity | Windows Security log, failed logons (rule 60122) |
| Automate alerts | Custom brute-force rule **100100** (level 12, MITRE T1110) |
| Sysmon logs | Sysmon (SwiftOnSecurity config) read by the agent via eventchannel |
| MalwareBazaar threat intel | CDB list of malware MD5 hashes + custom rule **100200** (level 13) |

---

## Lab architecture

```
┌──────────────────────────┐        logs & events        ┌──────────────────────────┐
│  Windows 10 (endpoint)   │  ─────────────────────────▶ │  Ubuntu 24.04 (server)   │
│  Wazuh agent 4.14.9      │      TCP 1514 / 1515        │  Wazuh manager           │
│  Sysmon64                │                             │  Wazuh indexer           │
│  FIM: C:\InterneeData    │                             │  Wazuh dashboard (443)   │
│  192.168.247.131         │                             │  192.168.247.130         │
└──────────────────────────┘                             └──────────────────────────┘
              Both VMs on the same VMware NAT network
```

Server VM: 4+ vCPU, 8+ GB RAM, 50 GB disk (Wazuh quickstart recommendation for 1–25 agents).

---

## Repository layout

```
server/
  local_rules.xml          custom detection rules (100100, 100200)
  malware-hashes           CDB list: known-malware MD5 hashes
  ossec-conf-snippet.xml   registering the CDB list in the manager
  systemd-override.conf    longer start timeout for wazuh-manager
agent/
  ossec-agent-snippet.xml  Sysmon collection + FIM directory
scripts/
  fim-test.ps1             create / modify / delete a file to test FIM
  bruteforce-test.ps1      generate failed logons to test rule 100100
  eicar-test.ps1           create the harmless EICAR test file
screenshots/               evidence for each deliverable
```

---

## Setup

### 1. Wazuh server (Ubuntu)

```bash
curl -sO https://packages.wazuh.com/4.14/wazuh-install.sh && sudo bash ./wazuh-install.sh -a
```

Optional, if `wazuh-manager` times out at boot:

```bash
sudo mkdir -p /etc/systemd/system/wazuh-manager.service.d
sudo cp server/systemd-override.conf /etc/systemd/system/wazuh-manager.service.d/override.conf
sudo systemctl daemon-reload
```

### 2. Wazuh agent (Windows 10)

Dashboard → Agents management → Deploy new agent → Windows MSI, server address `192.168.247.130`, then in an Admin PowerShell:

```powershell
NET START WazuhSvc
```

### 3. Sysmon

```powershell
.\Sysmon64.exe -accepteula -i sysmonconfig.xml
```

Config: [SwiftOnSecurity/sysmon-config](https://github.com/SwiftOnSecurity/sysmon-config). Then append `agent/ossec-agent-snippet.xml` to
`C:\Program Files (x86)\ossec-agent\ossec.conf` and run `Restart-Service WazuhSvc`.

### 4. Custom rules and threat intel (server)

```bash
sudo cp server/malware-hashes /var/ossec/etc/lists/malware-hashes
sudo chown wazuh:wazuh /var/ossec/etc/lists/malware-hashes
# add the <list> line from server/ossec-conf-snippet.xml inside <ruleset> in /var/ossec/etc/ossec.conf
sudo bash -c 'cat server/local_rules.xml >> /var/ossec/etc/rules/local_rules.xml'
sudo systemctl restart wazuh-manager
```

---

## Testing

| Test | Command (Windows, Admin PowerShell) | Expected alert |
|---|---|---|
| FIM | `.\scripts\fim-test.ps1` | 554 added → 550 modified → 553 deleted |
| Brute force | `.\scripts\bruteforce-test.ps1` (wrong password ×3) | 60122 ×3, then **100100** level 12 |
| Malware hash | `.\scripts\eicar-test.ps1` | **100200** level 13 on `eicar.com` |

Search in Dashboard → Threat Hunting → Events, e.g. `rule.id:100100`.

> EICAR is a harmless, industry-standard antivirus test string, not malware. Windows Defender deletes it instantly, so add a temporary exclusion for `C:\InterneeData` during the test and remove it afterwards:
> `Add-MpPreference -ExclusionPath "C:\InterneeData"` / `Remove-MpPreference -ExclusionPath "C:\InterneeData"`

---

## Results

- Agent `internee-win10` active and reporting in real time
- FIM detected file creation, modification (with diff) and deletion within ~1 second
- Failed logons detected (rule 60122) and escalated by the custom brute-force rule to level 12
- Sysmon events triggered built-in detections (PowerShell creating executables, possible DLL search-order hijack, executable dropped in a malware-common folder)
- EICAR detected as known malware via MD5 match against the MalwareBazaar CDB list (level 13)

### Alert triage

A level-15 alert (rule 92213, *Executable file dropped in folder commonly used by malware*) was investigated. The process was `msedge.exe` writing a DLL into `AppData\Local\Temp\msedge_chrome_Unpacker...`, Microsoft Edge's self-update. **Verdict: false positive.** In production this rule could be tuned to ignore trusted, signed Microsoft processes.

---

## Challenges and learnings

- **VMs on different networks** (Bridged vs NAT): diagnosed with `ipconfig` and `Test-NetConnection`, fixed by putting both on NAT.
- **Agent stopped silently**: `ossec.log` showed `ERROR (1226): Error reading XML file 'ossec.conf'`; fixed by reinstalling the agent and writing config programmatically.
- **Host crashes mid-install**: verified state from `/var/log/wazuh-install.log` before redoing; used VM snapshots as save points.
- **Manager start timeout at boot**: added a systemd override with `TimeoutStartSec=300`.
- Biggest lesson: installing tools is half the job; understanding why an alert fired, and whether it is real, is what matters.

## Possible next steps

- Email/Slack notifications for level ≥ 12 alerts (alerts are already flagged `mail: true`)
- Active response to delete files matching the malware hash list
- Automated pull of the latest MalwareBazaar hashes (requires a free abuse.ch Auth-Key)

## References

- [Wazuh Quickstart](https://documentation.wazuh.com/current/quickstart.html)
- [Wazuh: CDB lists and threat intelligence](https://documentation.wazuh.com/current/user-manual/capabilities/malware-detection/cdb-lists-threat-intelligence.html)
- [Wazuh blog: Detecting threats with Sysmon](https://wazuh.com/blog/learn-to-detect-threats-on-windows-by-monitoring-sysmon-events)
- [MalwareBazaar](https://bazaar.abuse.ch/)
