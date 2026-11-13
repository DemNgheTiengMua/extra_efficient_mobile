# Manual demo flow

A scripted walkthrough of every working feature, in an order that tells a story and never
dead-ends. Read §1 before you present; it is the difference between a smooth demo and a
five-minute apology.

---

## 1. Set up (do this before the demo starts)

### 1.1 Start the backend

```powershell
Start-Process "C:\Users\Nguoi Viet Chim Tay\AppData\Local\Programs\DockerDesktop\Docker Desktop.exe"

# wait until BOTH containers report healthy
for ($i=0; $i -lt 40; $i++) {
  Start-Sleep -Seconds 4
  $s = docker inspect --format "{{.State.Health.Status}}" extra-efficiency-api-1 2>&1
  if ($s -match "healthy") { "api healthy"; break }
}
docker ps --format "{{.Names}} {{.Status}}"
```

Confirm the API answers:

```powershell
(Invoke-WebRequest http://localhost:5001/api/packages -UseBasicParsing).StatusCode   # expect 200
```

### 1.2 Start the emulator and tunnel the API

```powershell
flutter emulators --launch Pixel_8
# wait for "emulator-5554" to appear
flutter devices

adb -s emulator-5554 reverse --remove-all
adb -s emulator-5554 reverse tcp:5001 tcp:5001
adb -s emulator-5554 reverse --list        # expect: host-…. tcp:5001 tcp:5001
```

> **Why `adb reverse` and not `10.0.2.2`?** On this machine the emulator's NAT does not reach
> the Docker-published port. The APK must be built with
> `--dart-define=API_BASE_URL=http://localhost:5001` so it uses the tunnel.

### 1.3 Build and install

```powershell
flutter build apk --debug --dart-define=API_BASE_URL=http://localhost:5001
adb -s emulator-5554 install -r build\app\outputs\flutter-apk\app-debug.apk
```

Launch it from the app drawer, or:

```powershell
adb -s emulator-5554 shell monkey -p com.demnghetiengmua.eenglish.extra_efficient_mobile -c android.intent.category.LAUNCHER 1
```

> **Do not use `flutter install`** — it uninstalls and rebuilds, and the rebuild is what
> crashes Docker Desktop on this machine.

### 1.4 Accounts

| Purpose | Email | Password |
|---|---|---|
| **Rich account — use this for the demo** | `learner@demo.local` | `Demo1234!` |
| Clean slate (to show empty states) | `learner.fresh@demo.local` | `Demo1234!` |

The rich account carries: **11 credits**, 4 exam attempts (best 720), a finished + a confirmed +
a cancelled booking, 3 orders, 10 ledger rows, 2 complaints, 8 saved questions, one unfinished
writing practice, and an unfinished placement sitting. Everything below assumes it.

### 1.5 Typing into fields

`adb shell input tap` is unreliable here — the tap often lands before the widget settles, and
forui's floating toolbar covers the fields. **Type by hand in the emulator** during the demo.
If you must script it, tap the email field once, type, then press `TAB` to move to the password
field (do not tap the password field directly).

---

## 2. The demo, in order

### Act 1 — Sign in (30 s)

1. Launch the app. You land on **EXTRA EFFICIENT — SIGN IN**.
2. Enter `learner@demo.local` / `Demo1234!` and press **SIGN IN**.
3. You arrive on **PATH**.

**Say:** *"The app is certificate-aware — TOEIC, IELTS, VSTEP and two more — and everything is
scoped to the active certificate, so content and scoring can never leak between them."*

> The three secondary actions (CREATE ACCOUNT / VERIFY EMAIL / FORGOT PASSWORD) are stacked
> full-width beneath the primary button.

---

### Act 2 — PATH: where you stand and what to do next (2 min)

**On screen:** a certificate chip, a **PICK UP WHERE YOU LEFT OFF** card, a big score placard
with the band, the CEFR ladder, **GOAL & CALIBRATION**, **LEARNING PATH**, and
**SKILL MEASUREMENTS**.

1. Point at **NEXT ACTION** — it says *"Finish Respond to a written request — 0 of 2 questions
   answered"* with a **RESUME PRACTICE** button. **Press it.**
2. You land in the practice room for that unfinished session. Press **BACK** (top-left).

**Say:** *"The next action is the backend's own recommendation, not a guess in the client — the
app follows the URL the server supplies and maps it onto its own routes."*

3. Back on PATH, scroll to **SKILL MEASUREMENTS** — Listening and Reading each show a band and a
   scaled score with a **MEASURED** badge.

**Say:** *"Band and score are the measured values. The honest case matters more — let me show
you the other account later."*

> **Don't claim audio.** No media file resolves on this backend (see §4).

---

### Act 3 — PRACTICE: free drills (3 min)

Tap the **PRACTICE** tab.

**DRILLS** shows sections grouped by skill with real question counts:
`P1 3q · P2 5q · P3 3q · P4 3q · P5 9q · P6 5q · P7 5q`.

1. Press **START DRILL** on **P5 — Incomplete Sentences** (9 questions).
2. The room opens on question 1 with a progress badge, the stem, and four options.
3. Pick an option → **CHECK ANSWER**.
4. The card turns **CORRECT** or **INCORRECT**, shows the correct option, and prints the
   explanation. Press **NEXT QUESTION**.
5. On any question press **SAVE QUESTION** — the button flips to **SAVED**.
6. Press **REQUEST HINT** — the backend's hint appears in a warning panel.
7. Finish or press **BACK**.

**Say:** *"Drills are free and graded immediately by the correct option — never by AI — so a
drill never spends a credit. Pool questions have no row id, so every answer, hint and save is
addressed by the opaque handle the server assigns; that's what a `question address` is."*

8. Switch to **SAVED** — the question you saved is listed. Tap it to see explanation and options.
9. Switch to **WEAKNESS** — 5 recommendations with real text, severity and skill badges.
   Press **RESOLVE** on one: the panel flips to a **RESOLVED** badge and the button disappears.

**Say:** *"Resolve is durable — it's read back from the server, not cached locally. And a failed
resolve reports the backend's message instead of silently doing nothing."*

> The **TOPIC × CEFR** grid below the section list shows mastery per cell (`NEW / LEARN / REVIEW
> / MSTR`) and marks resting or locked cells as untappable before you can fail on them.

#### Optional: paid skill practice

Press **SPEAKING ATTEMPT** on any speaking section (`S1`–`S5`). This opens the skill-practice
catalogue — speaking has **no typed drill by design**, because a spoken answer cannot be typed.
Both catalogues show a real credit cost: *ETS TOEIC Speaking Practice Exam 1 · 1 credit*.
Starting one **spends a credit**; only do this if you intend to.

---

### Act 4 — EXAMS: placement and mocks (3 min)

Tap the **EXAMS** tab.

**MOCK EXAMS** shows two panels:

1. **PLACEMENT ASSESSMENT** — with a **RESUME** control, because this account has an unfinished
   placement sitting.
2. **MOCK EXAM CATALOG** — *ETS 2024 — Test 1*, 120 minutes, 200 questions, **1 CREDIT**.

**Demonstrate the device gate** (the fix for the original "stuck screen with no buttons"):

3. Press **RESUME** on the placement.
4. You arrive at **the preflight gate**: exam name, duration, an **AUDIO OUTPUT CHECK** and a
   **MICROPHONE CHECK**.
5. Press **TEST AUDIO OUTPUT**. On this build the backend serves no audio sample, so it reports
   the sample is unavailable and asks you to confirm you can hear — it does **not** block you.
6. Press **TEST MICROPHONE**, allow permission, then **ENTER EXAM ROOM**.
7. The room opens with a countdown clock, autosave badge, and a two-row header where **SUBMIT**
   is always reachable.
8. Press **EXIT** (top-left). You leave immediately.

**Say:** *"This is the fix. EXIT is a navigation and never waits on a backend call — previously
it tried to cancel, the cancel failed on a graded sitting, and the learner was trapped behind
controls that all failed. Deliberate CANCEL is a separate control that may report an error."*

9. Back on the hub, switch to **HISTORY & REVIEW** — 4 attempts with real statuses, scores and
   bands (best 720).
10. Open **RESULT** on a graded attempt: score placard and per-skill breakdown.
11. Open **REVIEW**: every question with its correct option and rationale.

---

### Act 5 — WALLET: credits, checkout, mentors (4 min)

Tap the **WALLET** tab.

#### Credits & orders

1. The placard shows **LEDGER BALANCE 11**, with **PURCHASED / USED / BALANCE** split out.
2. **CREDIT PACKAGES**: Starter 5 credits · **100,000 ₫**, Intensive 10 · **190,000 ₫**,
   Master 20 · **360,000 ₫**.
3. Press **BUY** on any package → **CHECKOUT PREVIEW** shows the package, its credits, and the
   **real price**.

**Say:** *"The price comes from the backend's own `price` field. This screen used to quote zero
dong because the model read a key the server never sends."*

4. Press **CREATE ORDER** — an order is created and you can open the payment gateway, or use the
   **MOCK GATEWAY** controls (**SIMULATE PAID / FAILED / CANCELLED**) to drive the states.
5. Scroll to the **LEDGER** — 10 rows with reason and note, including an
   **ADMIN GRANT** make-good. Point out that the balance on the placard equals the ledger sum,
   so the grant is visible rather than hidden.

> **One open order per account** is enforced: with an open order, checkout blocks a second one
> and surfaces the existing order instead.

#### Mentors & bookings

6. Switch to **MENTORS & BOOKINGS**.
7. The directory lists **Dr. Trần Minh Khoa** (human, 60 min, **1 credit**, ★ 5.0) and
   **AI Mentor — TOEIC Coach** (AI, no time slot needed).
8. Press **BOOK** on Dr. Trần Minh Khoa → the booking screen shows the **real price** and the
   mentor's **real available slot(s)**, selectable.
9. Select a slot, optionally type a focus area, press **CONFIRM BOOKING**. (Spends 1 credit.)
10. Under **MY BOOKINGS**, point out the existing rows:
    - a **confirmed** booking → **JOIN MEET** opens the meeting link in a browser
    - a **done** booking → no JOIN MEET, but **RATE SESSION** is offered
    - a **cancelled** booking → shown as cancelled
11. Rate the finished session: pick stars, add a review, submit. The rating and text render on
    the booking afterwards.

**Say:** *"JOIN MEET only appears for a confirmed booking that carries a link — a finished
session keeps a stale link in the seed, and we don't send you to an ended room."*

---

### Act 6 — ACCOUNT and complaints (2 min)

Tap **ACCOUNT**.

1. The certificate switcher lists all certificates; switching scopes every tab.
2. Press **EDIT** → profile screen, update your name, save.
3. Press **OPEN COMPLAINTS CENTER**. Two existing complaints are listed with type, status and
   reason.
4. Press the new-complaint control → **FILE COMPLAINT**:
   - **1. SELECT SUBJECT** lists every eligible booking, attempt and order — each with its own
     mentor name / exam title / order code and date, so two orders are distinguishable.
   - **2. COMPLAINT TYPE** offers only the types valid for the subject you picked.
   - **3. REASON** with a required description.
5. Submit (or press BACK without submitting — filing is real).

> This screen used to crash with a red "duplicate keys" error because every subject's
> identifier parsed as `0`.

---

### Act 7 — The honest empty state (1 min) — **the strongest slide**

1. **SIGN OUT**.
2. Sign in as `learner.fresh@demo.local` / `Demo1234!`.
3. PATH shows **no band, no score, no skill ladder** — instead the first step:
   *"Find your level"* with **START FREE PLACEMENT**.

**Say:** *"This is the case that used to lie. It printed a fabricated `<A1` band and offered a
learning path that could not be generated. Now it says what is true: you haven't been measured,
and the free placement test is step one. Zero credits, no history — nothing is invented."*

4. Note **0 CREDITS** in the header, and that WEAKNESS/SAVED show explicit empty states rather
   than blank rows.

---

## 3. Cheat sheet

| Feature | Where | Cost |
|---|---|---|
| Free placement test (first per certificate) | EXAMS → PLACEMENT ASSESSMENT | **0** |
| Placement retake | EXAMS → PLACEMENT ASSESSMENT | 5 (all skills) / 3 (L&R) |
| Mock exam | EXAMS → MOCK EXAM CATALOG | 1 |
| Section drill | PRACTICE → DRILLS → START DRILL | **0** |
| Saved questions, weakness report, insights | PRACTICE | **0** |
| Speaking / writing skill practice | PRACTICE → SPEAKING ATTEMPT | 1 |
| Mentor session | WALLET → MENTORS & BOOKINGS | 1 |
| Credit packs | WALLET → CREDITS & ORDERS | 100k / 190k / 360k ₫ |

---

## 4. What **not** to demo (and what to say instead)

These are **backend** defects, not app defects. They are documented in the repo so nobody
re-discovers them as bugs.

| Avoid | Symptom | Say instead |
|---|---|---|
| Starting drills on **W1** or **W2** | `500 UNEXPECTED` from the backend | Use **P5** or **P7**. The app reports the failure rather than spinning. |
| Starting **W3** | "No questions available" (legitimate — 0 items) | Skip it. |
| Promising audio playback | **Every** media path 404s, including the DTOs' own `audioUrls` | "The audio gate degrades to a confirmation on this seed; playback works wherever the backend serves a file." |
| Listening sections expecting sound | Same 404 | Show the question text and options instead. |
| Leaving a **speaking-practice attempt** to expire | Poisons exam history with a 500 until cancelled | Cancel it, or don't start one and walk away. |
| Resume a **speaking** attempt from NEXT ACTION | That URL (`/speaking/take/{id}`) has no screen here | The app falls back to the skill-practice catalogue deliberately. |

---

## 5. Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| "Cannot reach the server" | Docker stopped, or the tunnel was lost | Restart Docker, wait for healthy, re-run `adb reverse tcp:5001 tcp:5001` |
| `docker ps` fails | Docker Desktop's backend exited (happens after heavy Gradle builds) | Relaunch Docker Desktop and wait for `healthy` |
| EXAMS shows "Unable to load" | A skill-practice attempt expired and poisons history | Cancel the in-progress attempt: `POST /api/learner/attempts/{id}/cancel` |
| Sign-in spinner then error | App built without `--dart-define=API_BASE_URL=http://localhost:5001` | Rebuild with the define |
| Taps land on the wrong field | `adb input tap` races the widget tree | Type by hand; use `TAB` between fields |
| Screenshots look corrupt | `adb exec-out screencap` through PowerShell adds bytes | `adb shell screencap -p /sdcard/s.png` then `adb pull` |

---

## 6. Automated proof (run before or after)

```powershell
flutter analyze                                   # expect: No issues found
flutter test                                      # expect: 296/296
flutter test integration_test/app_journey_test.dart -d emulator-5554 `
  --dart-define=API_BASE_URL=http://localhost:5001 # expect: 8/8 against the live API
```

The device journey covers exactly the acts above: sign-in → PATH, all five tabs, EXAMS
catalogues + history, PRACTICE sub-tabs, WALLET packages (asserting no zero price), mentor
detail, ACCOUNT + complaints — each asserting no spinner, no raw `DioException` text and no
load error.
