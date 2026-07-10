# Foodie 🍽️ — Melbourne Restaurants Seed Data
# Version: 1.0.0 | 2026-07-10
# Curated list of well-known Melbourne restaurants across cuisines and suburbs.

---

## 🔴 CBD / Flinders Lane

### Gimlet at Cavendish House
- **Cuisine:** Modern Australian / Cocktail Bar
- **Suburb:** CBD (Russell St)
- **Vibe:** Elegant, art deco, cocktail-focused
- **Price Range:** $$$ (mains $40–$55)
- **Best For:** Celebratory dinners, date nights, after-work drinks
- **Notable:** 2023 Gourmet Traveller Restaurant of the Year

### Supernormal
- **Cuisine:** Modern Asian (Japanese/Korean/Chinese fusion)
- **Suburb:** CBD (Flinders Lane)
- **Vibe:** Bustling, share-plate, loud
- **Price Range:** $$ (mains $25–$40)
- **Best For:** Groups, casual catch-ups, sharing
- **Notable:** Andrew McConnell venue

### Flower Drum
- **Cuisine:** Cantonese (fine dining)
- **Suburb:** CBD (Market Lane)
- **Vibe:** Formal, white tablecloth, old-school
- **Price Range:** $$$$ (mains $50–$80+)
- **Best For:** Special occasions, business dinners
- **Notable:** Melbourne institution since 1975

### Etta
- **Cuisine:** Modern Australian (wood-fired, share)
- **Suburb:** CBD (Little Collins St)
- **Vibe:** Warm, intimate, open kitchen
- **Price Range:** $$$ (mains $35–$55)
- **Best For:** Date nights, small groups (2–4)

---

## 🟠 Fitzroy / Collingwood

### Cutler & Co.
- **Cuisine:** Modern Australian
- **Suburb:** Fitzroy (Gertrude St)
- **Vibe:** Polished, romantic, courtyard
- **Price Range:** $$$ (mains $40–$60)
- **Best For:** Date nights, special dinners
- **Notable:** Andrew McConnell venue, 1-hat

### Attica
- **Cuisine:** Modern Australian (native ingredients)
- **Suburb:** Ripponlea (near Fitzroy)
- **Vibe:** Fine dining, degustation, experiential
- **Price Range:** $$$$$ (degustation $295+)
- **Best For:** Bucket list dining, special occasions
- **Notable:** 3-hat, world top 50

### Marion
- **Cuisine:** Italian (wine bar + small plates)
- **Suburb:** Fitzroy (Gertrude St)
- **Vibe:** Casual, natural wine, excellent pasta
- **Price Range:** $$ (mains $20–$35)
- **Best For:** Casual catch-ups, wine lovers, weeknight

### Lune Croissanterie
- **Cuisine:** Bakery / Pastry
- **Suburb:** Fitzroy (Rose St)
- **Vibe:** Iconic, queue, takeaway
- **Price Range:** $ (croissants $8–$12)
- **Best For:** Breakfast, weekend treat, best croissant in the world
- **Notable:** Voted world's best croissant, 2017

---

## 🟡 Richmond / South Yarra / Prahran

### Tonka
- **Cuisine:** Modern Indian
- **Suburb:** Richmond (Duckboard Pl)
- **Vibe:** Sophisticated, vibrant, share-plate
- **Price Range:** $$$ (mains $35–$50)
- **Best For:** Groups, adventurous eaters, cocktails
- **Notable:** 1-hat

### Ishizuka
- **Cuisine:** Japanese (kaiseki)
- **Suburb:** South Yarra (Bourke St) — actually CBD
- **Vibe:** Intimate, omakase, counter dining
- **Price Range:** $$$$$ (degustation $225+)
- **Best For:** Special occasion, date night
- **Notable:** 2-hat

### Firebird
- **Cuisine:** Modern European (wood-fired, Georgian-inspired)
- **Suburb:** South Yarra (Chapel St)
- **Vibe:** Dark, moody, share-style
- **Price Range:** $$$ (mains $35–$50)
- **Best For:** Date nights, groups

---

## 🟢 Carlton / Parkville

### Tiamo
- **Cuisine:** Italian (classic)
- **Suburb:** Carlton (Lygon St)
- **Vibe:** Bustling, family-friendly, classic red sauce
- **Price Range:** $$ (mains $20–$35)
- **Best For:** Casual dinner, family, pre-theatre
- **Notable:** Lygon St institution

### King & Godfree
- **Cuisine:** Italian (modern)
- **Suburb:** Carlton (Lygon St)
- **Vibe:** Trendy, rooftop bar, market-style
- **Price Range:** $$–$$$ (mains $25–$45)
- **Best For:** Groups, drinks + dinner, rooftop

---

## 🔵 St Kilda / Windsor

### Stokehouse
- **Cuisine:** Modern Australian
- **Suburb:** St Kilda (St Kilda Beach)
- **Vibe:** Waterfront, elegant, seasonal
- **Price Range:** $$$$ (mains $45–$65)
- **Best For:** Beachside dining, special occasions
- **Notable:** 1-hat, stunning views

### Cicciolina
- **Cuisine:** Italian (modern)
- **Suburb:** St Kilda (Acland St)
- **Vibe:** Cosy, romantic, window booths
- **Price Range:** $$$ (mains $35–$55)
- **Best For:** Date nights, St Kilda locals

---

## 🟣 Brunswick / Footscray

### A1 Bakery
- **Cuisine:** Lebanese
- **Suburb:** Brunswick (Sydney Rd)
- **Vibe:** Casual, no-frills, late-night
- **Price Range:** $ (mains $10–$20)
- **Best For:** Hungry late-night, budget eat
- **Notable:** Melbourne institution, open till 3am

### Thuan Long
- **Cuisine:** Vietnamese
- **Suburb:** Footscray (Hopkins St)
- **Vibe:** Casual, no-frills, authentic
- **Price Range:** $ (mains $10–$18)
- **Best For:** Pho, budget dinner, authentic Vietnamese

### Mr West
- **Cuisine:** Modern Australian / Cafe
- **Suburb:** Footscray (Paisley St)
- **Vibe:** Hip cafe, brunch, specialty coffee
- **Price Range:** $$ (breakfast $15–$25)
- **Best For:** Brunch, coffee, casual meeting

---

# Schema Notes — Preference & History Recording

## User Preferences (to be recorded per user)
```yaml
user_id: <telegram_id>
name: <display_name>
dietary:
  - vegetarian / vegan / gluten-free / halal / none
  - allergies: <list>
budget_per_person: <$ / $$ / $$$ / $$$$>
preferred_suburbs:
  - Fitzroy
  - CBD
  - Richmond
avoid_cuisines:
  - Sichuan
  - <any>
favourite_restaurants:
  - <name>
  - <name>
notes: <any free-text>
```

## Dining History Entry (per outing)
```yaml
date: 2026-07-10
restaurant: <name>
suburb: <suburb>
attendees:
  - <user_id_1>
  - <user_id_2>
  - <user_id_3>
cuisine: <type>
spend_per_person: <$ amount>
rating: <1-5>
verdict: <brief summary>
photos: <optional links>
```

## Poll Format
```yaml
poll_id: <uuid>
date_range: <date_range>
proposed_by: <user_id>
options:
  - restaurant: <name>
    suburb: <suburb>
    reason: <why this works>
    price_range: <$>
responses:
  - user: <user_id>
    vote: <option_index>
    preference: <like / neutral / avoid>
    dietary_note: <optional>
status: open / decided / closed
result: <decided_restaurant + date>
```