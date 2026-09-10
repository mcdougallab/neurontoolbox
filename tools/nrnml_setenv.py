import ctypes
import os
import sys
import winreg


def normalize_path(value: str) -> str:
    return os.path.normcase(os.path.normpath(os.path.expandvars(value)))


def append_env(name: str, value: str) -> None:
    with winreg.OpenKey(
        winreg.HKEY_CURRENT_USER,
        "Environment",
        0,
        winreg.KEY_READ | winreg.KEY_WRITE,
    ) as key:
        try:
            current, _ = winreg.QueryValueEx(key, name)
        except FileNotFoundError:
            current = ""

        parts = [part for part in current.split(";") if part]
        normalized_parts = {normalize_path(part) for part in parts}
        normalized_value = normalize_path(value)

        if normalized_value in normalized_parts:
            print(f"  Already in {name}, skipping")
            return

        parts.append(value)
        winreg.SetValueEx(key, name, 0, winreg.REG_EXPAND_SZ, ";".join(parts))
        print(f"  Updated {name}")


def main() -> int:
    if len(sys.argv[1:]) % 2 != 0:
        print("usage: nrnml_setenv.py NAME VALUE [NAME VALUE ...]", file=sys.stderr)
        return 2

    for name, value in zip(sys.argv[1::2], sys.argv[2::2]):
        append_env(name, value)

    ctypes.windll.user32.SendMessageTimeoutW(
        0xFFFF,
        0x1A,
        0,
        "Environment",
        2,
        5000,
        None,
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
