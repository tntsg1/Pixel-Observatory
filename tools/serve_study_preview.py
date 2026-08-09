"""Serve the landing site locally with browser-safe module MIME types."""

from __future__ import annotations

import argparse
import http.server
import mimetypes
import posixpath
import re
from pathlib import Path
from urllib.parse import unquote, urlsplit


def safe_path(root: Path, request_path: str) -> Path:
    normalized = posixpath.normpath(unquote(urlsplit(request_path).path))
    parts = [part for part in normalized.split("/") if part not in {"", ".", ".."}]
    return root.joinpath(*parts)


class PreviewHandler(http.server.SimpleHTTPRequestHandler):
    landing_root: Path
    game_public_root: Path
    byte_range: tuple[int, int] | None = None

    def translate_path(self, path: str) -> str:
        landing_candidate = safe_path(self.landing_root, path)
        if landing_candidate.exists():
            return str(landing_candidate)
        return str(safe_path(self.game_public_root, path))

    def send_head(self):
        range_header = self.headers.get("Range")
        if not range_header:
            self.byte_range = None
            return super().send_head()

        path = Path(self.translate_path(self.path))
        if not path.is_file():
            self.send_error(404, "File not found")
            return None

        match = re.fullmatch(r"bytes=(\d*)-(\d*)", range_header.strip())
        if not match or (not match.group(1) and not match.group(2)):
            self.send_error(416, "Invalid byte range")
            return None

        size = path.stat().st_size
        if match.group(1):
            start = int(match.group(1))
            end = int(match.group(2)) if match.group(2) else size - 1
        else:
            suffix_length = int(match.group(2))
            start = max(0, size - suffix_length)
            end = size - 1

        if start >= size or start > end:
            self.send_response(416)
            self.send_header("Content-Range", f"bytes */{size}")
            self.end_headers()
            return None

        end = min(end, size - 1)
        self.byte_range = (start, end)
        stream = path.open("rb")
        self.send_response(206)
        self.send_header("Content-type", self.guess_type(str(path)))
        self.send_header("Content-Range", f"bytes {start}-{end}/{size}")
        self.send_header("Content-Length", str(end - start + 1))
        self.send_header("Last-Modified", self.date_time_string(path.stat().st_mtime))
        self.end_headers()
        return stream

    def copyfile(self, source, outputfile) -> None:
        if self.byte_range is None:
            return super().copyfile(source, outputfile)

        start, end = self.byte_range
        source.seek(start)
        remaining = end - start + 1
        while remaining:
            chunk = source.read(min(1024 * 1024, remaining))
            if not chunk:
                break
            outputfile.write(chunk)
            remaining -= len(chunk)

    def end_headers(self) -> None:
        self.send_header("Accept-Ranges", "bytes")
        self.send_header("Cross-Origin-Opener-Policy", "same-origin")
        self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
        self.send_header("Cross-Origin-Resource-Policy", "cross-origin")
        super().end_headers()


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=8766)
    parser.add_argument("--game-public-root", type=Path)
    args = parser.parse_args()

    landing_root = Path(__file__).resolve().parents[1] / "web" / "landing"
    game_public_root = args.game_public_root
    if game_public_root is None:
        game_public_root = landing_root.parents[2] / "ai-game-0628" / "build" / "web"
    game_public_root = game_public_root.resolve()
    if not (game_public_root / "game" / "index.html").is_file():
        parser.error(f"Godot web export not found under {game_public_root}")

    mimetypes.add_type("text/javascript", ".mjs")
    mimetypes.add_type("application/wasm", ".wasm")
    mimetypes.add_type("application/octet-stream", ".pck")
    PreviewHandler.landing_root = landing_root
    PreviewHandler.game_public_root = game_public_root

    with http.server.ThreadingHTTPServer((args.host, args.port), PreviewHandler) as server:
        print(f"Study preview: http://{args.host}:{args.port}/study/", flush=True)
        print(f"Godot export: {game_public_root / 'game'}", flush=True)
        server.serve_forever()


if __name__ == "__main__":
    main()
