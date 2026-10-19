#!/usr/bin/env python3
"""Opgave: anden shebang end Bash — lille Python-demo."""
import platform
import sys
from datetime import datetime

def main() -> None:
    print("=== Python-demo (ikke Bash) ===")
    print(f"Shebang-fortolker : {sys.executable}")
    print(f"Python-version    : {sys.version.split()[0]}")
    print(f"Platform          : {platform.platform()}")
    print(f"Tidspunkt         : {datetime.now():%Y-%m-%d %H:%M:%S}")
    print("OK — scriptet kørte via #!/usr/bin/env python3")

if __name__ == "__main__":
    main()
