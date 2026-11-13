# Graph Report - swarm-ticket-2-457c008e  (2026-11-13)

## Corpus Check
- 46 files · ~86,639 words
- Verdict: corpus is large enough that graph structure adds value.
- Unclassified: 20 file(s) not represented in the graph (top: .xml 7, .ttf 6, (none) 4)

## Summary
- 674 nodes · 887 edges · 44 communities (34 shown, 10 thin omitted)
- Extraction: 96% EXTRACTED · 4% INFERRED · 0% AMBIGUOUS · INFERRED: 35 edges (avg confidence: 0.9)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `27097cca`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- Forui Form Controls & Pickers
- Exam-Hall Signage & Client Stack
- Flutter Pubspec & Dependencies
- signage_theme.dart
- Flutter App Entrypoint & Tests
- Forui Theming & Style Deltas
- auth_provider.dart
- Learner Attempts, Scoring & Ledger
- signage_primitives.dart
- Web PWA Manifest
- Launcher & Web App Icons
- audio_media_adapter.dart
- Dart Linter & Analysis Options
- Forui CLI Configuration
- Android MainActivity Host
- Practice Sessions & Weakness Insights
- Content Ingestion & Item Lifecycle
- network_auth_interceptor_test.dart
- dio_client.dart
- token_storage.dart
- register_screen.dart
- _
- account_screen.dart
- sign_in_screen.dart
- main_shell.dart
- package:flutter_riverpod/flutter_riverpod.dart
- package:flutter/material.dart
- verify_email_screen.dart
- forgot_password_screen.dart
- Agent skills
- Language
- package:flutter_riverpod/flutter_riverpod.dart
- Issue tracker: GitHub
- Domain Docs
- FLabel & FLabelLayout
- 0001-flutter-client-stack-and-signage-theme.md
- triage-labels.md
- StatelessWidget

## God Nodes (most connected - your core abstractions)
1. `Forui Controls (State Management Abstraction)` - 24 edges
2. `_` - 18 edges
3. `FThemeData` - 15 edges
4. `authNotifierProvider` - 13 edges
5. `Exam-Hall Signage Design System (Bảng hiệu phòng thi)` - 13 edges
6. `dependencies` - 10 edges
7. `FPopover, FPopoverControl & FPopoverController` - 10 edges
8. `ADR 0001: Flutter Client Stack and Exam-Hall Signage Theme` - 9 edges
9. `Forui Full LLM Documentation (forui-llms-full.txt)` - 9 edges
10. `FTextField (email, password, multiline)` - 8 edges

## Surprising Connections (you probably didn't know these)
- `Target Backend Stack (.NET 10, EF Core, ASP.NET Core Web API, SQL Server)` --semantically_similar_to--> `Backend API (Docker localhost:5001 / 10.0.2.2:5001)`  [INFERRED] [semantically similar]
  docs/backend-ref/PRODUCT.md → AGENTS.md
- `Backend Reference Domain Context & Ubiquitous Language` --semantically_similar_to--> `Certificate`  [INFERRED] [semantically similar]
  docs/backend-ref/CONTEXT.md → GLOSSARY.md
- `Android Launcher Icon (xxxhdpi - Default Flutter Logo)` --semantically_similar_to--> `Web PWA Icon (512x512 Default Flutter Logo)`  [INFERRED] [semantically similar]
  android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png → web/icons/Icon-512.png
- `extra_efficient_mobile Flutter Project` --conceptually_related_to--> `ADR 0001: Flutter Client Stack and Exam-Hall Signage Theme`  [INFERRED]
  README.md → docs/adr/0001-flutter-client-stack-and-signage-theme.md
- `Flutter Web Entrypoint (web/index.html & flutter_bootstrap.js)` --references--> `extra_efficient_mobile Flutter Project`  [INFERRED]
  web/index.html → README.md

## Import Cycles
- None detected.

## Hyperedges (group relationships)
- **Append-Only Credit Ledger and Gateway Order Reconciliation** — glossary_credit, glossary_ledger, glossary_order, glossary_gateway, glossary_paymentevent, docs_backend_ref_product_creditmonetisation, docs_backend_ref_product_payosgateway [EXTRACTED 1.00]
- **Exam-Hall Signage UI Foundation (ADR-0001 + DESIGN.md + Forui + IBM Plex)** — docs_adr_0001_flutter_client_stack_and_signage_theme_client_stack_decision, docs_backend_ref_design_examhallsignage, docs_backend_ref_forui_llms_foruithemesanddeltas, docs_backend_ref_design_ibmplextypography, assets_fonts_ibm_plex_sans_license_sil_open_font_license [EXTRACTED 1.00]
- **Forui Control Abstraction (Lifted & Managed Controls and Controllers)** — docs_backend_ref_forui_llms_full_controls, docs_backend_ref_forui_llms_full_lifted_control, docs_backend_ref_forui_llms_full_managed_control, docs_backend_ref_forui_llms_full_custom_controllers, docs_backend_ref_forui_llms_full_forui_hooks, docs_backend_ref_forui_llms_full_faccordioncontrol, docs_backend_ref_forui_llms_full_fcalendarcontrol, docs_backend_ref_forui_llms_full_fdateselectioncontrol, docs_backend_ref_forui_llms_full_fautocompletecontrol, docs_backend_ref_forui_llms_full_fmultivaluecontrol, docs_backend_ref_forui_llms_full_fselectcontrol, docs_backend_ref_forui_llms_full_ftextfieldcontrol [EXTRACTED 1.00]
- **Forui Data Display, Accordion, Card, Item, and Tile Widget Family** — docs_backend_ref_forui_llms_full_faccordion, docs_backend_ref_forui_llms_full_faccordionitem, docs_backend_ref_forui_llms_full_fcollapsible, docs_backend_ref_forui_llms_full_favatar, docs_backend_ref_forui_llms_full_fbadge, docs_backend_ref_forui_llms_full_fcard, docs_backend_ref_forui_llms_full_fitem, docs_backend_ref_forui_llms_full_fitemgroup, docs_backend_ref_forui_llms_full_ftile, docs_backend_ref_forui_llms_full_ftilegroup, docs_backend_ref_forui_llms_full_fselecttilegroup, docs_backend_ref_forui_llms_full_fselectmenutile, docs_backend_ref_forui_llms_full_ftappable, docs_backend_ref_forui_llms_full_ffocusedoutline [EXTRACTED 1.00]
- **Forui Calendar, Date, Time, and Wheel Picker Widget Family** — docs_backend_ref_forui_llms_full_fcalendar, docs_backend_ref_forui_llms_full_flinecalendar, docs_backend_ref_forui_llms_full_fdatefield, docs_backend_ref_forui_llms_full_fdatetimepicker, docs_backend_ref_forui_llms_full_ftimefield, docs_backend_ref_forui_llms_full_ftimepicker, docs_backend_ref_forui_llms_full_fpicker [EXTRACTED 1.00]
- **Forui Form, Text Input, and Selection Widget Family** — docs_backend_ref_forui_llms_full_fbutton, docs_backend_ref_forui_llms_full_fbuttonstyle, docs_backend_ref_forui_llms_full_ftextfield, docs_backend_ref_forui_llms_full_ftextformfield, docs_backend_ref_forui_llms_full_fotpfield, docs_backend_ref_forui_llms_full_fcheckbox, docs_backend_ref_forui_llms_full_fradio, docs_backend_ref_forui_llms_full_fswitch, docs_backend_ref_forui_llms_full_flabel, docs_backend_ref_forui_llms_full_fselect, docs_backend_ref_forui_llms_full_fmultiselect, docs_backend_ref_forui_llms_full_fselectgroup, docs_backend_ref_forui_llms_full_fautocomplete, docs_backend_ref_forui_llms_full_fslider [EXTRACTED 1.00]
- **Forui App Shell, Layout, and Navigation Widget Family** — docs_backend_ref_forui_llms_full_fscaffold, docs_backend_ref_forui_llms_full_fheader, docs_backend_ref_forui_llms_full_fbottomnavigationbar, docs_backend_ref_forui_llms_full_fsidebar, docs_backend_ref_forui_llms_full_ftabs, docs_backend_ref_forui_llms_full_fbreadcrumb, docs_backend_ref_forui_llms_full_fpagination, docs_backend_ref_forui_llms_full_fresizable, docs_backend_ref_forui_llms_full_fdivider [EXTRACTED 1.00]
- **Forui Portal, Overlay, Dialog, Sheet, Menu, Toast, and Progress Widgets** — docs_backend_ref_forui_llms_full_foverlay, docs_backend_ref_forui_llms_full_fportal, docs_backend_ref_forui_llms_full_fpointportal, docs_backend_ref_forui_llms_full_fpopover, docs_backend_ref_forui_llms_full_fpopovermenu, docs_backend_ref_forui_llms_full_fcontextmenu, docs_backend_ref_forui_llms_full_fdialog, docs_backend_ref_forui_llms_full_fsheet, docs_backend_ref_forui_llms_full_fpersistentsheet, docs_backend_ref_forui_llms_full_ftoast, docs_backend_ref_forui_llms_full_ftooltip, docs_backend_ref_forui_llms_full_falert, docs_backend_ref_forui_llms_full_fprogress, docs_backend_ref_forui_llms_full_fdeterminateprogress, docs_backend_ref_forui_llms_full_fcircularprogress [EXTRACTED 1.00]
- **Forui Theme, Variant, and Style Delta Architecture** — docs_backend_ref_forui_llms_full_ftheme, docs_backend_ref_forui_llms_full_fthemedata, docs_backend_ref_forui_llms_full_fcolors, docs_backend_ref_forui_llms_full_ftypography, docs_backend_ref_forui_llms_full_fstyle, docs_backend_ref_forui_llms_full_fhapticfeedback, docs_backend_ref_forui_llms_full_fvariants, docs_backend_ref_forui_llms_full_fplatformvariant, docs_backend_ref_forui_llms_full_fbreakpoints, docs_backend_ref_forui_llms_full_ficons, docs_backend_ref_forui_llms_full_style_deltas, docs_backend_ref_forui_llms_full_theme_extensions, docs_backend_ref_forui_llms_full_material_interop, docs_backend_ref_forui_llms_full_customizing_themes [EXTRACTED 1.00]
- **Learner Diagnostic Placement, Scoring, and Guided Learning Path Flow** — glossary_certificate, glossary_placementattempt, glossary_scaledscore, glossary_band, glossary_learningpath, glossary_practicesession, glossary_weaknessanalysis [EXTRACTED 1.00]
- **Android Multi-Density Mipmap Launcher Icons** — android_app_src_main_res_mipmap_mdpi_ic_launcher_flutter_launcher_icon, android_app_src_main_res_mipmap_hdpi_ic_launcher_flutter_launcher_icon, android_app_src_main_res_mipmap_xhdpi_ic_launcher_flutter_launcher_icon, android_app_src_main_res_mipmap_xxhdpi_ic_launcher_flutter_launcher_icon, android_app_src_main_res_mipmap_xxxhdpi_ic_launcher_flutter_launcher_icon [INFERRED 0.95]
- **Web Favicon and PWA Manifest Icons** — web_favicon_flutter_favicon, web_icons_icon_192_flutter_web_icon, web_icons_icon_512_flutter_web_icon, web_icons_icon_maskable_192_flutter_maskable_icon, web_icons_icon_maskable_512_flutter_maskable_icon [INFERRED 0.95]

## Communities (44 total, 10 thin omitted)

### Community 0 - "Forui Form Controls & Pickers"
Cohesion: 0.06
Nodes (60): Forui Controls (State Management Abstraction), FAutocomplete & FAutocompleteSection, FAutocompleteControl & FAutocompleteController, FAvatar, FBottomNavigationBar & FBottomNavigationBarItem, FBreadcrumb & FBreadcrumbItem, FButton (primary, secondary, outline, destructive, ghost, link, icon, raw), FButtonStyle, FButtonVariant & FButtonSizeVariant (+52 more)

### Community 1 - "Exam-Hall Signage & Client Stack"
Cohesion: 0.05
Nodes (33): Backend API (Docker localhost:5001 / 10.0.2.2:5001), JWT Bearer Auth (POST /api/auth/sign-in), SIL Open Font License 1.1 (IBM Plex), dio HTTP Client with Bearer Interceptor, go_router Declarative Routing, flutter_riverpod State Management & DI, flutter_secure_storage JWT Persistence, GitHub Issue Tracker & CLI Conventions (+25 more)

### Community 2 - "Flutter Pubspec & Dependencies"
Cohesion: 0.06
Nodes (30): dependencies, cupertino_icons, dio, flutter, flutter_riverpod, flutter_secure_storage, forui, go_router (+22 more)

### Community 3 - "signage_theme.dart"
Cohesion: 0.04
Nodes (49): bandBlueMuted, bandInkMuted, bandScoreCaption, blueInk, blueKeyline, blueWash, body, buildSignageTheme (+41 more)

### Community 4 - "Flutter App Entrypoint & Tests"
Cohesion: 0.17
Nodes (9): build, _counter, createState, _incrementCounter, main, MyApp, MyHomePage, _MyHomePageState (+1 more)

### Community 5 - "Forui Theming & Style Deltas"
Cohesion: 0.12
Nodes (22): Custom Controllers & Managed Control Subclassing, Customizing Themes & Styles Guide, Forui Full LLM Documentation (forui-llms-full.txt), FAccordion, FAccordionControl & FAccordionController, FAccordionItem, FAlert & FAlertVariant, FBadge & FBadgeVariant (+14 more)

### Community 6 - "auth_provider.dart"
Cohesion: 0.06
Nodes (32): AppConfig, _envBaseUrl, dioProvider, tokenStorageProvider, AuthState, AuthNotifier, AuthRouterRefresh, authRouterRefreshProvider (+24 more)

### Community 7 - "Learner Attempts, Scoring & Ledger"
Cohesion: 0.13
Nodes (17): payOS Redirect Gateway & PaymentEvents Reconciliation, Asynchronous Speaking Practice & AI Grading Contract, Attempt, Complaint, Free Response, Gateway (payOS / Mock), Grading (AI Rubric Scoring), Learning Path (+9 more)

### Community 8 - "signage_primitives.dart"
Cohesion: 0.06
Nodes (31): action, backgroundColor, bands, build, caption, child, currentBand, danger (+23 more)

### Community 9 - "Web PWA Manifest"
Cohesion: 0.18
Nodes (10): background_color, description, display, icons, name, orientation, prefer_related_applications, short_name (+2 more)

### Community 10 - "Launcher & Web App Icons"
Cohesion: 0.20
Nodes (10): Android Launcher Icon (hdpi - Default Flutter Logo), Android Launcher Icon (mdpi - Default Flutter Logo), Android Launcher Icon (xhdpi - Default Flutter Logo), Android Launcher Icon (xxhdpi - Default Flutter Logo), Android Launcher Icon (xxxhdpi - Default Flutter Logo), Web Favicon (16x16 Default Flutter Logo), Web PWA Icon (192x192 Default Flutter Logo), Web PWA Icon (512x512 Default Flutter Logo) (+2 more)

### Community 11 - "audio_media_adapter.dart"
Cohesion: 0.06
Nodes (28): adapter, AudioMediaAdapter, audioMediaAdapterProvider, DeviceAudioMediaAdapter, dispose, _durationController, durationStream, FakeAudioMediaAdapter (+20 more)

### Community 12 - "Dart Linter & Analysis Options"
Cohesion: 0.33
Nodes (5): analyzer, exclude, include, linter, rules

### Community 13 - "Forui CLI Configuration"
Cohesion: 0.33
Nodes (5): cli, fonts-output, snippet-output, style-output, theme-output

### Community 15 - "Practice Sessions & Weakness Insights"
Cohesion: 0.67
Nodes (3): Insight (AI Narrative), Practice Session, Weakness Analysis

### Community 20 - "network_auth_interceptor_test.dart"
Cohesion: 0.12
Nodes (12): close, _FakeHttpClientAdapter, fetch, main, recordedRequests, close, FakeHttpClientAdapter, fetch (+4 more)

### Community 21 - "dio_client.dart"
Cohesion: 0.06
Nodes (15): adapter, AuthInterceptor, createDioClient, dio, httpClientAdapterProvider, onError, onRequest, onUnauthorized (+7 more)

### Community 22 - "token_storage.dart"
Cohesion: 0.09
Nodes (19): clearToken, InMemoryTokenStorage, readToken, SecureTokenStorage, _storage, _token, _tokenKey, TokenStorage (+11 more)

### Community 23 - "register_screen.dart"
Cohesion: 0.15
Nodes (11): build, createState, dispose, _emailController, _errorMessage, _fullNameController, _isSubmitting, _passwordController (+3 more)

### Community 24 - "_"
Cohesion: 0.12
Nodes (15): _, authenticated, AuthStatus, AuthUser, email, emailVerified, fromJson, fullName (+7 more)

### Community 25 - "account_screen.dart"
Cohesion: 0.08
Nodes (30): AccountScreen, _AccountScreenState, build, code, createState, enabled, _errorMessage, _isSwitching (+22 more)

### Community 26 - "sign_in_screen.dart"
Cohesion: 0.18
Nodes (7): build, createState, dispose, _emailController, _errorMessage, _isSubmitting, _passwordController

### Community 27 - "main_shell.dart"
Cohesion: 0.18
Nodes (4): navigationShell, _tabTitles, description, tabName

### Community 28 - "package:flutter_riverpod/flutter_riverpod.dart"
Cohesion: 0.29
Nodes (5): AuthPageFrame, build, child, panelTitle, screenTitle

### Community 29 - "package:flutter/material.dart"
Cohesion: 0.20
Nodes (4): build, ExtraEfficientApp, appRouterProvider, main

### Community 30 - "verify_email_screen.dart"
Cohesion: 0.22
Nodes (7): createState, dispose, _errorMessage, _isSubmitting, _successMessage, _tokenController, _verify

### Community 31 - "forgot_password_screen.dart"
Cohesion: 0.15
Nodes (11): build, createState, dispose, _emailController, _errorMessage, _isSubmitting, _newPasswordController, _sendReset (+3 more)

### Community 32 - "Agent skills"
Cohesion: 0.22
Nodes (7): 1. Graphify Knowledge Graph (`graphify-out/graph.json`) — Cấm `grep` mù quáng, 2. Context7 MCP (`resolve-library-id` → `query-docs`) — BẮT BUỘC tra cứu thư viện, Agent skills, Domain docs, Issue tracker, Quy tắc Công cụ & Điều hướng Codebase (BẮT BUỘC cho Agent thi công), Triage labels

### Community 33 - "Language"
Cohesion: 0.22
Nodes (8): AI, Catalog, extra efficient, Guided learning, Language, Learning activity, Money, Scoring

### Community 34 - "package:flutter_riverpod/flutter_riverpod.dart"
Cohesion: 0.25
Nodes (4): _contextPayload, main, main, main

### Community 35 - "Issue tracker: GitHub"
Cohesion: 0.29
Nodes (6): Conventions, Issue tracker: GitHub, Pull requests as a triage surface, Wayfinding operations, When a skill says "fetch the relevant ticket", When a skill says "publish to the issue tracker"

### Community 36 - "Domain Docs"
Cohesion: 0.33
Nodes (5): Before exploring, read these, Domain Docs, File structure, Flag ADR conflicts, Use the glossary's vocabulary

### Community 37 - "FLabel & FLabelLayout"
Cohesion: 0.50
Nodes (5): FCheckbox, FLabel & FLabelLayout, FRadio, FSelectGroup & FSelectGroupItemMixin, FSwitch

### Community 42 - "StatelessWidget"
Cohesion: 0.22
Nodes (8): _CertificateTile, CefrBandBar, PlacardAlert, PlacardBadge, PlacardButton, PlacardPanel, ScorePlacard, StateBlock

## Knowledge Gaps
- **273 isolated node(s):** `UnauthorizedCallback`, `tokenStorage`, `onUnauthorized`, `dio`, `httpClientAdapterProvider` (+268 more)
  These have ≤1 connection - possible missing edges or undocumented components. (Counts symbols only; 397 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)
- **10 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `AuthState` connect `auth_provider.dart` to `_`?**
  _High betweenness centrality (0.028) - this node is a cross-community bridge._
- **What connects `UnauthorizedCallback`, `tokenStorage`, `onUnauthorized` to the rest of the system?**
  _273 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Forui Form Controls & Pickers` be split into smaller, more focused modules?**
  _Cohesion score 0.059322033898305086 - nodes in this community are weakly interconnected._
- **Why does `_` connect `_` to `auth_provider.dart`?**
  _High betweenness centrality (0.027) - this node is a cross-community bridge._
- **Should `Exam-Hall Signage & Client Stack` be split into smaller, more focused modules?**
  _Cohesion score 0.051207729468599035 - nodes in this community are weakly interconnected._
- **Why does `Forui Controls (State Management Abstraction)` connect `Forui Form Controls & Pickers` to `Forui Theming & Style Deltas`?**
  _High betweenness centrality (0.009) - this node is a cross-community bridge._
- **Should `Flutter Pubspec & Dependencies` be split into smaller, more focused modules?**
  _Cohesion score 0.06451612903225806 - nodes in this community are weakly interconnected._