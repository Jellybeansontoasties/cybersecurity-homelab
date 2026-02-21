# Cybersecurity Home Lab Portfolio

A minimal, terminal-themed portfolio website documenting cybersecurity home lab activities, attack writeups, and lab environment configuration.

## Description

This site documents my personal cybersecurity home lab running on Arch Linux with KVM/QEMU virtualization. It serves as a portfolio showcasing penetration testing exercises, vulnerability assessments, and security research conducted in an isolated lab environment.

## Live Site

🌐 **GitHub Pages:** `https://<username>.github.io/portfolio-site/`

*(Replace `<username>` with your GitHub username after deploying)*

## Tools & Technologies

- **Host OS:** Arch Linux
- **Virtualization:** KVM/QEMU
- **Attack Platform:** Kali Linux
- **Target Systems:** Metasploitable 2, Ubuntu Server 22.04
- **Network:** Isolated virbr1 bridge (192.168.100.0/24)
- **Web:** HTML5, CSS3, SVG

## Virtual Machines

| VM Name | Role | OS |
|---------|------|-----|
| Kali | Attacker | Kali Linux |
| Metasploitable 2 | Victim 1 | Ubuntu 8.04 (Hardened) |
| Ubuntu Server 22.04 | Victim 2 | Ubuntu Server 22.04 LTS |

## Project Structure

```
portfolio-site/
├── index.html              # Landing page
├── lab-setup.html          # Lab environment documentation
├── writeups/               # Attack writeups
│   ├── writeup-01.html     # vsftpd 2.3.4 Backdoor
│   └── writeup-02.html     # SSH Brute Force
├── assets/
│   ├── css/
│   │   └── style.css       # Terminal-themed stylesheet
│   └── img/                 # Screenshots and diagrams
└── README.md               # This file
```

## Design Theme

- **Background:** `#1B0906` (deep dark red-brown)
- **Primary Accent:** `#FF8C00` (orange)
- **Secondary Accent:** `#3a401a` (dark moss green)
- **Text:** `#e0e0e0` (light gray)
- **Font:** JetBrains Mono / Fira Code (monospace)

## Deployment

This site is designed to be deployed on GitHub Pages. Simply push the repository to GitHub and enable GitHub Pages in the repository settings.

## License

This portfolio site is for educational and demonstration purposes only. All security research is conducted in an isolated lab environment.
