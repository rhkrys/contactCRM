# ContactCRM — Web Dashboard

Mobile-friendly web version of ContactCRM: Google SSO sign-in, dashboard, contacts
with notes/likes/dislikes, kanban pipelines (with drag-and-drop and custom pipelines),
reminders, and settings — all in the periwinkle/peach palette.

## Privacy model

- **Google Sign-In is identity only.** The ID token is decoded client-side for your
  name/avatar and never stored or sent to any server.
- **All CRM data stays in this browser**, AES-GCM encrypted (WebCrypto) before it
  touches `localStorage`. The encryption key is a **non-extractable** `CryptoKey`
  held in IndexedDB — it cannot be exported by script.
- No backend, no analytics, no third-party requests beyond the Google Sign-In script.

## Setup

1. Create an OAuth 2.0 **Web application** client ID at
   https://console.cloud.google.com/apis/credentials
2. Add your origin (e.g. `http://localhost:8080` or your domain) to
   *Authorized JavaScript origins*.
3. Provide the client ID either by editing `GOOGLE_CLIENT_ID` at the top of `app.js`,
   or by adding a `config.js` before `app.js`:

```html
<script>window.CONTACTCRM_GOOGLE_CLIENT_ID = "1234-abc.apps.googleusercontent.com";</script>
```

4. Serve the folder (any static server):

```sh
cd web
python3 -m http.server 8080
# open http://localhost:8080
```

"Continue without Google (local demo)" works with no setup at all.

## Files

| File | Purpose |
|---|---|
| `index.html` | Shell: login screen, app layout, tab bar |
| `styles.css` | Full palette + mobile-first responsive styles |
| `crypto.js` | WebCrypto AES-GCM + IndexedDB key storage |
| `store.js` | Encrypted localStorage data layer (contacts, pipelines, reminders) |
| `app.js` | Views, routing, Google SSO, drag-and-drop kanban |
