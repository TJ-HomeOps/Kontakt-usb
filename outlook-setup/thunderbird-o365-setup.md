# Thunderbird + Office 365 / Exchange

Thunderbird (recent versions, included in this image) supports Microsoft 365
accounts via OAuth2 out of the box:

1. Open Thunderbird → "Set Up an Existing Email Account"
2. Enter your name, your @-work email address, and password
3. Thunderbird auto-detects the Office 365/Exchange server settings and will
   pop up a Microsoft login window (OAuth2) — log in there as normal,
   including MFA if your organisation requires it
4. Accept the detected IMAP/EWS settings

If your organisation has disabled modern auth/OAuth2 for third-party clients,
you'll need an app password or IT will need to allow Thunderbird under your
tenant's conditional access / app policy — that's an admin-side setting, not
something fixable from the client.
