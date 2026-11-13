# Flutter Client Stack and Exam-Hall Signage Theme

Status: accepted

The mobile learner app uses `flutter_riverpod` for state management and dependency injection, `dio` with a Bearer-token interceptor for HTTP, `flutter_secure_storage` for JWT persistence, `go_router` for declarative routing, and `forui` as the component foundation. All `forui` and custom widgets are locked to the "Bảng hiệu phòng thi" (exam-hall signage) aesthetic from `docs/backend-ref/DESIGN.md`: `BorderRadius.zero` everywhere, zero elevation/shadows, 2px solid Ink (`#14181d`) structural keylines, 1px soft (`#ccd2d6`) interior dividers, solid Ink inversion for active/selected states, and self-hosted IBM Plex Sans / Sans Condensed / Mono (`tabularFigures`) typography. Agents implementing or modifying any UI, theme, style delta, controller, or widget MUST consult `docs/backend-ref/forui-llms.txt` and `docs/backend-ref/forui-llms-full.txt` rather than guessing `forui` APIs.
