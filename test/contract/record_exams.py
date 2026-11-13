"""Re-capture the exam-surface fixtures verbatim from the running backend.

Usage: python test/fixtures/record_exams.py
Requires the docker backend on http://localhost:5001 and the demo learner.
"""
import json
import urllib.request

BASE = "http://localhost:5001"
EMAIL = "learner@demo.local"
PASSWORD = "Demo1234!"

ENDPOINTS = {
    "placement_catalog.json": "/api/learner/placement",
    "mock_exam_list.json": "/api/learner/exams",
    "exam_history.json": "/api/learner/exams/history",
    "mock_exam_instructions.json": "/api/learner/exams/1/instructions",
    "attempt_result.json": "/api/learner/attempts/1004/result",
    "attempt_review.json": "/api/learner/attempts/1004/review",
    "placement_result.json": "/api/learner/placement/result/1",
    "placement_grading_status.json": "/api/learner/placement/result/1/status",
}


def post(path, payload):
    body = json.dumps(payload).encode()
    req = urllib.request.Request(
        BASE + path, data=body, headers={"Content-Type": "application/json"}
    )
    with urllib.request.urlopen(req) as resp:
        return json.load(resp)


def get(path, token):
    req = urllib.request.Request(
        BASE + path, headers={"Authorization": f"Bearer {token}"}
    )
    with urllib.request.urlopen(req) as resp:
        return resp.read().decode()


def main():
    token = post("/api/auth/sign-in", {"email": EMAIL, "password": PASSWORD})["token"]
    for name, path in ENDPOINTS.items():
        raw = get(path, token)
        # Re-indent so the fixture diffs readably, without touching its values.
        text = json.dumps(json.loads(raw), indent=2, ensure_ascii=False)
        with open(f"test/contract/fixtures/{name}", "w", encoding="utf-8", newline="\n") as f:
            f.write(text + "\n")
        print(f"recorded {name}")


if __name__ == "__main__":
    main()

