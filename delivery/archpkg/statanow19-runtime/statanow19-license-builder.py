#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

ALPH = "0123456789abcdefghijklmnopqrstuvwxyz$"
MOD = 37
PROFILE_NAME = "statanow19"
DISPLAY_NAME = "StataNow 19"
DEFAULT_PRESET = "mp64"
DEFAULT_OUTPUT = "~/.config/statanow19-runtime/stata.lic"
FIELD6_REQUIRED = True
YEAR_MAX = 2050
DEFAULTS = {
    "serial": "12345678",
    "field1": "999",
    "field2": "24",
    "field3": "5",
    "field4": "9999",
    "field5": "h",
    "field6": "01012050",
    "field7": "64",
    "line1": "LocalLab",
    "line2": "LocalLab",
}
PRESETS = {
    "be": {**DEFAULTS, "field7": ""},
    "mp32": {**DEFAULTS, "field7": "32"},
    "mp64": {**DEFAULTS, "field7": "64"},
}


def to_digits(text: str) -> list[int]:
    out: list[int] = []
    for ch in text:
        if "0" <= ch <= "9":
            out.append(ord(ch) - 48)
        elif "a" <= ch <= "z":
            out.append(ord(ch) - 87)
        elif "A" <= ch <= "Z":
            out.append(ord(ch) - 55)
        elif ch == "$":
            out.append(36)
        else:
            raise ValueError(f"unsupported character: {ch!r}")
    return out


def from_digits(values: list[int]) -> str:
    return "".join(ALPH[v] for v in values)


def encode_payload(payload: str) -> str:
    prefix = to_digits(payload)
    checks = [
        sum(prefix) % MOD,
        sum(prefix[i] for i in range(len(prefix)) if i & 1) % MOD,
        sum(prefix[i] for i in range(len(prefix)) if not (i & 1)) % MOD,
    ]
    y = prefix + checks
    partials: list[int] = []
    acc = 0
    for value in y:
        acc = (acc + value) % MOD
        partials.append(acc)

    encoded = [0] * len(y)
    encoded[-1] = partials[-1]
    for i in range(len(y) - 2, -1, -1):
        encoded[i] = (partials[i] + encoded[i + 1]) % MOD
    return from_digits(encoded)


def split_encoded(encoded: str, split_prefix: int = 4) -> tuple[str, str]:
    if split_prefix <= 0 or split_prefix >= len(encoded):
        raise ValueError(f"invalid split_prefix={split_prefix} for encoded length {len(encoded)}")
    return encoded[:split_prefix], encoded[split_prefix:]


def checksum(line1: str, line2: str) -> int:
    return sum(line1.encode()) + sum(line2.encode())


def build_payload(fields: dict[str, str]) -> str:
    parts = [
        fields["serial"],
        fields["field1"],
        fields["field2"],
        fields["field3"],
        fields["field4"],
        fields["field5"],
        fields["field6"],
    ]
    if fields["field7"] != "":
        parts.append(fields["field7"])
    return "$".join(parts)


def build_bundle(fields: dict[str, str], split_prefix: int = 4) -> dict[str, str]:
    payload = build_payload(fields)
    encoded = encode_payload(payload)
    authorization, code = split_encoded(encoded, split_prefix)
    total = checksum(fields["line1"], fields["line2"])
    license_text = (
        f"{fields['serial']}!{code}!{authorization}!{fields['line1']}!{fields['line2']}!{total}!"
    )
    return {
        "profile": PROFILE_NAME,
        "display_name": DISPLAY_NAME,
        "serial": fields["serial"],
        "payload": payload,
        "encoded": encoded,
        "authorization": authorization,
        "code": code,
        "checksum": str(total),
        "license_text": license_text,
        "default_output": DEFAULT_OUTPUT,
    }


def validate(fields: dict[str, str]) -> tuple[list[str], list[str]]:
    errors: list[str] = []
    warnings: list[str] = []

    for key in ("serial", "field1", "field2", "field3", "field4"):
        if not fields[key].isdigit():
            errors.append(f"{key} must be decimal digits")

    if fields["field5"] == "" or fields["field5"][0] not in "abcdefgh":
        errors.append("field5 must start with a-h")

    if "!" in fields["line1"] or "!" in fields["line2"]:
        errors.append("Licensed-to lines cannot contain '!'")

    if FIELD6_REQUIRED and fields["field6"] == "":
        errors.append("field6 is required for this profile")

    if fields["field6"] != "":
        if len(fields["field6"]) != 8 or not fields["field6"].isdigit():
            errors.append("field6 must be 8 digits in MMDDYYYY format")
        elif YEAR_MAX is not None and int(fields["field6"][4:8]) > YEAR_MAX:
            errors.append(f"field6 year must be <= {YEAR_MAX}")

    if fields["field7"] != "":
        if not fields["field7"].isdigit():
            errors.append("field7 must be decimal digits when present")
        else:
            cores = int(fields["field7"])
            if cores < 2:
                errors.append("field7 must be >= 2 when present")
            elif cores > 64:
                warnings.append("field7 > 64 is accepted but runtime clamps it to 64")

    if fields["field2"] != "24":
        warnings.append("validated family uses field2=24")

    if fields["field3"] not in {"2", "5"}:
        warnings.append("validated family uses field3 in {2,5}")

    return errors, warnings


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=f"Generate installer fields and stata.lic for {DISPLAY_NAME}.")
    parser.add_argument("--preset", choices=sorted(PRESETS), default=DEFAULT_PRESET)
    parser.add_argument("--split-prefix", type=int, default=4)
    parser.add_argument("--output", help="write stata.lic to this path")
    parser.add_argument("--format", choices=("text", "json", "license-only"), default="text")
    parser.add_argument("--allow-warnings", action="store_true", help="return success even when warnings are present")
    for key in ("serial", "field1", "field2", "field3", "field4", "field5", "field6", "field7", "line1", "line2"):
        parser.add_argument(f"--{key}", default=None)
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    fields = dict(PRESETS[args.preset])
    for key in list(fields):
        value = getattr(args, key)
        if value is not None:
            fields[key] = value

    errors, warnings = validate(fields)
    if errors:
        for line in errors:
            print(f"error: {line}", file=sys.stderr)
        return 2
    if warnings and not args.allow_warnings:
        for line in warnings:
            print(f"warning: {line}", file=sys.stderr)
        print("warning: re-run with --allow-warnings to accept this parameter set", file=sys.stderr)
        return 3

    bundle = build_bundle(fields, args.split_prefix)
    if args.output:
        out_path = Path(args.output).expanduser()
        out_path.parent.mkdir(parents=True, exist_ok=True)
        out_path.write_text(bundle["license_text"])
        bundle["written_to"] = str(out_path)

    if args.format == "json":
        print(json.dumps(bundle, ensure_ascii=False, indent=2))
    elif args.format == "license-only":
        print(bundle["license_text"])
    else:
        print(f"Profile: {bundle['display_name']}")
        print(f"Payload: {bundle['payload']}")
        print(f"Serial number: {bundle['serial']}")
        print(f"Authorization: {bundle['authorization']}")
        print(f"Code: {bundle['code']}")
        print(f"Checksum: {bundle['checksum']}")
        if warnings:
            print("Warnings:")
            for line in warnings:
                print(f"- {line}")
        if args.output:
            print(f"License written to: {bundle['written_to']}")
        else:
            print(f"Suggested output path: {bundle['default_output']}")
        print("stata.lic:")
        print(bundle["license_text"])
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
