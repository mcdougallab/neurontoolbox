import sys
from pathlib import Path


def replace_once(content: str, old: str, new: str, label: str) -> str:
    count = content.count(old)
    if count != 1:
        raise RuntimeError(f"expected exactly one {label} pattern, found {count}")
    return content.replace(old, new, 1)


def main() -> int:
    if len(sys.argv) != 5:
        print("usage: nrnml_patch.py <src> <dst> <api_h> <nrniv>", file=sys.stderr)
        return 2

    src = Path(sys.argv[1])
    dst = Path(sys.argv[2])
    api_h = sys.argv[3]
    nrniv = sys.argv[4]

    content = src.read_text(encoding="utf-8")

    content = replace_once(
        content,
        r'#include "C:\nrn\include\neuronapi.h"',
        f'#include "{api_h}"',
        "neuronapi.h",
    )
    content = replace_once(
        content,
        r'DLL_LOAD("c:\\nrn\\bin\\libnrniv.dll")',
        f'DLL_LOAD("{nrniv.replace("\\", "\\\\")}")',
        "libnrniv",
    )

    dst.write_text(content, encoding="utf-8")
    print(f"  Patched: {dst}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
