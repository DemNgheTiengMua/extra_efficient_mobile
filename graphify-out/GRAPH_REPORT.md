# Graph Report - extra_efficient_mobile  (2026-11-13)

## Corpus Check
- 35 files · ~79,111 words
- Verdict: corpus is large enough that graph structure adds value.
- Unclassified: 15 file(s) not represented in the graph (top: .xml 7, (none) 3, .properties 2)

## Summary
- 238 nodes · 298 edges · 20 communities (15 shown, 5 thin omitted)
- Extraction: 88% EXTRACTED · 12% INFERRED · 0% AMBIGUOUS · INFERRED: 35 edges (avg confidence: 0.9)
- Token cost: 0 input · 0 output

## Community Hubs (Navigation)
- Forui Form Controls & Pickers
- Exam-Hall Signage & Client Stack
- Flutter Pubspec & Dependencies
- Product Scope & Domain Governance
- Flutter App Entrypoint & Tests
- Forui Theming & Style Deltas
- Forui Shell, Overlay & Feedback Widgets
- Learner Attempts, Scoring & Ledger
- Forui Items, Menus & Layout
- Web PWA Manifest
- Launcher & Web App Icons
- Forui Accordion & Hook Controllers
- Dart Linter & Analysis Options
- Forui CLI Configuration
- Android MainActivity Host
- Practice Sessions & Weakness Insights
- Content Ingestion & Item Lifecycle

## God Nodes (most connected - your core abstractions)
1. `Forui Controls (State Management Abstraction)` - 24 edges
2. `FThemeData` - 15 edges
3. `Exam-Hall Signage Design System (Bảng hiệu phòng thi)` - 13 edges
4. `FPopover, FPopoverControl & FPopoverController` - 10 edges
5. `ADR 0001: Flutter Client Stack and Exam-Hall Signage Theme` - 9 edges
6. `Forui Full LLM Documentation (forui-llms-full.txt)` - 9 edges
7. `FTextField (email, password, multiline)` - 8 edges
8. `Phase 1 Mobile Learner Port Scope` - 6 edges
9. `FScaffold` - 6 edges
10. `cli` - 5 edges

## Surprising Connections (you probably didn't know these)
- `Target Backend Stack (.NET 10, EF Core, ASP.NET Core Web API, SQL Server)` --semantically_similar_to--> `Backend API (Docker localhost:5001 / 10.0.2.2:5001)`  [INFERRED] [semantically similar]
  docs/backend-ref/PRODUCT.md → AGENTS.md
- `Backend Reference Domain Context & Ubiquitous Language` --semantically_similar_to--> `Certificate`  [INFERRED] [semantically similar]
  docs/backend-ref/CONTEXT.md → GLOSSARY.md
- `Android Launcher Icon (xxxhdpi - Default Flutter Logo)` --semantically_similar_to--> `Web PWA Icon (512x512 Default Flutter Logo)`  [INFERRED] [semantically similar]
  android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png → web/icons/Icon-512.png
- `extra_efficient_mobile Flutter Project` --conceptually_related_to--> `ADR 0001: Flutter Client Stack and Exam-Hall Signage Theme`  [INFERRED]
  README.md → docs/adr/0001-flutter-client-stack-and-signage-theme.md
- `dio HTTP Client with Bearer Interceptor` --implements--> `JWT Bearer Auth (POST /api/auth/sign-in)`  [INFERRED]
  docs/adr/0001-flutter-client-stack-and-signage-theme.md → AGENTS.md

## Import Cycles
- None detected.

## Hyperedges (group relationships)
- **Exam-Hall Signage UI Foundation (ADR-0001 + DESIGN.md + Forui + IBM Plex)** — docs_adr_0001_flutter_client_stack_and_signage_theme_client_stack_decision, docs_backend_ref_design_examhallsignage, docs_backend_ref_forui_llms_foruithemesanddeltas, docs_backend_ref_design_ibmplextypography, assets_fonts_ibm_plex_sans_license_sil_open_font_license [EXTRACTED 1.00]
- **Learner Diagnostic Placement, Scoring, and Guided Learning Path Flow** — glossary_certificate, glossary_placementattempt, glossary_scaledscore, glossary_band, glossary_learningpath, glossary_practicesession, glossary_weaknessanalysis [EXTRACTED 1.00]
- **Append-Only Credit Ledger and Gateway Order Reconciliation** — glossary_credit, glossary_ledger, glossary_order, glossary_gateway, glossary_paymentevent, docs_backend_ref_product_creditmonetisation, docs_backend_ref_product_payosgateway [EXTRACTED 1.00]
- **Forui Theme, Variant, and Style Delta Architecture** — docs_backend_ref_forui_llms_full_ftheme, docs_backend_ref_forui_llms_full_fthemedata, docs_backend_ref_forui_llms_full_fcolors, docs_backend_ref_forui_llms_full_ftypography, docs_backend_ref_forui_llms_full_fstyle, docs_backend_ref_forui_llms_full_fhapticfeedback, docs_backend_ref_forui_llms_full_fvariants, docs_backend_ref_forui_llms_full_fplatformvariant, docs_backend_ref_forui_llms_full_fbreakpoints, docs_backend_ref_forui_llms_full_ficons, docs_backend_ref_forui_llms_full_style_deltas, docs_backend_ref_forui_llms_full_theme_extensions, docs_backend_ref_forui_llms_full_material_interop, docs_backend_ref_forui_llms_full_customizing_themes [EXTRACTED 1.00]
- **Forui Control Abstraction (Lifted & Managed Controls and Controllers)** — docs_backend_ref_forui_llms_full_controls, docs_backend_ref_forui_llms_full_lifted_control, docs_backend_ref_forui_llms_full_managed_control, docs_backend_ref_forui_llms_full_custom_controllers, docs_backend_ref_forui_llms_full_forui_hooks, docs_backend_ref_forui_llms_full_faccordioncontrol, docs_backend_ref_forui_llms_full_fcalendarcontrol, docs_backend_ref_forui_llms_full_fdateselectioncontrol, docs_backend_ref_forui_llms_full_fautocompletecontrol, docs_backend_ref_forui_llms_full_fmultivaluecontrol, docs_backend_ref_forui_llms_full_fselectcontrol, docs_backend_ref_forui_llms_full_ftextfieldcontrol [EXTRACTED 1.00]
- **Forui App Shell, Layout, and Navigation Widget Family** — docs_backend_ref_forui_llms_full_fscaffold, docs_backend_ref_forui_llms_full_fheader, docs_backend_ref_forui_llms_full_fbottomnavigationbar, docs_backend_ref_forui_llms_full_fsidebar, docs_backend_ref_forui_llms_full_ftabs, docs_backend_ref_forui_llms_full_fbreadcrumb, docs_backend_ref_forui_llms_full_fpagination, docs_backend_ref_forui_llms_full_fresizable, docs_backend_ref_forui_llms_full_fdivider [EXTRACTED 1.00]
- **Forui Form, Text Input, and Selection Widget Family** — docs_backend_ref_forui_llms_full_fbutton, docs_backend_ref_forui_llms_full_fbuttonstyle, docs_backend_ref_forui_llms_full_ftextfield, docs_backend_ref_forui_llms_full_ftextformfield, docs_backend_ref_forui_llms_full_fotpfield, docs_backend_ref_forui_llms_full_fcheckbox, docs_backend_ref_forui_llms_full_fradio, docs_backend_ref_forui_llms_full_fswitch, docs_backend_ref_forui_llms_full_flabel, docs_backend_ref_forui_llms_full_fselect, docs_backend_ref_forui_llms_full_fmultiselect, docs_backend_ref_forui_llms_full_fselectgroup, docs_backend_ref_forui_llms_full_fautocomplete, docs_backend_ref_forui_llms_full_fslider [EXTRACTED 1.00]
- **Forui Calendar, Date, Time, and Wheel Picker Widget Family** — docs_backend_ref_forui_llms_full_fcalendar, docs_backend_ref_forui_llms_full_flinecalendar, docs_backend_ref_forui_llms_full_fdatefield, docs_backend_ref_forui_llms_full_fdatetimepicker, docs_backend_ref_forui_llms_full_ftimefield, docs_backend_ref_forui_llms_full_ftimepicker, docs_backend_ref_forui_llms_full_fpicker [EXTRACTED 1.00]
- **Forui Portal, Overlay, Dialog, Sheet, Menu, Toast, and Progress Widgets** — docs_backend_ref_forui_llms_full_foverlay, docs_backend_ref_forui_llms_full_fportal, docs_backend_ref_forui_llms_full_fpointportal, docs_backend_ref_forui_llms_full_fpopover, docs_backend_ref_forui_llms_full_fpopovermenu, docs_backend_ref_forui_llms_full_fcontextmenu, docs_backend_ref_forui_llms_full_fdialog, docs_backend_ref_forui_llms_full_fsheet, docs_backend_ref_forui_llms_full_fpersistentsheet, docs_backend_ref_forui_llms_full_ftoast, docs_backend_ref_forui_llms_full_ftooltip, docs_backend_ref_forui_llms_full_falert, docs_backend_ref_forui_llms_full_fprogress, docs_backend_ref_forui_llms_full_fdeterminateprogress, docs_backend_ref_forui_llms_full_fcircularprogress [EXTRACTED 1.00]
- **Forui Data Display, Accordion, Card, Item, and Tile Widget Family** — docs_backend_ref_forui_llms_full_faccordion, docs_backend_ref_forui_llms_full_faccordionitem, docs_backend_ref_forui_llms_full_fcollapsible, docs_backend_ref_forui_llms_full_favatar, docs_backend_ref_forui_llms_full_fbadge, docs_backend_ref_forui_llms_full_fcard, docs_backend_ref_forui_llms_full_fitem, docs_backend_ref_forui_llms_full_fitemgroup, docs_backend_ref_forui_llms_full_ftile, docs_backend_ref_forui_llms_full_ftilegroup, docs_backend_ref_forui_llms_full_fselecttilegroup, docs_backend_ref_forui_llms_full_fselectmenutile, docs_backend_ref_forui_llms_full_ftappable, docs_backend_ref_forui_llms_full_ffocusedoutline [EXTRACTED 1.00]
- **Android Multi-Density Mipmap Launcher Icons** — android_app_src_main_res_mipmap_mdpi_ic_launcher_flutter_launcher_icon, android_app_src_main_res_mipmap_hdpi_ic_launcher_flutter_launcher_icon, android_app_src_main_res_mipmap_xhdpi_ic_launcher_flutter_launcher_icon, android_app_src_main_res_mipmap_xxhdpi_ic_launcher_flutter_launcher_icon, android_app_src_main_res_mipmap_xxxhdpi_ic_launcher_flutter_launcher_icon [INFERRED 0.95]
- **Web Favicon and PWA Manifest Icons** — web_favicon_flutter_favicon, web_icons_icon_192_flutter_web_icon, web_icons_icon_512_flutter_web_icon, web_icons_icon_maskable_192_flutter_maskable_icon, web_icons_icon_maskable_512_flutter_maskable_icon [INFERRED 0.95]

## Communities (20 total, 5 thin omitted)

### Community 0 - "Forui Form Controls & Pickers"
Cohesion: 0.10
Nodes (36): Forui Controls (State Management Abstraction), FAutocomplete & FAutocompleteSection, FAutocompleteControl & FAutocompleteController, FCalendar (grid, splitGrid, wheel), FCalendarControl & FCalendarController, FCheckbox, FDateField (calendar, input), FDateSelectionControl & FDateSelectionController (+28 more)

### Community 1 - "Exam-Hall Signage & Client Stack"
Cohesion: 0.09
Nodes (19): JWT Bearer Auth (POST /api/auth/sign-in), SIL Open Font License 1.1 (IBM Plex), dio HTTP Client with Bearer Interceptor, go_router Declarative Routing, flutter_riverpod State Management & DI, flutter_secure_storage JWT Persistence, Signature Component: Answer Navigator, Signature Component: CEFR Band Bar (+11 more)

### Community 2 - "Flutter Pubspec & Dependencies"
Cohesion: 0.08
Nodes (23): dependencies, cupertino_icons, flutter, forui, description, dev_dependencies, flutter_lints, flutter_test (+15 more)

### Community 3 - "Product Scope & Domain Governance"
Cohesion: 0.12
Nodes (14): Backend API (Docker localhost:5001 / 10.0.2.2:5001), GitHub Issue Tracker & CLI Conventions, Wayfinder Map & Native Issue Dependencies, Five Canonical Triage Labels, Backend Reference Domain Context & Ubiquitous Language, Target Backend Stack (.NET 10, EF Core, ASP.NET Core Web API, SQL Server), Audio Slicing, Certificate (+6 more)

### Community 4 - "Flutter App Entrypoint & Tests"
Cohesion: 0.12
Nodes (10): build, _counter, createState, _incrementCounter, main, MyApp, MyHomePage, _MyHomePageState (+2 more)

### Community 5 - "Forui Theming & Style Deltas"
Cohesion: 0.18
Nodes (15): Customizing Themes & Styles Guide, Forui Full LLM Documentation (forui-llms-full.txt), FAlert & FAlertVariant, FBadge & FBadgeVariant, FBreakpoints & Responsive Layouts, FColors, FIcons, FIcon & FLucideIcons, Forui CLI (init, snippet, style, theme) (+7 more)

### Community 6 - "Forui Shell, Overlay & Feedback Widgets"
Cohesion: 0.12
Nodes (17): FAvatar, FBottomNavigationBar & FBottomNavigationBarItem, FButton (primary, secondary, outline, destructive, ghost, link, icon, raw), FButtonStyle, FButtonVariant & FButtonSizeVariant, FCard & FCardStyle, FCircularProgress (loader, pinwheel), FDeterminateProgress, FDialog, showFDialog & FDialogRouteStyle (+9 more)

### Community 7 - "Learner Attempts, Scoring & Ledger"
Cohesion: 0.13
Nodes (17): payOS Redirect Gateway & PaymentEvents Reconciliation, Asynchronous Speaking Practice & AI Grading Contract, Attempt, Complaint, Free Response, Gateway (payOS / Mock), Grading (AI Rubric Scoring), Learning Path (+9 more)

### Community 8 - "Forui Items, Menus & Layout"
Cohesion: 0.27
Nodes (12): FBreadcrumb & FBreadcrumbItem, FContextMenu, FDivider & FDividerStyle, FFocusedOutline & FFocusedOutlineStyle, FItem & FItemVariant, FItemGroup & FItemDivider, FPopoverMenu, FResizable, FResizableRegion, FResizableDivider & FResizableControl (+4 more)

### Community 9 - "Web PWA Manifest"
Cohesion: 0.18
Nodes (10): background_color, description, display, icons, name, orientation, prefer_related_applications, short_name (+2 more)

### Community 10 - "Launcher & Web App Icons"
Cohesion: 0.20
Nodes (10): Android Launcher Icon (hdpi - Default Flutter Logo), Android Launcher Icon (mdpi - Default Flutter Logo), Android Launcher Icon (xhdpi - Default Flutter Logo), Android Launcher Icon (xxhdpi - Default Flutter Logo), Android Launcher Icon (xxxhdpi - Default Flutter Logo), Web Favicon (16x16 Default Flutter Logo), Web PWA Icon (192x192 Default Flutter Logo), Web PWA Icon (512x512 Default Flutter Logo) (+2 more)

### Community 11 - "Forui Accordion & Hook Controllers"
Cohesion: 0.29
Nodes (7): Custom Controllers & Managed Control Subclassing, FAccordion, FAccordionControl & FAccordionController, FAccordionItem, FCollapsible, forui_hooks (Flutter Hooks Integration), Managed Control (.managed)

### Community 12 - "Dart Linter & Analysis Options"
Cohesion: 0.33
Nodes (5): analyzer, exclude, include, linter, rules

### Community 13 - "Forui CLI Configuration"
Cohesion: 0.33
Nodes (5): cli, fonts-output, snippet-output, style-output, theme-output

### Community 15 - "Practice Sessions & Weakness Insights"
Cohesion: 0.67
Nodes (3): Insight (AI Narrative), Practice Session, Weakness Analysis

## Knowledge Gaps
- **45 isolated node(s):** `title`, `_counter`, `main`, `build`, `createState` (+40 more)
  These have ≤1 connection - possible missing edges or undocumented components. (Counts symbols only; 92 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)
- **5 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `Forui Controls (State Management Abstraction)` connect `Forui Form Controls & Pickers` to `Forui Items, Menus & Layout`, `Forui Accordion & Hook Controllers`, `Forui Theming & Style Deltas`, `Forui Shell, Overlay & Feedback Widgets`?**
  _High betweenness centrality (0.076) - this node is a cross-community bridge._
- **Are the 2 inferred relationships involving `Exam-Hall Signage Design System (Bảng hiệu phòng thi)` (e.g. with `Forui Themes, Widget Styles, Deltas, and Controllers` and `Server-Authoritative Time, Answers, and Balance Principle`) actually correct?**
  _`Exam-Hall Signage Design System (Bảng hiệu phòng thi)` has 2 INFERRED edges - model-reasoned connections that need verification._
- **What connects `title`, `_counter`, `main` to the rest of the system?**
  _45 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Forui Form Controls & Pickers` be split into smaller, more focused modules?**
  _Cohesion score 0.10317460317460317 - nodes in this community are weakly interconnected._
- **Why does `Phase 1 Mobile Learner Port Scope` connect `Product Scope & Domain Governance` to `Exam-Hall Signage & Client Stack`?**
  _High betweenness centrality (0.037) - this node is a cross-community bridge._
- **Should `Exam-Hall Signage & Client Stack` be split into smaller, more focused modules?**
  _Cohesion score 0.08547008547008547 - nodes in this community are weakly interconnected._
- **Should `Flutter Pubspec & Dependencies` be split into smaller, more focused modules?**
  _Cohesion score 0.08333333333333333 - nodes in this community are weakly interconnected._