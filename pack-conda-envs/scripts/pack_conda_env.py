#!/usr/bin/env python3
"""Package conda environments into a workspace archive directory with dedupe."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path
from typing import Sequence


DEFAULT_OUTPUT_ROOT = Path("/home/phl/workspace/conda-env-packs")
CHUNK_SIZE = 1024 * 1024
MANIFEST_VERSION = 1


@dataclass(frozen=True)
class EnvIdentity:
    name: str
    prefix: Path


def die(message: str) -> None:
    print(f"[pack-conda-envs] Error: {message}", file=sys.stderr)
    raise SystemExit(1)


def run(
    cmd: Sequence[str],
    *,
    check: bool = True,
    capture: bool = True,
    env: dict[str, str] | None = None,
) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        list(cmd),
        check=check,
        text=True,
        stdout=subprocess.PIPE if capture else None,
        stderr=subprocess.PIPE if capture else None,
        env=env,
    )


def sha256_text(text: str) -> str:
    return hashlib.sha256(text.encode("utf-8")).hexdigest()


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(CHUNK_SIZE), b""):
            digest.update(chunk)
    return digest.hexdigest()


def safe_name(value: str) -> str:
    cleaned = re.sub(r"[^A-Za-z0-9_.-]+", "-", value.strip())
    cleaned = cleaned.strip(".-")
    return cleaned or "conda-env"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Pack the current or selected conda environment into /home/phl/workspace/conda-env-packs without duplicates."
    )
    selector = parser.add_mutually_exclusive_group()
    selector.add_argument("--env-name", help="Conda environment name to pack")
    selector.add_argument("--env-prefix", type=Path, help="Conda environment prefix to pack")
    parser.add_argument(
        "--output-root",
        type=Path,
        default=DEFAULT_OUTPUT_ROOT,
        help=f"Archive directory (default: {DEFAULT_OUTPUT_ROOT})",
    )
    parser.add_argument(
        "--archive-name",
        help="Archive base name without .tar.gz. Defaults to <env-name>-<fingerprint>.",
    )
    parser.add_argument(
        "--ignore-editable-packages",
        action="store_true",
        help="Pass --ignore-editable-packages to conda pack.",
    )
    parser.add_argument(
        "--ignore-missing-files",
        action="store_true",
        help="Pass --ignore-missing-files to conda pack.",
    )
    parser.add_argument(
        "--force",
        action="store_true",
        help="Create a new archive even if the same environment fingerprint already exists.",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Print the selected environment, fingerprint, and output path without running conda pack.",
    )
    parser.add_argument(
        "--list-existing",
        action="store_true",
        help="List existing manifests under output-root and exit.",
    )
    parser.add_argument(
        "--conda",
        default=os.environ.get("CONDA_EXE") or shutil.which("conda") or "conda",
        help="Path to conda executable.",
    )
    parser.add_argument(
        "--conda-pack",
        default=shutil.which("conda-pack") or "conda-pack",
        help="Path to conda-pack executable.",
    )
    return parser.parse_args()


def resolve_env(args: argparse.Namespace) -> EnvIdentity:
    if args.env_prefix:
        prefix = args.env_prefix.expanduser().resolve()
        if not prefix.is_dir():
            die(f"env prefix does not exist: {prefix}")
        return EnvIdentity(name=prefix.name, prefix=prefix)

    if args.env_name:
        env_name = args.env_name
        if env_name == "base":
            proc = run([args.conda, "info", "--base"], check=False)
            if proc.returncode == 0 and proc.stdout.strip():
                prefix = Path(proc.stdout.strip()).expanduser().resolve()
                if prefix.is_dir():
                    return EnvIdentity(name="base", prefix=prefix)
        proc = run([args.conda, "env", "list", "--json"])
        data = json.loads(proc.stdout)
        for item in data.get("envs", []):
            prefix = Path(item).expanduser().resolve()
            if prefix.name == env_name:
                return EnvIdentity(name=env_name, prefix=prefix)
        die(f"conda env not found: {env_name}")

    prefix_text = os.environ.get("CONDA_PREFIX")
    if not prefix_text:
        die("no active conda env. Activate one first, or pass --env-name/--env-prefix.")
    prefix = Path(prefix_text).expanduser().resolve()
    if not prefix.is_dir():
        die(f"CONDA_PREFIX does not exist: {prefix}")
    name = os.environ.get("CONDA_DEFAULT_ENV") or prefix.name
    return EnvIdentity(name=name, prefix=prefix)


def conda_explicit_spec(conda: str, prefix: Path) -> str:
    proc = run([conda, "list", "-p", str(prefix), "--explicit"], check=False)
    if proc.returncode != 0:
        die(f"failed to collect conda explicit spec:\n{proc.stderr.strip()}")
    return proc.stdout


def pip_freeze(prefix: Path) -> str:
    python_bin = prefix / "bin" / "python"
    if not python_bin.exists():
        return ""
    proc = run([str(python_bin), "-m", "pip", "freeze"], check=False)
    if proc.returncode != 0:
        return ""
    return proc.stdout


def python_version(prefix: Path) -> str:
    python_bin = prefix / "bin" / "python"
    if not python_bin.exists():
        return "unknown"
    proc = run([str(python_bin), "-c", "import sys; print(sys.version.split()[0])"], check=False)
    if proc.returncode != 0:
        return "unknown"
    return proc.stdout.strip() or "unknown"


def build_manifest(
    env: EnvIdentity,
    args: argparse.Namespace,
    *,
    explicit_spec: str,
    freeze: str,
) -> dict[str, object]:
    return {
        "manifest_version": MANIFEST_VERSION,
        "env_name": env.name,
        "env_prefix": str(env.prefix),
        "python_version": python_version(env.prefix),
        "conda_explicit_sha256": sha256_text(explicit_spec),
        "pip_freeze_sha256": sha256_text(freeze),
        "pack_options": {
            "ignore_editable_packages": bool(args.ignore_editable_packages),
            "ignore_missing_files": bool(args.ignore_missing_files),
        },
    }


def fingerprint_manifest(manifest: dict[str, object]) -> str:
    stable = {
        key: manifest[key]
        for key in (
            "manifest_version",
            "env_name",
            "env_prefix",
            "python_version",
            "conda_explicit_sha256",
            "pip_freeze_sha256",
            "pack_options",
        )
    }
    payload = json.dumps(stable, sort_keys=True, ensure_ascii=True)
    return sha256_text(payload)[:16]


def load_json(path: Path) -> dict[str, object] | None:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return None


def existing_manifests(output_root: Path) -> list[tuple[Path, dict[str, object]]]:
    result: list[tuple[Path, dict[str, object]]] = []
    for path in sorted(output_root.glob("*.manifest.json")):
        data = load_json(path)
        if isinstance(data, dict):
            result.append((path, data))
    return result


def matching_archive(
    output_root: Path,
    manifest: dict[str, object],
    fingerprint: str,
) -> tuple[Path, Path] | None:
    for manifest_path, data in existing_manifests(output_root):
        if data.get("fingerprint") != fingerprint:
            continue
        archive_name = data.get("archive")
        if not isinstance(archive_name, str):
            continue
        archive_path = output_root / archive_name
        if not archive_path.exists():
            continue
        comparable = {
            key: data.get(key)
            for key in (
                "manifest_version",
                "env_name",
                "env_prefix",
                "python_version",
                "conda_explicit_sha256",
                "pip_freeze_sha256",
                "pack_options",
            )
        }
        expected = {
            key: manifest.get(key)
            for key in (
                "manifest_version",
                "env_name",
                "env_prefix",
                "python_version",
                "conda_explicit_sha256",
                "pip_freeze_sha256",
                "pack_options",
            )
        }
        if comparable == expected:
            return archive_path, manifest_path
    return None


def list_existing(output_root: Path) -> None:
    if not output_root.exists():
        print(f"No archive directory: {output_root}")
        return
    rows = existing_manifests(output_root)
    if not rows:
        print(f"No manifests found under: {output_root}")
        return
    for manifest_path, data in rows:
        print(
            f"{data.get('env_name', '?')}\t{data.get('fingerprint', '?')}\t"
            f"{data.get('archive', '?')}\t{manifest_path}"
        )


def conda_pack_cmd(args: argparse.Namespace, env: EnvIdentity, archive_path: Path) -> list[str]:
    cmd = [
        args.conda_pack,
        "-p",
        str(env.prefix),
        "-o",
        str(archive_path),
    ]
    if args.ignore_editable_packages:
        cmd.append("--ignore-editable-packages")
    if args.ignore_missing_files:
        cmd.append("--ignore-missing-files")
    if args.force:
        cmd.append("--force")
    return cmd


def main() -> None:
    args = parse_args()
    output_root = args.output_root.expanduser().resolve()

    if args.list_existing:
        list_existing(output_root)
        return

    env = resolve_env(args)
    output_root.mkdir(parents=True, exist_ok=True)

    explicit_spec = conda_explicit_spec(args.conda, env.prefix)
    freeze = pip_freeze(env.prefix)
    manifest = build_manifest(env, args, explicit_spec=explicit_spec, freeze=freeze)
    fingerprint = fingerprint_manifest(manifest)
    archive_base = safe_name(args.archive_name or f"{env.name}-{fingerprint}")
    archive_name = f"{archive_base}.tar.gz"
    archive_path = output_root / archive_name
    manifest_path = output_root / f"{archive_base}.manifest.json"
    sha_path = output_root / f"{archive_base}.sha256"

    print(f"[pack-conda-envs] env_name:     {env.name}")
    print(f"[pack-conda-envs] env_prefix:   {env.prefix}")
    print(f"[pack-conda-envs] output_root:  {output_root}")
    print(f"[pack-conda-envs] fingerprint:  {fingerprint}")
    print(f"[pack-conda-envs] archive:      {archive_path}")

    match = matching_archive(output_root, manifest, fingerprint)
    if match and not args.force:
        existing_archive, existing_manifest = match
        print("[pack-conda-envs] skip: matching archive already exists")
        print(f"[pack-conda-envs] existing_archive:  {existing_archive}")
        print(f"[pack-conda-envs] existing_manifest: {existing_manifest}")
        return

    if args.dry_run:
        print("[pack-conda-envs] dry-run: conda pack was not executed")
        return

    if shutil.which(args.conda_pack) is None and not Path(args.conda_pack).exists():
        die("conda-pack not found. Install with: conda install -c conda-forge conda-pack")

    cmd = conda_pack_cmd(args, env, archive_path)
    print("[pack-conda-envs] running:", " ".join(cmd))
    with tempfile.NamedTemporaryFile("w", delete=False, encoding="utf-8", suffix=".log") as log_file:
        log_path = Path(log_file.name)
    try:
        with log_path.open("w", encoding="utf-8") as log_file:
            proc = subprocess.run(cmd, text=True, stdout=log_file, stderr=subprocess.STDOUT)
        if proc.returncode != 0:
            try:
                tail = log_path.read_text(encoding="utf-8")[-4000:]
            except OSError:
                tail = ""
            die(f"conda pack failed; log: {log_path}\n{tail}")
    finally:
        if archive_path.exists():
            try:
                log_path.unlink()
            except OSError:
                pass

    archive_sha = sha256_file(archive_path)
    full_manifest = dict(manifest)
    full_manifest.update(
        {
            "created_at": datetime.now().isoformat(timespec="seconds"),
            "fingerprint": fingerprint,
            "archive": archive_name,
            "archive_sha256": archive_sha,
            "archive_size_bytes": archive_path.stat().st_size,
            "conda_pack_command": cmd,
        }
    )
    manifest_path.write_text(json.dumps(full_manifest, indent=2, ensure_ascii=False), encoding="utf-8")
    sha_path.write_text(f"{archive_sha}  {archive_name}\n", encoding="utf-8")

    print("[pack-conda-envs] packed")
    print(f"[pack-conda-envs] manifest: {manifest_path}")
    print(f"[pack-conda-envs] sha256:   {sha_path}")


if __name__ == "__main__":
    main()
