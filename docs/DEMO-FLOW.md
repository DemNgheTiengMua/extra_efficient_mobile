# Manual test guide — post-fix (fresh seed)

Rewritten against a **freshly reseeded database** after the three backend defects were fixed.
Every number, path and claim below was verified against the running stack at the time of writing.

---

## Demo readiness: **yes, with three caveats**

What changed since the previous guide:

| Was broken | Now | Verified |
|---|---|---|
| `GET /exams/history` 500'd forever once a skill-practice attempt expired | **200 on every read**, with an expired skill-practice attempt present | yes |
| W1 / W2 drill start → **500** | **200**, and each holds exactly one copy of its shared item | yes |
| Every media path 404'd | **All published paths serve**: `/audio/**`, `/img/**` with correct content-type | yes |

**Three caveats, all honest:**

1. **No account has skill measurements or a placement.** Both seeded accounts have
   `skill_states = 0` and `placements = 0`. So PATH shows **no band, no score placard, no skill
   ladder** — the "honest first step" state — for *both* accounts. You cannot demo a populated
   PATH or a real placement result without taking the placement first.
2. **`hasNoMeasurement: true` coexists with `currentScore: 720`.** `goal.currentBandCode` is `B1`
   and `currentScore` is `720` (the seed's best mock), yet `hasNoMeasurement` is true and every
   skill is unmeasured. The app keys on `hasNoMeasurement`, so it renders the first-step card and
   never prints "B1 / 720". That is the safe behaviour, but the payload disagrees with itself —
   worth raising with the backend owner.
3. **The demo account now has 13 credits and 2 attempts**, not the 11 / 4 the old script assumed.
   Those older numbers came from an accumulated database, not the seed.

---

## 1. Setup

### 1.1 Start the stack

```powershell
cd "D:\Study\PRN3\Project\extra_efficiency_ui"
docker compose up -d
docker compose logs -f db-init        # watch: loading schema -> loading demo seed -> done
```

Wait for `db-init` to exit 0 and for `api` to report healthy:

```powershell
docker compose ps
```

> **Reseeding:** `docker compose down -v && docker compose up -d`. Stop/start does **not** reseed —
> `db-init` sees the `DerivedFactOwners` table and refuses (`"...is already loaded - not touching it"`).
> `-v` is the only thing that resets. It also discards the `api-audio` volume (recordings).

> **Your backend fixes are uncommitted.** `up -d` rebuilds the API image from the working tree, so
> the fixes stay live. Commit or stash them *before* reseeding and the old code returns.

### 1.2 Emulator and API tunnel

```powershell
flutter devices                                  # expect emulator-5554
adb -s emulator-5554 reverse --remove-all
adb -s emulator-5554 reverse tcp:5001 tcp:5001
adb -s emulator-5554 reverse --list               # expect tcp:5001 tcp:5001
```

### 1.3 Build and install

```powershell
cd "D:\Study\PRM_Android\Projects\extra_efficient_mobile"
flutter build apk --debug --dart-define=API_BASE_URL=http://localhost:5001
adb -s emulator-5554 install -r build\app\outputs\flutter-apk\app-debug.apk
```

`--dart-define` is **not optional**: without it the app targets `10.0.2.2`, which does not reach
the Docker-published port on this machine, and every screen reports "Cannot reach the server".
Do **not** use `flutter install` — its rebuild is what crashes Docker Desktop here.

### 1.4 Accounts

| Purpose | Email | Password | Credits |
|---|---|---|---|
| Main demo account | `learner@demo.local` | `Demo1234!` | **13** |
| Empty-state account | `learner.fresh@demo.local` | `Demo1234!` | **0** |

Fresh-seed state of the main account:

- **13 credits**, 2 exam attempts (both scored, best **720**), 2 orders, 6 ledger rows
- 2 complaints; 2 eligible bookings, 2 eligible attempts, 2 eligible orders
- **2 saved questions**
- **No placements, no skill measurements** — PATH is the first-step state
- One unfinished practice session: **P5 — Incomplete Sentences, 0 of 9 answered**
- Bookings: **1 confirmed**, **1 done**
- 1 open mentor slot
- Learning path: **not created**

### 1.5 Typing into fields

Type by hand in the emulator. `adb shell input tap` races the widget tree, and forui's floating
toolbar covers the fields. If you must script it: tap the email field once, type, then press
**TAB** to reach the password field — do not tap it.

---

## 2. The demo, in order

### Act 1 — Sign in (30 s)

Sign in as `learner@demo.local`. You land on **PATH**.

**Say:** *"Certificate-aware — TOEIC, IELTS, VSTEP and two more — and every tab is scoped to the
active certificate, so content and scoring cannot leak between them."*

---

### Act 2 — PATH: the honest empty state (2 min)

What you see: the certificate chip, **PICK UP WHERE YOU LEFT OFF** (P5, 0 of 9), and the first-step
card. **No band, no score placard, no skill ladder.**

This is correct for a fresh seed — nothing has been measured yet.

1. Point at **RESUME PRACTICE** and press it → the P5 practice room opens on question 1.
2. Press **BACK**.

**Say:** *"This account has a mock score but no measured skills — the two are different facts.
The app refuses to print a band it cannot stand behind, and instead says what is actually true:
you haven't been measured, and the free placement is step one. This is the bug that used to lie —
it fabricated a `<A1` band and offered a learning path that could not be generated."*

3. **GOAL & CALIBRATION** — the target-band picker offers the certificate's **6 real bands** with
   their score ranges (Below A1 · 10–119 points, …). Nothing is hardcoded.
4. **LEARNING PATH** — no path exists, so it offers generation, and says a target band is needed
   first. Press nothing; just show that it does not present an empty module shell.

---

### Act 3 — PRACTICE: free drills, now with working audio (4 min)

Tap **PRACTICE** → **DRILLS**.

Sections with real counts, freshly seeded:
`P1 3q · P2 5q · P3 3q · P4 3q · P5 9q · P6 5q · P7 5q · W1 1q · W2 1q · W3 0q`

**P1 — Photographs is the one to demo**, because it has both audio and an image:

1. Press **START DRILL** on **P1**.
2. The room opens on question 1. Press **PLAY AUDIO** — **it plays**. This is newly working.
3. The question shows the image (`/img/part1-sample.svg`, serving 200).
4. Pick an option → **CHECK ANSWER** → correct/incorrect, the correct option, and the explanation.
5. Press **SAVE QUESTION** → button flips to **SAVED**.
6. Press **REQUEST HINT** → the backend's hint appears.

**Say:** *"Drills are free and graded by the correct option, never by AI, so a drill never spends a
credit. Audio now plays because the backend serves the paths its own payloads publish."*

7. **W1 or W2** — previously a 500. Press **START DRILL**: the session now starts. This is the
   duplicate-binding fix, visible from the UI.
8. **SAVED** sub-tab → the question you just saved, plus the 2 seeded ones. Open one for its
   explanation and options.
9. **WEAKNESS** sub-tab → honest empty state. The account has no graded practice or exam answers
   yet, so `hasData` is false and the screen says so rather than showing blank rows.

> **To make WEAKNESS non-empty**, complete a few drills first (answer a handful of questions), then
> return. That also gives the weakness report real section counts and the topic axis something to
> rank.

10. Optional: **SPEAKING ATTEMPT** → skill-practice catalogue, *ETS TOEIC Speaking Practice Exam 1
    · 1 credit*. Speaking has no typed drill by design. Starting one **spends a credit**.

---

### Act 4 — EXAMS: the device gate and the escape fix (3 min)

Tap **EXAMS**. You have **no unfinished placement**, so the placement panel offers **START FREE
PLACEMENT** rather than RESUME, and the mock catalogue lists *ETS 2024 — Test 1* (120 min, 200
questions, **1 credit**).

1. Press **HISTORY & REVIEW** → **2 attempts** with real scores and bands (best **720**).
2. Open **RESULT** on one → score placard and per-skill breakdown.
3. Open **REVIEW** → questions with correct options and rationale.
4. Back to **MOCK EXAMS** → press **INSTRUCTIONS & START** on the mock exam.

**The device gate** (the fix for "stuck screen with no buttons"):

5. You arrive at the preflight gate: exam name, duration, **AUDIO OUTPUT CHECK**, **MICROPHONE
   CHECK**.
6. Press **TEST AUDIO OUTPUT** — a real sample now exists and plays. On the devices where no
   playable sample is supplied, it degrades to an explicit confirmation rather than blocking entry.
   A genuine playback failure is reported as a failure (it used to be recorded as a pass — a real
   bug, now fixed).
7. Press **TEST MICROPHONE**, allow permission, then **ENTER EXAM ROOM**.
8. The room opens with a countdown clock, an autosave badge, and a two-row header where **SUBMIT**
   is always reachable.
9. Press **EXIT**. You leave **immediately**.

**Say:** *"EXIT is a navigation and never waits on a backend call. Previously it tried to cancel,
the cancel failed on a graded sitting, and the learner was trapped behind controls that all
failed. Deliberate CANCEL is a separate control that may report an error."*

> Starting the mock **costs 1 credit**. You have 13.

---

### Act 5 — WALLET: money, checkout, mentors (4 min)

Tap **WALLET**.

**Credits & orders**

1. Placard shows **LEDGER BALANCE 13**, split into **PURCHASED / USED / BALANCE**.
2. **CREDIT PACKAGES**: Starter 5 · **100,000 ₫**, Intensive 10 · **190,000 ₫**, Master 20 ·
   **360,000 ₫**.
3. Press **BUY** → **CHECKOUT PREVIEW** shows the package, its credits, and the **real price**.

**Say:** *"This screen used to quote zero dong because the model read a key the server never
sends."*

4. **CREATE ORDER** → then either open the payment gateway, or drive **MOCK GATEWAY**
   (**SIMULATE PAID / FAILED / CANCELLED**).
5. **LEDGER** → 6 rows with reason and note. The balance equals the ledger sum.

> **One open order per account** is enforced — with an order open, checkout blocks a second and
> surfaces the existing one.

**Mentors & bookings**

6. **MENTORS & BOOKINGS** → **Dr. Trần Minh Khoa** (human, 60 min, **1 credit**, ★ 5.0) and
   **AI Mentor — TOEIC Coach** (AI, no slot needed).
7. **BOOK** the human mentor → the screen shows the **real price** and the **real open slot**.
8. Select it, press **CONFIRM BOOKING** (spends 1 credit).
9. In **MY BOOKINGS**:
   - **confirmed** booking → **JOIN MEET** opens the link in a browser
   - **done** booking → no JOIN MEET, but **RATE SESSION** is offered
10. Rate the finished session: stars + review. It renders on the booking afterwards.

**Say:** *"JOIN MEET only appears for a confirmed booking carrying a link — a finished session
keeps a stale link in the seed, and we don't send you to an ended room."*

---

### Act 6 — ACCOUNT and complaints (2 min)

Tap **ACCOUNT**.

1. The certificate switcher lists every certificate; switching re-scopes all tabs.
2. **EDIT** → profile screen; update your name and save.
3. **OPEN COMPLAINTS CENTER** → 2 existing complaints with type, status and reason.
4. New complaint → **FILE COMPLAINT**:
   - **1. SELECT SUBJECT** — 2 bookings, 2 attempts, 2 orders, each with its own mentor name /
     exam title / order code and date, so two orders are distinguishable.
   - **2. COMPLAINT TYPE** — only types valid for the chosen subject.
   - **3. REASON** — required.
5. Submit, or press BACK without submitting.

**Say:** *"This screen used to crash with a red 'duplicate keys' error — every subject's identifier
parsed as zero."*

---

### Act 7 — Empty-state account (1 min) — the strongest close

1. **SIGN OUT**.
2. Sign in as `learner.fresh@demo.local` / `Demo1234!`.
3. PATH shows **0 CREDITS**, no band, no skills, and the first step.
4. **PRACTICE → WEAKNESS** and **SAVED** show explicit empty states, not blank rows.
5. **EXAMS** shows no history; the placement is free and unstarted.

**Say:** *"Nothing is invented. Zero credits, no history, and every screen says so in words."*

---

## 3. What costs credits

| Feature | Cost |
|---|---|
| Section drill (all P*, W1, W2) | **0** |
| Saved questions, weakness report, insights | **0** |
| First placement per certificate | **0** |
| Placement retake | 5 (all skills) / 3 (L&R) |
| Mock exam | 1 |
| Speaking / writing skill practice | 1 |
| Mentor session | 1 |

Main account starts with **13**.

---

## 4. Known limitations — say these, don't discover them live

| Situation | What happens | What to say |
|---|---|---|
| W3 drill | `404 No questions available` | Legitimate — the section has 0 active items. |
| S1–S5 sections | `400 Modality not allowed` | By design — speaking has no typed drill; use SPEAKING ATTEMPT. |
| PATH band/score | Absent on a fresh seed | Nothing is measured yet. Take the placement to populate it. |
| Weakness report | Empty until you answer questions | Complete a few drills first. |
| Placement result | Cannot be shown without sitting one | The seed has no placement rows. |
| `hasNoMeasurement` with `currentScore: 720` | App shows the first-step card | Payload inconsistency; the app takes the safe reading. |

---

## 5. Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| "Cannot reach the server" | Docker stopped, tunnel lost, or APK built without `--dart-define` | Restart Docker, re-run `adb reverse`, rebuild with the define |
| `docker compose down -v` → "no configuration file provided" | Wrong directory | `cd "D:\Study\PRN3\Project\extra_efficiency_ui"` — this session's repo is the mobile one |
| Taps land on the wrong field | `adb input tap` races the tree | Type by hand; `TAB` between fields |
| Screenshots corrupt | `adb exec-out screencap` through PowerShell | `adb shell screencap -p /sdcard/s.png` then `adb pull` |
| Reseed didn't happen | Used `down`/`restart` without `-v` | `docker compose down -v && docker compose up -d` |

---

## 6. Automated proof

```powershell
cd "D:\Study\PRM_Android\Projects\extra_efficient_mobile"
flutter analyze                                   # No issues found
flutter test                                      # 296/296
flutter test integration_test/app_journey_test.dart -d emulator-5554 `
  --dart-define=API_BASE_URL=http://localhost:5001 # 8/8 against the live API
```

The device journey covers sign-in → PATH, all five tabs, EXAMS catalogues + history, PRACTICE
sub-tabs, WALLET packages (asserting no zero price), mentor detail, ACCOUNT + complaints — each
asserting no spinner, no raw `DioException` text and no load error.

Backend regressions for the three fixes:

```powershell
cd "D:\Study\PRN3\Project\extra_efficiency_ui"
dotnet test tests/Services.Tests/Services.Tests.csproj --filter "FullyQualifiedName~AttemptEngineTests|FullyQualifiedName~PoolDrillCatalogTests"
dotnet test tests/WebAPI.Tests/WebAPI.Tests.csproj --filter "FullyQualifiedName~MediaStaticAndAliasRouteTests"
```
