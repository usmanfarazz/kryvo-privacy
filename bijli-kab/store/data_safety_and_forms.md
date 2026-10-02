# Bijli Kab? — Play Console forms (answers)

These are the answers for Bijli Kab? as it is built today, **with Firebase connected** (live
mode). If a feature changes, these answers must change too.

---

## 1. Data safety  (Policy → App content → Data safety)

"Collect" means sent off the phone. Bijli Kab? sends reports to its own Firebase project.

| Question | Answer |
|---|---|
| Does your app collect or share any of the required user data types? | **Yes** |
| Is all of the user data collected by your app encrypted in transit? | **Yes** (HTTPS/TLS to Firebase) |
| Do you provide a way for users to request that their data is deleted? | **Yes** — by e-mail to usmanfaraz1818@gmail.com (reports also auto-delete after 35 days) |

**Data types collected** (none are shared with third parties, none are sold):

| Data type | Collected | Shared | Optional? | Purpose |
|---|---|---|---|---|
| Location → **Approximate location** | Yes (the ~1 km area code of a report and the area's centre) | No | Required to report | App functionality |
| Personal info → **Name** | Yes (the nickname you choose; can be anything) | No | Optional | App functionality (leaderboard) |
| App activity → **Other user-generated content** | Yes (light gone / back reports with optional detail) | No | Required to report | App functionality |
| App info & performance | No | — | — | — |
| Device or other IDs → **User IDs** | Yes (random anonymous Firebase ID) | No | Required | App functionality, fraud prevention (rate limiting) |

Not collected: precise location, phone number, e-mail, contacts, photos, files, messages,
financial info, health, browsing history.

> Note: The precise GPS position is used **on the phone only** to find the area and is not sent.
> Map tiles are downloaded from OpenStreetMap (standard web requests).

---

## 2. Privacy policy  (Policy → App content → Privacy policy)

Host `store/privacy_policy.html` (for example with GitHub Pages) and paste its link. Also put the
same link in `lib/screens/about_screen.dart` → `kPrivacyUrl`.

---

## 3. App access  (Policy → App content → App access)

**All functionality is available without special access.** No login is needed (anonymous sign-in
happens automatically).

## 4. Ads

**No, my app does not contain ads.**

## 5. Content rating  (IARC questionnaire)

- Category: **Utility, Productivity, Communication, or Other**
- Violence, sexuality, language, controlled substances, gambling: **No**
- Does the app allow users to interact or exchange content? **Yes** — users share power-status
  reports and a nickname on a leaderboard (no chat, no free text, no media).
- Does the app share the user's location with other users? **No** (only an area's on/off status
  is shown, not who reported it).

Expected rating: **Everyone / PEGI 3**.

## 6. Target audience

**18 and over** (simplest; the app is a utility) — or 13+ if you prefer. It is not designed for
children.

## 7. Permissions declaration

| Permission | Why |
|---|---|
| `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION` | Find the user's ~1 km area while choosing it (foreground only). |
| `POST_NOTIFICATIONS` | Outage warnings and "light is back" alerts. |
| `RECEIVE_BOOT_COMPLETED` | Re-arm scheduled outage warnings after a restart. |
| `INTERNET` | Reports, live map, leaderboard. |

No background location, no exact-alarm permission.

## 8. News app / Government app

- News app: **No**
- Government app: **No** — the store listing and the app say the forecast is community-based and
  not official.
