# Railway TA Form — Flutter App

AI-powered Travel Allowance (GA-31) form filling assistant for government railway employees.

## Features

- AI chat interface (Claude) to fill TA forms conversationally in Hinglish/Hindi/English
- GA-31 PDF generation (2 pages) with scanned form images as background
- Contingent Bill support
- Hive local storage (offline-first)
- Remote config via GitHub raw file (API key never bundled)
- Dark mode, multi-language support

## Project Structure

```
lib/
  main.dart                   — App entry point + Hive init
  providers/
    app_provider.dart         — Central state (profile, API key, theme)
  models/
    employee_profile.dart     — Hive model (typeId 0)
    employee_profile.g.dart   — Generated adapter
    trip_model.dart           — TripRow, Trip, TaFormData (plain Dart)
    contingent_model.dart     — ContingentEntry, ContingentFormData
    ta_session.dart           — TaSession (JSON in Hive string box)
  services/
    hive_service.dart         — All Hive box access
    api_service.dart          — Claude API calls
    remote_config_service.dart— GitHub config fetch + cache fallback
    pdf_service.dart          — GA-31 PDF overlay generation
  config/
    app_routes.dart           — Named routes
    app_theme.dart            — Material 3 theme
    form_layout.dart          — PDF x/y overlay coordinates (tune these!)
    ta_rates.dart             — Mileage & DA rates
    remote_config.dart        — GitHub config URL constant
  prompts/
    ta_system_prompt.dart     — TA AI system prompt
    contingent_system_prompt.dart — Contingent AI system prompt
  screens/
    splash_screen.dart
    home_screen.dart
    profile_screen.dart
    month_selection_screen.dart
    draft_preview_screen.dart
    chat_screen.dart
    pdf_preview_screen.dart
    old_records_screen.dart
  widgets/
    chat_bubble_widget.dart
    ta_table_widget.dart
    trip_card_widget.dart (standalone helper)
    status_badge_widget.dart
```

## Quick Start

See `SETUP.md` for full instructions.

1. Add `assets/fonts/Inter-*.ttf` (download from Google Fonts)
2. GA-31 form scans (`assets/images/ga31_page1.png` & `ga31_page2.png`) are
   already included — replace with your own scans if needed
3. Set your GitHub raw URL in `lib/config/remote_config.dart`
4. Run `flutter pub run build_runner build` to generate Hive adapters
5. `flutter run`
