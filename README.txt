GYMBOOK: how to put it online and install it

1. Go to https://app.netlify.com/drop and sign up or log in (free).
2. Drag this whole folder (the one containing index.html) onto the page.
3. Netlify gives you an address like https://something.netlify.app.
   If it asks for a password or a login, make the site public in the
   project's settings: the app holds no data itself, so public is safe.
4. On your phone, open that address:
   - iPhone: in Safari, tap Share, then Add to Home Screen.
   - Android: in Chrome, tap the menu, then Install app.
5. Open GymBook from the new icon, then go to Routines > Backups >
   Import backup and choose the JSON backup you exported from the
   Claude version.

Your workouts are saved on the phone itself. Use "Back up now" every
few weeks and keep the file somewhere safe (Files, Drive, email).

Updating later: drag the new folder onto your site's "Production
deploys" area in Netlify. Change VERSION at the top of sw.js each
time, so phones pick up the new version (the app shows "Reload").
