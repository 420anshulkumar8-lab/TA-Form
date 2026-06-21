# Railway TA Form — Flutter App

Travel Allowance (GA-31) form filling app for government railway employees.
Manual entry only — no AI / chat assistant.

## Features

- Manual TA table entry — add/remove rows yourself, real-form layout
- Auto-calculated TA amount from departure/arrival time + employee Level
- Optional Contingent Bill section on the same screen
- GA-31 PDF generation (2 pages) with scanned form images as background;
  Contingent Bill prints directly below the TA table on the same scanned page
- Hive local storage (offline-first)
- Dark mode

## Project Structure

```
lib/
  main.dart                     — App entry point + Hive init
  providers/
    app_provider.dart           — Central state (profile, theme)
  models/
    employee_profile.dart       — Hive model (typeId 0)
    employee_profile.g.dart     — Generated adapter
    trip_model.dart             — TripRow, TaFormData (flat row list)
    contingent_model.dart       — ContingentEntry, ContingentFormData
    ta_session.dart             — TaSession (JSON in Hive string box)
  services/
    hive_service.dart           — All Hive box access
    ta_calculation_service.dart — Row-amount + total calculations
    pdf_service.dart            — GA-31 PDF overlay generation
  config/
    app_routes.dart             — Named routes
    app_theme.dart              — Material 3 theme
    form_layout.dart            — PDF x/y overlay coordinates (tune these!)
    ta_rates.dart                — Duration-slab TA rates by Level
    railway_options.dart        — Railway dropdown list
    department_options.dart     — Department dropdown list
    ta_calc_helpers.dart        — Small shared helpers
  screens/
    splash_screen.dart
    home_screen.dart
    profile_screen.dart
    month_selection_screen.dart
    ta_form_screen.dart         — Fill / view / edit / finalize TA + Contingent
    pdf_preview_screen.dart
  widgets/
    status_badge_widget.dart
    editable_cell_widget.dart   — Tap-to-edit table cells

## Quick Start

See `SETUP.md` for full instructions.

1. GA-31 form scans (`assets/images/ga31_page1.png` & `ga31_page2.png`) are
   already included — replace with your own scans if needed
2. Run `flutter pub run build_runner build` to (re)generate Hive adapters
3. `flutter run`
```
