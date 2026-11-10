"""Serve the landing site locally with browser-safe module MIME types."""

from __future__ import annotations

import argparse
import csv
import http.server
import io
import json
import mimetypes
import posixpath
import re
import secrets
import subprocess
import threading
import time
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
    research_content: dict = {}
    research_records: dict[str, dict] = {}
    research_lock = threading.Lock()

    def log_message(self, format: str, *args) -> None:
        # Godot issues many range requests; suppress per-request noise so a
        # long-running preview cannot block on a full captured output pipe.
        return

    def study_state(self, record: dict) -> dict:
        completed = record["completedNodes"]
        node_ids = [node["id"] for node in self.research_content["nodes"]]
        current = next((node for node in node_ids if node not in completed), None)
        if record["routeArm"] == "field_gameplay" and current != "baseline":
            current = record.get("unlockedNode") if record.get("unlockedNode") not in completed else None
        forms = self.research_content["forms"].get(current, []) if current else []
        questions = forms[0]["questions"] if forms else []
        return {
            "participantId": record["participantId"],
            "language": record["language"],
            "routeArm": record["routeArm"] if completed else None,
            "currentNode": current,
            "completedNodes": completed,
            "deferCounts": record["deferCounts"],
            "lateResponseCount": 0,
            "crossExposed": False,
            "withdrawn": record["withdrawn"],
            "questions": questions,
            "rewardOffer": None,
        }

    def json_response(self, payload: dict, status: int = 200) -> None:
        data = json.dumps(payload, ensure_ascii=False).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def read_json(self) -> dict:
        length = min(int(self.headers.get("Content-Length", "0") or 0), 100_000)
        return json.loads(self.rfile.read(length).decode("utf-8") or "{}")

    def authenticated_record(self, body: dict) -> dict | None:
        record = self.research_records.get(str(body.get("participantId", "")))
        if not record or record["token"] != str(body.get("token", "")):
            return None
        return record

    def do_POST(self) -> None:
        path = urlsplit(self.path).path
        if not path.startswith("/api/research/"):
            self.json_response({"message": "Preview API route not found."}, 404)
            return
        try:
            body = self.read_json()
        except (ValueError, UnicodeDecodeError):
            self.json_response({"message": "Invalid JSON."}, 400)
            return

        with self.research_lock:
            if path == "/api/research/enroll":
                route = str(body.get("routeArm", ""))
                if route not in {"archive_text", "field_gameplay"}:
                    self.json_response({"message": "Choose a valid research route."}, 400)
                    return
                participant_id = f"RSP-LOCAL-{secrets.token_hex(6).upper()}"
                record = {
                    "participantId": participant_id,
                    "token": secrets.token_urlsafe(24),
                    "language": "zh" if body.get("language") == "zh" else "en",
                    "routeArm": route,
                    "completedNodes": [],
                    "deferCounts": {},
                    "withdrawn": False,
                    "unlockedNode": "baseline",
                    "responses": [],
                    "events": [{"type": "enrolled", "payload": {"routeArm": route}, "createdAt": int(time.time())}],
                    "createdAt": int(time.time()),
                }
                self.research_records[participant_id] = record
                self.json_response({"participantId": participant_id, "token": record["token"], "state": self.study_state(record)}, 201)
                return

            record = self.authenticated_record(body)
            if not record:
                self.json_response({"message": "Research session not found.", "error": "invalid_research_session"}, 401)
                return
            if path == "/api/research/session":
                self.json_response({"state": self.study_state(record)})
                return
            if path == "/api/research/checkpoint":
                level = int(body.get("level", 0) or 0)
                node = next((item for item in self.research_content["nodes"] if item["afterLevel"] == level), None)
                if not node:
                    self.json_response({"message": "Invalid checkpoint."}, 400)
                    return
                record["unlockedNode"] = node["id"]
                record["events"].append({"type": "gameplay_checkpoint", "payload": {"level": level, "nodeId": node["id"]}, "createdAt": int(time.time())})
                self.json_response({"state": self.study_state(record), "checkpoint": {"level": level, "nodeId": node["id"]}})
                return
            if path == "/api/research/submit":
                node_id = str(body.get("nodeId", ""))
                if node_id in record["completedNodes"]:
                    self.json_response({"message": "This questionnaire was already submitted."}, 409)
                    return
                forms = self.research_content["forms"].get(node_id, [])
                if not forms:
                    self.json_response({"message": "Questionnaire is unavailable."}, 409)
                    return
                form = forms[0]
                answers = body.get("answers") if isinstance(body.get("answers"), dict) else {}
                score = sum(1 for question in form["questions"] if answers.get(question["id"]) == question["correctOptionId"])
                now = int(time.time())
                record["responses"].append({"nodeId": node_id, "questionFormId": form["id"], "answers": answers, "score": score, "maxScore": len(form["questions"]), "durationSeconds": int(body.get("durationSeconds", 0) or 0), "createdAt": now})
                record["completedNodes"].append(node_id)
                record["unlockedNode"] = None
                record["events"].append({"type": "questionnaire_completed", "payload": {"nodeId": node_id, "score": score}, "createdAt": now})
                self.json_response({"state": self.study_state(record), "feedback": {"nodeId": node_id, "score": score, "maxScore": len(form["questions"])}, "rewardOffer": None})
                return
            if path == "/api/research/defer":
                node_id = str(body.get("nodeId", ""))
                record["deferCounts"][node_id] = record["deferCounts"].get(node_id, 0) + 1
                record["events"].append({"type": "questionnaire_deferred", "payload": {"nodeId": node_id}, "createdAt": int(time.time())})
                self.json_response({"state": self.study_state(record), "deferCount": record["deferCounts"][node_id]})
                return
            if path == "/api/research/skip":
                node_id = str(body.get("nodeId", ""))
                if record["routeArm"] != "field_gameplay":
                    self.json_response({"message": "Questionnaires cannot be skipped on this research route."}, 409)
                    return
                existing = next((event for event in record["events"] if event["type"] == "questionnaire_skipped" and event["payload"].get("nodeId") == node_id), None)
                if existing:
                    self.json_response({"state": self.study_state(record), "skippedNode": node_id})
                    return
                if self.study_state(record)["currentNode"] != node_id:
                    self.json_response({"message": "That research node is not available."}, 409)
                    return
                record["completedNodes"].append(node_id)
                record["unlockedNode"] = None
                record["events"].append({"type": "questionnaire_skipped", "payload": {"nodeId": node_id}, "createdAt": int(time.time())})
                self.json_response({"state": self.study_state(record), "skippedNode": node_id})
                return
            if path == "/api/research/withdraw":
                record["withdrawn"] = True
                record["events"].append({"type": "withdrawn", "payload": {}, "createdAt": int(time.time())})
                self.json_response({"state": self.study_state(record)})
                return
            if path == "/api/research/exposure":
                self.json_response({"state": self.study_state(record)})
                return
            if path == "/api/research/reward/choose":
                self.json_response({"bundleId": str(body.get("bundleId", "")), "receiptToken": f"local-{secrets.token_hex(8)}", "prestigeLevel": len(record["responses"])})
                return
        self.json_response({"message": "Preview API route not found."}, 404)

    def do_GET(self) -> None:
        path = urlsplit(self.path).path
        if path == "/api/auth/session":
            self.json_response({"user": None})
            return
        if path == "/favicon.ico":
            self.send_response(204)
            self.end_headers()
            return
        if path == "/api/admin/feedback":
            self.json_response({"ok": True, "feedback": []})
            return
        if path == "/api/admin/research/summary":
            records = list(self.research_records.values())
            route_counts = {route: sum(1 for record in records if record["routeArm"] == route) for route in ("archive_text", "field_gameplay")}
            responses = [response for record in records for response in record["responses"]]
            skipped_events = sum(1 for record in records for event in record["events"] if event["type"] == "questionnaire_skipped")
            completed = sum(1 for record in records if len(record["completedNodes"]) == 6)
            incomplete = sum(1 for record in records if len(record["completedNodes"]) < 6 and not record["withdrawn"])
            withdrawn = sum(1 for record in records if record["withdrawn"])
            option_distributions = {}
            question_labels = {}
            option_labels = {}
            for response in responses:
                form = next(form for form in self.research_content["forms"][response["nodeId"]] if form["id"] == response["questionFormId"])
                for question in form["questions"]:
                    selected_id = response["answers"].get(question["id"], "")
                    selected = next((option for option in question["options"] if option["id"] == selected_id), {})
                    option_distributions.setdefault(question["id"], {})[selected_id] = option_distributions.setdefault(question["id"], {}).get(selected_id, 0) + 1
                    question_labels.setdefault(question["id"], question["prompt"]["en"])
                    option_labels.setdefault(question["id"], {})[selected_id] = selected.get("en", selected_id)
            self.json_response({"ok": True, "summary": {"totalParticipants": len(records), "routeCounts": route_counts, "languageCounts": {language: sum(1 for record in records if record["language"] == language) for language in ("en", "zh")}, "completed": completed, "incomplete": incomplete, "withdrawn": withdrawn, "incompleteRate": incomplete / len(records) if records else 0, "withdrawalRate": withdrawn / len(records) if records else 0, "routeCompletionRates": {route: (sum(1 for record in records if record["routeArm"] == route and len(record["completedNodes"]) == 6) / route_counts[route]) if route_counts[route] else 0 for route in route_counts}, "nodeSubmissions": {node["id"]: sum(1 for response in responses if response["nodeId"] == node["id"]) for node in self.research_content["nodes"]}, "averageScore": (sum(response["score"] for response in responses) / sum(response["maxScore"] for response in responses)) if responses else 0, "averageDurationSeconds": (sum(response["durationSeconds"] for response in responses) / len(responses)) if responses else 0, "deferredEvents": sum(sum(record["deferCounts"].values()) for record in records), "skippedEvents": skipped_events, "skipRate": skipped_events / (len(responses) + skipped_events) if responses or skipped_events else 0, "lateResponses": 0, "optionDistributions": option_distributions, "questionLabels": question_labels, "optionLabels": option_labels}})
            return
        if path == "/api/admin/research/participants":
            self.json_response({"ok": True, "participants": [{"participantId": record["participantId"], "language": record["language"], "routeArm": record["routeArm"], "currentNode": self.study_state(record)["currentNode"], "completedNodes": record["completedNodes"], "deferCounts": record["deferCounts"], "withdrawn": record["withdrawn"], "complete": len(record["completedNodes"]) == 6, "responseCount": len(record["responses"]), "totalScore": sum(item["score"] for item in record["responses"]), "maxScore": sum(item["maxScore"] for item in record["responses"]), "totalDurationSeconds": sum(item["durationSeconds"] for item in record["responses"]), "createdAt": record["createdAt"], "updatedAt": int(time.time())} for record in self.research_records.values()]})
            return
        participant_match = re.fullmatch(r"/api/admin/research/participants/([^/]+)", path)
        if participant_match:
            record = self.research_records.get(unquote(participant_match.group(1)))
            if not record:
                self.json_response({"message": "Research participant not found."}, 404)
                return
            response_rows = []
            for response in record["responses"]:
                form = next(form for form in self.research_content["forms"][response["nodeId"]] if form["id"] == response["questionFormId"])
                answers = []
                for question in form["questions"]:
                    selected_id = response["answers"].get(question["id"], "")
                    selected = next((option for option in question["options"] if option["id"] == selected_id), {})
                    correct = next(option for option in question["options"] if option["id"] == question["correctOptionId"])
                    language = record["language"]
                    answers.append({"questionId": question["id"], "prompt": question["prompt"].get(language, question["prompt"]["en"]), "selectedAnswer": selected.get(language, selected.get("en", "")), "correctAnswer": correct.get(language, correct["en"]), "correct": selected_id == question["correctOptionId"]})
                response_rows.append({**response, "answers": answers, "lateResponse": False})
            self.json_response({"ok": True, "participant": {"participantId": record["participantId"], "language": record["language"], "routeArm": record["routeArm"], "currentNode": self.study_state(record)["currentNode"], "completedNodes": record["completedNodes"], "deferCounts": record["deferCounts"], "withdrawn": record["withdrawn"], "complete": len(record["completedNodes"]) == 6, "createdAt": record["createdAt"], "updatedAt": int(time.time())}, "responses": response_rows, "events": record["events"]})
            return
        if path == "/api/admin/research/export.csv":
            output = io.StringIO()
            writer = csv.writer(output)
            writer.writerow(["participant_id", "route_arm", "node_id", "after_level", "question_version", "question_id", "question", "selected_answer", "correct_answer", "is_correct", "node_score", "total_score", "duration_seconds", "submitted_at", "is_skipped", "late_submission", "study_complete"])
            level_by_node = {node["id"]: node["afterLevel"] for node in self.research_content["nodes"]}
            for record in self.research_records.values():
                total_score = sum(response["score"] for response in record["responses"])
                for response in record["responses"]:
                    form = next(form for form in self.research_content["forms"][response["nodeId"]] if form["id"] == response["questionFormId"])
                    for question in form["questions"]:
                        selected_id = response["answers"].get(question["id"], "")
                        language = record["language"]
                        selected = next((option for option in question["options"] if option["id"] == selected_id), {})
                        correct = next(option for option in question["options"] if option["id"] == question["correctOptionId"])
                        writer.writerow([record["participantId"], record["routeArm"], response["nodeId"], level_by_node.get(response["nodeId"], ""), response["questionFormId"], question["id"], question["prompt"].get(language, question["prompt"]["en"]), selected.get(language, selected.get("en", "")), correct.get(language, correct["en"]), int(selected_id == question["correctOptionId"]), response["score"], total_score, response["durationSeconds"], response["createdAt"], 0, 0, int(len(record["completedNodes"]) == 6)])
                for event in record["events"]:
                    if event["type"] != "questionnaire_skipped":
                        continue
                    node_id = event["payload"].get("nodeId", "")
                    writer.writerow([record["participantId"], record["routeArm"], node_id, level_by_node.get(node_id, ""), self.research_content.get("version", "local-preview"), "", "", "", "", "", "", total_score, "", event["createdAt"], 1, 0, int(len(record["completedNodes"]) == 6)])
            data = ("\ufeff" + output.getvalue()).encode("utf-8")
            self.send_response(200)
            self.send_header("Content-Type", "text/csv; charset=utf-8")
            self.send_header("Content-Disposition", "attachment; filename=pixel-observatory-research-preview.csv")
            self.send_header("Content-Length", str(len(data)))
            self.end_headers()
            self.wfile.write(data)
            return
        return super().do_GET()

    def translate_path(self, path: str) -> str:
        request_path = urlsplit(path).path.rstrip("/")
        if request_path in {"/study", "/study/text", "/study/game"}:
            return str(self.landing_root / "study" / "index.html")
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
    node_script = """import('./web/landing/study/research-content.mjs').then(({RESEARCH_NODES,QUESTION_FORMS}) => console.log(JSON.stringify({nodes:RESEARCH_NODES,forms:QUESTION_FORMS})))"""
    content_process = subprocess.run(
        ["node", "--input-type=module", "-e", node_script],
        cwd=landing_root.parents[1],
        check=True,
        capture_output=True,
        text=True,
        encoding="utf-8",
    )
    PreviewHandler.research_content = json.loads(content_process.stdout)

    with http.server.ThreadingHTTPServer((args.host, args.port), PreviewHandler) as server:
        print(f"Study preview: http://{args.host}:{args.port}/study/", flush=True)
        print(f"Text route: http://{args.host}:{args.port}/study/text/", flush=True)
        print(f"Game route: http://{args.host}:{args.port}/study/game/", flush=True)
        print(f"Admin preview: http://{args.host}:{args.port}/admin/", flush=True)
        print(f"Godot export: {game_public_root / 'game'}", flush=True)
        server.serve_forever()


if __name__ == "__main__":
    main()
