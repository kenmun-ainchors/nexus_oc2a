# CHANGELOG

## 2026-05-21
- Fix EOD Blog format drift for May 18, 19, and 20.
- Restored approved template (CSS accent #c49b5e, structure) for drifted blogs.
- Updated cron job `a027fd60` (Daily Close — Blog) with mandatory template validation:
    - Requirement: accent color must be exactly #c49b5e.
    - Requirement: minimum of 4 `h2` sections.
