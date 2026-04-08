import os
import shutil
import subprocess
import uuid


def _require_env(name: str) -> str:
    value = os.environ.get(name)
    if not value:
        raise RuntimeError(f"Missing required env var: {name}")
    return value


def _run(cmd: list[str]) -> None:
    subprocess.run(cmd, check=True)


def handler(event, context):
    source_region = _require_env("SOURCE_REGION")
    source_repo = _require_env("SOURCE_REPO_NAME")
    replica_region = _require_env("REPLICA_REGION")
    replica_repo = _require_env("REPLICA_REPO_NAME")

    src_url = f"codecommit::{source_region}://{source_repo}"
    dst_url = f"codecommit::{replica_region}://{replica_repo}"

    mirror_dir = f"/tmp/{uuid.uuid4().hex}.git"
    os.environ.setdefault("HOME", "/tmp")

    try:
        _run(["git", "clone", "--mirror", src_url, mirror_dir])
        _run(["git", "--git-dir", mirror_dir, "push", "--mirror", dst_url])
        return {"status": "ok"}
    finally:
        shutil.rmtree(mirror_dir, ignore_errors=True)

