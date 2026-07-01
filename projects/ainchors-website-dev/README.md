# AINCHORS Local Dev Replica

Self-contained local development replica of [ainchors.com](https://ainchors.com).

## Quick Start

```bash
./serve.sh
# Opens at http://localhost:8080
```

Or specify a custom port:

```bash
./serve.sh 9090
```

## Structure

```
projects/ainchors-website-dev/
├── serve.sh              # Local dev server script
├── README.md             # This file
├── pages/                # Page HTML files (route/index.html)
│   ├── home/
│   ├── about-us-814253/
│   ├── consulting-gov/
│   ├── consulting-main/
│   ├── consulting-private/
│   ├── contact-us/
│   ├── courses/
│   ├── events/
│   ├── faqs/
│   ├── hiring-page/
│   ├── success-story-of-angie/
│   ├── testimonials/
│   └── trainers-profile/
├── assets/               # Local static assets
│   ├── css/              # Stylesheets
│   ├── js/               # JavaScript modules
│   ├── images/           # Images
│   ├── fonts/            # Google Fonts (woff2 + CSS)
│   └── icons/            # Social media icons
└── raw/                  # Original downloaded files (reference only)
    ├── pages/            # Raw HTML pages
    └── assets/           # Raw downloaded assets
```

## Pages (13 total)

| Route | Description |
|-------|-------------|
| `/home` | Home page |
| `/about-us-814253` | About AINCHORS |
| `/consulting-gov` | Government/Public Sector Consulting |
| `/consulting-main` | Consulting Main |
| `/consulting-private` | Private Sector Consulting |
| `/contact-us` | Contact form |
| `/courses` | Course listings |
| `/events` | Events |
| `/faqs` | Frequently Asked Questions |
| `/hiring-page` | Careers/Join Us |
| `/success-story-of-angie` | Angie's Success Story |
| `/testimonials` | Client testimonials |
| `/trainers-profile` | Trainer profiles |

## Known Limitations

1. **SPA Architecture**: The site is built on LeadConnector (HighLevel) platform using Nuxt.js. It's a heavy single-page application. Local rendering may differ from production.

2. **Forms are visual-only**: Contact forms, newsletter signups, and other form submissions will not work locally. They require the LeadConnector backend (`backend.leadconnectorhq.com`).

3. **Responsive images**: Some `<source>` tags in `<picture>` elements still reference `images.leadconnectorhq.com` for responsive image variants. The fallback `<img>` tags point to local files. Images will load from local files in most cases.

4. **Tidio Chat**: The Tidio live chat widget (`code.tidio.co`) has been removed from local pages.

5. **FontAwesome icons**: Some FontAwesome webfont references in inline CSS still point to `stcdn.leadconnectorhq.com`. Basic icon rendering may be affected.

6. **CloudFlare email protection**: Email obfuscation scripts have been stubbed out. Email links may not work.

7. **External tenant images**: Some images from a different LeadConnector tenant (`n4lLPqZ3Dv19TQTebcB6`) are referenced in inline CSS backgrounds and will not load locally.

8. **No backend**: This is a static HTML/CSS/JS replica only. No server-side processing, database, or API endpoints.

## CHG

CHG-0794 — Local dev replica of ainchors.com

## Evidence Files

- `.openclaw/tmp/ainchors-website-inventory.json` — Site inventory
- `.openclaw/tmp/ainchors-website-smoke-test.md` — Smoke test results
