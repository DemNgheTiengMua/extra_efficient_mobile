"""Re-capture the PATH-surface fixtures verbatim from the running backend.

The empty-path and no-goal fixtures come from the demo learner, which has never
had a path or a goal. The populated path fixture needs an account that has been
through the honest sequence (goal -> generate), so this creates a throwaway one
rather than mutating the demo accounts.

Usage: python test/contract/record_path.py
Requires the docker backend on http://localhost:5001.
"""
import json
import urllib.error
import urllib.request

BASE = "http://localhost:5001"
PROBE = {"fullName": "Path Probe", "email": "path.probe.recorder@demo.local",
         "phone": None, "password": "Demo1234!", "termsAccepted": True}


def call(method, path, payload=None, token=None):
    headers = {"Content-Type": "application/json"}
    if token:
        headers["Authorization"] = f"Bearer {token}"
    body = json.dumps(payload).encode() if payload is not None else None
    request = urllib.request.Request(BASE + path, data=body, headers=headers, method=method)
    try:
        with urllib.request.urlopen(request) as response:
            return response.status, response.read().decode()
    except urllib.error.HTTPError as error:
        return error.code, error.read().decode()


def write(name, text):
    # Re-indent so the fixture diffs readably, without touching its values.
    text = json.dumps(json.loads(text), indent=2, ensure_ascii=False)
    with open(f"test/contract/fixtures/{name}", "w", encoding="utf-8", newline="\n") as handle:
        handle.write(text + "\n")
    print(f"recorded {name}")


def main():
    demo = json.loads(call("POST", "/api/auth/sign-in",
                           {"email": "learner@demo.local", "password": "Demo1234!"})[1])["token"]
    write("learner_target_band_empty.json", call("GET", "/api/learner/target-band", token=demo)[1])
    write("learner_learning_path_generate_no_goal.json",
          call("POST", "/api/learner/learning-path/generate", {}, token=demo)[1])

    # A fresh account has no path; its 422 above is the state the screen gates on.
    call("POST", "/api/auth/register", PROBE)
    token = json.loads(call("POST", "/api/auth/sign-in",
                            {"email": PROBE["email"], "password": PROBE["password"]})[1])["token"]

    # The honest sequence: a target band, then generation.
    call("POST", "/api/learner/goal",
         {"currentBandCode": "below_A1", "targetBandCode": "B2",
          "targetDate": None, "weeklyStudyHours": None}, token=token)
    write("learner_target_band_goal.json", call("GET", "/api/learner/target-band", token=token)[1])
    write("learner_learning_path_active.json",
          call("POST", "/api/learner/learning-path/generate", {}, token=token)[1])

    write("learner_learning_path_step_start.json",
          call("POST", "/api/learner/learning-path/steps/1/start", token=token)[1])
    write("learner_learning_path_step_not_found.json",
          call("POST", "/api/learner/learning-path/steps/999/start", token=token)[1])


if __name__ == "__main__":
    main()
