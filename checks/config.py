#!/usr/bin/env python3
"""Declarative config loader for the checks/ engineering harness.

Loads engineering.yaml once and exposes it as typed sections.
Direct port from snaplink's checks/config.py.
"""
import sys
from dataclasses import dataclass, field
from pathlib import Path
from typing import Optional

try:
    import yaml
except ImportError:
    yaml = None

DEFAULT_CONFIG_PATH = "engineering.yaml"


@dataclass
class ProjectConfig:
    name: str = ""
    language: str = "dart"


@dataclass
class FilesizeConfig:
    max_lines: int = 400
    ignore_patterns: list = field(default_factory=list)
    exemptions: list = field(default_factory=list)
    required_exemptions: list = field(default_factory=list)


@dataclass
class ComplexityConfig:
    max_cyclomatic: int = 12
    max_cognitive: int = 18
    ignore_pattern: str = ""
    exempt_functions: list = field(default_factory=list)
    gocyclo_path: str = ""
    gocognit_path: str = ""


@dataclass
class ArchitectureConfig:
    forbidden: dict = field(default_factory=dict)
    excluded_dirs: list = field(default_factory=list)


@dataclass
class DirectoryFanoutConfig:
    max_subdirs: int = 12
    exempt_dirs: list = field(default_factory=list)


@dataclass
class RootPolicyConfig:
    max_files: int = 12
    allowed_files: list = field(default_factory=list)
    allowed_prefixes: list = field(default_factory=list)
    banned_patterns: list = field(default_factory=list)
    banned_files: list = field(default_factory=list)
    exempt_files: list = field(default_factory=list)


@dataclass
class BuildConfig:
    output_dir: str = "build/web"
    base_href: str = "/"
    binaries: list = field(default_factory=list)


@dataclass
class B61bGatesConfig:
    """B6-1b debug-only ring copy surface gates (AC-1).

    Post-seam pin values (design b6-1b storage-seam §1.7): the seam pins
    are final, so the gate is red until the storage seam lands — the
    intended safe direction (W-1/W-2).
    """

    service_file: str = "lib/services/audit_log_service.dart"
    tab_file: str = "lib/screens/admin/audit_log_tab.dart"
    catalog_dir: str = "lib/i18n"
    catalog_file: str = "lib/i18n/app_strings_source_admin_core.dart"
    old_en_needles: list = field(default_factory=list)
    old_zh_needles: list = field(default_factory=list)
    new_keys: list = field(default_factory=list)
    service_kdebug_count: int = 6  # post-seam (interim was 2)
    tab_kdebug_count: int = 1
    initializer_pin: str = "_ringCopyEnabled = kDebugMode"
    storage_initializer_pin: str = "_storageEnabled = kDebugMode"
    guard_line: str = "if (!kDebugMode) return;"
    guard_line_count: int = 4
    # Key-reconstruction constructs banned in the service file (mask-ban
    # mirror of scan-6 R2.6, extended with the base64 family).
    banned_service_tokens: list = field(
        default_factory=lambda: [
            "String.fromCharCodes",
            "base64Decode",
            "base64Url",
        ]
    )
    # Recursive over build/web/ so chunked builds cannot widen the
    # artifact surface; missing dir is a failure, never a silent skip.
    artifact_dir: str = "build/web"
    artifact_en_needles: list = field(default_factory=list)
    # base64 / base64Url encodings of the sso_audit_log literal: a
    # masked write ships this text even though the source pins see no
    # literal.
    artifact_key_masks: list = field(default_factory=list)
    artifact_zh_escaped: list = field(default_factory=list)


@dataclass
class Config:
    project: ProjectConfig
    filesize: FilesizeConfig
    complexity: ComplexityConfig
    architecture: ArchitectureConfig
    directory_fanout: DirectoryFanoutConfig
    root_policy: RootPolicyConfig
    coverage_targets: dict
    build: BuildConfig
    skills_dir: str = "docs/skills"
    b6_1b_gates: B61bGatesConfig = field(default_factory=B61bGatesConfig)
    path: Optional[Path] = None


def _load_raw(path: Path) -> dict:
    if yaml is None:
        print("ERROR: PyYAML not installed. Run: pip install pyyaml", file=sys.stderr)
        sys.exit(1)
    if not path.exists():
        print(f"ERROR: config file not found: {path}", file=sys.stderr)
        sys.exit(1)
    data = yaml.safe_load(path.read_text(encoding="utf-8"))
    if not isinstance(data, dict):
        print(f"ERROR: {path} did not parse to a mapping", file=sys.stderr)
        sys.exit(1)
    return data


def load(path=DEFAULT_CONFIG_PATH) -> Config:
    """Load and parse engineering.yaml."""
    p = Path(path)
    data = _load_raw(p)
    return Config(
        project=ProjectConfig(**data.get("project", {})),
        filesize=FilesizeConfig(**data.get("filesize", {})),
        complexity=ComplexityConfig(**data.get("complexity", {})),
        architecture=ArchitectureConfig(**data.get("architecture", {})),
        directory_fanout=DirectoryFanoutConfig(**data.get("directory_fanout", {})),
        root_policy=RootPolicyConfig(**data.get("root_policy", {})),
        coverage_targets=data.get("coverage", {}).get("targets", {}),
        build=BuildConfig(**data.get("build", {})),
        skills_dir=data.get("skills", {}).get("dir", "docs/skills"),
        b6_1b_gates=B61bGatesConfig(**data.get("b6_1b_gates", {})),
        path=p,
    )


_cached: Optional[Config] = None


def get_config() -> Config:
    global _cached
    if _cached is None:
        _cached = load()
    return _cached


def reset_cache() -> None:
    global _cached
    _cached = None
