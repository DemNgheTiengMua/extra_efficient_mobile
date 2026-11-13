"""Re-capture the practice-room fixtures verbatim from the running backend.

Usage: python test/contract/record_practice_room.py
Requires the docker backend on http://localhost:5001 and the demo learner.

Starts one drill (a session start abandons the previous one), records the
composite take payload, reveals one hint, answers every question so the sitting
finishes, and records one right and one wrong graded reply plus the final
summary. Values are written untouched apart from re-indentation.
"""
import json
import urllib.request

BASE = "http://localhost:5001"
EMAIL = "learner@demo.local"
PASSWORD = "Demo1234!"


def post(path, payload, token=None):
    body = json.dumps(payload).encode()
    headers = {"Content-Type": "application/json"}
    if token:
        headers["Authorization"] = f"Bearer {token}"
    req = urllib.request.Request(BASE + path, data=body, headers=headers)
    with urllib.request.urlopen(req) as resp:
        return resp.read().decode()


def get(path, token):
    req = urllib.request.Request(
        BASE + path, headers={"Authorization": f"Bearer {token}"}
    )
    with urllib.request.urlopen(req) as resp:
        return resp.read().decode()


def write(name, raw):
    text = json.dumps(json.loads(raw), indent=2, ensure_ascii=False)
    with open(f"test/contract/fixtures/{name}", "w", encoding="utf-8", newline="\n") as f:
        f.write(text + "\n")
    print(f"recorded {name}")


def main():
    token = json.loads(post("/api/auth/sign-in", {"email": EMAIL, "password": PASSWORD}))["token"]

    # Section 2 (Question-Response) has five pool items and every one carries a hint.
    session = json.loads(post("/api/learner/practice/sessions", {"sectionId": 2}, token))
    session_id = session["sessionId"]

    take_raw = get(f"/api/learner/practice/sessions/{session_id}/take", token)
    write("practice_take.json", take_raw)
    take = json.loads(take_raw)

    # The address, never the nullable questionId: a pool item has no row id.
    first = take["questions"][0]
    write(
        "practice_hint.json",
        post(
            f"/api/learner/practice/sessions/{session_id}/questions/{first['address']}/hint",
            {},
            token,
        ),
    )

    right = wrong = None
    for question in take["questions"]:
        raw = post(
            f"/api/learner/practice/sessions/{session_id}/questions/{question['address']}/answer",
            {"selectedOptionId": question["options"][0]["optionId"]},
            token,
        )
        graded = json.loads(raw)
        if graded["isCorrect"] is True and right is None:
            right = raw
        if graded["isCorrect"] is False and wrong is None:
            wrong = raw

    if right is None or wrong is None:
        raise SystemExit("the seed answered every question the same way; pick another option")

    write("practice_answer_right.json", right)
    write("practice_answer_wrong.json", wrong)
    write(
        "practice_summary.json",
        get(f"/api/learner/practice/sessions/{session_id}/summary", token),
    )


if __name__ == "__main__":
    main()
