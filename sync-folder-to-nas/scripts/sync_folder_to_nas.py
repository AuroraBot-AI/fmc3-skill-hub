#!/usr/bin/env python3
"""Synchronize a local folder to NAS without copying duplicate content."""

from __future__ import annotations

import argparse
import fnmatch
import hashlib
import json
import os
import shutil
import sys
import tempfile
from dataclasses import dataclass, asdict
from datetime import datetime
from pathlib import Path


DEFAULT_DEST_ROOT = Path("/home/phl/FermiBotNas/backups")
DEFAULT_EXCLUDES = [".git/**", "__pycache__/**", ".cache/**"]
CHUNK_SIZE = 1024 * 1024


@dataclass
class FilePlan:
    action: str
    source: str
    destination: str | None
    size: int
    sha256: str
    reason: str


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Sync a local folder to the FermiBot NAS without duplicate content."
    )
    parser.add_argument("source", type=Path, help="Local folder to sync")
    parser.add_argument(
        "--dest-root",
        type=Path,
        default=DEFAULT_DEST_ROOT,
        help=f"NAS root to scan and write under (default: {DEFAULT_DEST_ROOT})",
    )
    parser.add_argument(
        "--dest-name",
        help="Destination subfolder name under dest-root (default: source folder name)",
    )
    parser.add_argument(
        "--execute",
        action="store_true",
        help="Actually copy files. Without this flag, only print a dry-run plan.",
    )
    parser.add_argument("--report", type=Path, help="JSON report path")
    parser.add_argument(
        "--exclude",
        action="append",
        default=[],
        help="Glob pattern to exclude, relative to source root. Can be repeated.",
    )
    parser.add_argument(
        "--include-hidden",
        action="store_true",
        help="Include hidden files and directories. Hidden paths are skipped by default.",
    )
    return parser.parse_args()


def die(message: str) -> None:
    print(f"[sync-folder-to-nas] Error: {message}", file=sys.stderr)
    raise SystemExit(1)


def relative_posix(path: Path, root: Path) -> str:
    return path.relative_to(root).as_posix()


def is_hidden_relative(rel: str) -> bool:
    return any(part.startswith(".") for part in rel.split("/"))


def matches_any(rel: str, patterns: list[str]) -> bool:
    return any(fnmatch.fnmatch(rel, pattern) for pattern in patterns)


def iter_files(root: Path, excludes: list[str], include_hidden: bool) -> list[Path]:
    files: list[Path] = []
    for dirpath, dirnames, filenames in os.walk(root):
        current = Path(dirpath)
        rel_dir = "." if current == root else relative_posix(current, root)

        kept_dirnames = []
        for dirname in dirnames:
            child_rel = dirname if rel_dir == "." else f"{rel_dir}/{dirname}"
            child_rel_dir = f"{child_rel}/**"
            if (not include_hidden and is_hidden_relative(child_rel)) or matches_any(child_rel_dir, excludes):
                continue
            kept_dirnames.append(dirname)
        dirnames[:] = kept_dirnames

        for filename in filenames:
            path = current / filename
            rel = relative_posix(path, root)
            if not include_hidden and is_hidden_relative(rel):
                continue
            if matches_any(rel, excludes):
                continue
            files.append(path)
    return files


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(CHUNK_SIZE), b""):
            digest.update(chunk)
    return digest.hexdigest()


def unique_conflict_path(path: Path) -> Path:
    stem = path.stem
    suffix = path.suffix
    parent = path.parent
    counter = 1
    while True:
        candidate = parent / f"{stem}.conflict-{counter}{suffix}"
        if not candidate.exists():
            return candidate
        counter += 1


def build_nas_hash_index(dest_root: Path, excludes: list[str], include_hidden: bool) -> dict[str, list[Path]]:
    index: dict[str, list[Path]] = {}
    for path in iter_files(dest_root, excludes, include_hidden):
        file_hash = sha256_file(path)
        index.setdefault(file_hash, []).append(path)
    return index


def plan_sync(
    source: Path,
    dest_root: Path,
    dest_dir: Path,
    excludes: list[str],
    include_hidden: bool,
) -> list[FilePlan]:
    nas_hashes = build_nas_hash_index(dest_root, excludes, include_hidden) if dest_root.exists() else {}
    plans: list[FilePlan] = []

    for src in iter_files(source, excludes, include_hidden):
        rel = Path(relative_posix(src, source))
        src_hash = sha256_file(src)
        size = src.stat().st_size

        if src_hash in nas_hashes:
            plans.append(
                FilePlan(
                    action="skip_duplicate",
                    source=str(src),
                    destination=str(nas_hashes[src_hash][0]),
                    size=size,
                    sha256=src_hash,
                    reason="same content already exists on NAS",
                )
            )
            continue

        dst = dest_dir / rel
        if dst.exists():
            dst_hash = sha256_file(dst)
            if dst_hash == src_hash:
                action = "skip_same_path"
                final_dst = dst
                reason = "same content already exists at target path"
            else:
                action = "copy_conflict"
                final_dst = unique_conflict_path(dst)
                reason = "target path exists with different content"
        else:
            action = "copy"
            final_dst = dst
            reason = "new content"

        plans.append(
            FilePlan(
                action=action,
                source=str(src),
                destination=str(final_dst),
                size=size,
                sha256=src_hash,
                reason=reason,
            )
        )
    return plans


def execute_plan(plans: list[FilePlan]) -> None:
    for item in plans:
        if not item.action.startswith("copy"):
            continue
        if item.destination is None:
            continue
        src = Path(item.source)
        dst = Path(item.destination)
        dst.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(src, dst)


def summarize(plans: list[FilePlan]) -> dict[str, int]:
    summary: dict[str, int] = {}
    for item in plans:
        summary[item.action] = summary.get(item.action, 0) + 1
    return summary


def write_report(report_path: Path, source: Path, dest_root: Path, dest_dir: Path, plans: list[FilePlan], executed: bool) -> None:
    report_path.parent.mkdir(parents=True, exist_ok=True)
    payload = {
        "created_at": datetime.now().isoformat(timespec="seconds"),
        "executed": executed,
        "source": str(source),
        "dest_root": str(dest_root),
        "dest_dir": str(dest_dir),
        "summary": summarize(plans),
        "items": [asdict(item) for item in plans],
    }
    report_path.write_text(json.dumps(payload, indent=2, ensure_ascii=False), encoding="utf-8")


def main() -> None:
    args = parse_args()
    source = args.source.expanduser().resolve()
    dest_root = args.dest_root.expanduser().resolve()

    if not source.is_dir():
        die(f"source folder does not exist: {source}")
    if not dest_root.exists():
        if args.execute:
            dest_root.mkdir(parents=True, exist_ok=True)
        else:
            die(f"dest root does not exist in dry-run mode: {dest_root}")
    if not dest_root.is_dir():
        die(f"dest root is not a directory: {dest_root}")

    dest_name = args.dest_name or source.name
    dest_dir = dest_root / dest_name
    excludes = DEFAULT_EXCLUDES + args.exclude

    plans = plan_sync(source, dest_root, dest_dir, excludes, args.include_hidden)
    summary = summarize(plans)

    if args.execute:
        execute_plan(plans)

    report_path = args.report
    if report_path is None:
        timestamp = datetime.now().strftime("%Y%m%d-%H%M%S")
        if args.execute:
            report_path = dest_dir / f".sync_report_{timestamp}.json"
        else:
            report_path = Path(tempfile.gettempdir()) / f"sync_folder_to_nas_dryrun_{timestamp}.json"
    write_report(report_path.expanduser().resolve(), source, dest_root, dest_dir, plans, args.execute)

    mode = "EXECUTED" if args.execute else "DRY-RUN"
    print(f"[sync-folder-to-nas] {mode}")
    print(f"source:    {source}")
    print(f"dest_root: {dest_root}")
    print(f"dest_dir:  {dest_dir}")
    print(f"report:    {report_path}")
    for action, count in sorted(summary.items()):
        print(f"{action}: {count}")

    copy_count = sum(count for action, count in summary.items() if action.startswith("copy"))
    if not args.execute and copy_count:
        print("Run again with --execute to copy planned files.")


if __name__ == "__main__":
    main()
