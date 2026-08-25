import os
import sys
import winreg


def normalize_path(value):
    if not value or not value.strip():
        return None
    return os.path.normcase(os.path.normpath(os.path.expandvars(value)))


def main():
    if len(sys.argv) != 3:
        print("usage: nrnml_env_contains.py NAME VALUE", file=sys.stderr)
        return 2

    name, value = sys.argv[1], sys.argv[2]
    try:
        with winreg.OpenKey(winreg.HKEY_CURRENT_USER, "Environment") as key:
            current, _ = winreg.QueryValueEx(key, name)
    except FileNotFoundError:
        current = ""
    target = normalize_path(value)
    parts = [part for part in current.split(";") if part]

    for part in parts:
        if normalize_path(part) == target:
            return 0
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
