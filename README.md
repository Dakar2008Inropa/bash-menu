# bash-menu

Terminal-menu i Bash til en Linux-server: processer, services, filer, brugere, netværk, Docker, health check, SSH, plus Fun og Games.

Krav: Bash, en terminal på ca. 76×36, og almindelige værktøjer (`ps`, `find`, `systemctl`, `ss`). Testet på Debian 13.

## Installer og kør

```bash
curl -fsSL https://raw.githubusercontent.com/Dakar2008Inropa/bash-menu/main/install.sh | bash
cd ~/bash-menu
./menu.sh -n
```

`curl` installeres med `sudo apt install curl`, hvis den mangler. Uden `-n` vises en boot-skærm først.

Installeren lægger ikonet **Bash-menu** på skrivebordet og i applikationsmenuen. Det åbner menuen i et terminalvindue. På GNOME skal man nogle gange højreklikke og vælge Tillad start.

## Manuel

```bash
git clone https://github.com/Dakar2008Inropa/bash-menu.git
cd bash-menu
./install.sh
./menu.sh -n
```

## Indhold

| Sti | Rolle |
|-----|--------|
| `menu.sh` | Starter menuen |
| `lib/` | System, tools, SSH, Fun, boot |
| `games/` | Spillene |
| `tools/` | Python-demo og mygrep |
| `install.sh` | Installerer til `~/bash-menu` og lægger et skrivebordsikon |
