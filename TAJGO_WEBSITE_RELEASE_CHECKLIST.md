# TajGo website release checklist

Run these checks manually after the future Firebase Hosting deployment. Do not submit the Google Play listing until all required public pages are reachable without authentication.

## Public URLs

- [ ] `https://tajgo.ru/` opens the TajGo delivery landing page.
- [ ] `https://tajgo.ru/privacy` opens the privacy policy.
- [ ] `https://tajgo.ru/terms` opens the terms of use.
- [ ] `https://tajgo.ru/support` opens the support page.
- [ ] `https://tajgo.ru/account-deletion` opens the public account deletion instructions.
- [ ] Every URL uses HTTPS with a valid certificate and redirects HTTP to HTTPS.

## Content and navigation

- [ ] Header and footer links work on every page.
- [ ] No link returns 404 and no asset is missing.
- [ ] Google Play CTA is changed from “Скоро в Google Play” only after the real store URL is available.
- [ ] The support contact `support@tajgo.tj` is monitored and can receive external email.
- [ ] Privacy and terms URLs match the URLs entered in Google Play Console.
- [ ] The account deletion URL is entered in Google Play Console and works for a signed-out visitor.
- [ ] Account deletion instructions match the released app flow.
- [ ] The email deletion request opens with the correct recipient and subject.

## Layout and accessibility

- [ ] Check the home page and all legal pages at 360 px width.
- [ ] Check the home page and all legal pages on a desktop viewport.
- [ ] Text is readable, does not overflow, and controls remain usable at 200% zoom.
- [ ] Keyboard focus is visible and the skip link works.
- [ ] Headings and links are understandable with a screen reader.

## Final release check

- [ ] `robots.txt` and `sitemap.xml` are publicly reachable.
- [ ] Page titles, descriptions, canonical URLs, and Open Graph metadata are present.
- [ ] There are no claims about taxi, food, market, unavailable services, or unannounced live features.
- [ ] Recheck all public links after DNS, certificate, or Hosting configuration changes.
