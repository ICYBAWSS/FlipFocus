# FlipFocus

Flip your phone face down to start a focus session. Flip it back to stop. Track streaks, pick a theme, stay off your phone.

iOS 18.0+ · Bundle ID `icybawss.FlipFocus`

## Install via AltStore

Add this source in AltStore / SideStore:

```
https://raw.githubusercontent.com/ICYBAWSS/flipfocus/main/apps.json
```

Or tap: [altstore://source?url=https://raw.githubusercontent.com/ICYBAWSS/flipfocus/main/apps.json](altstore://source?url=https://raw.githubusercontent.com/ICYBAWSS/flipfocus/main/apps.json)

Then open the **FlipFocus** source and install the app.

## Publishing a new version

The `v1.0` release is live and installable via the source above. To ship a new version:

1. **Build & export an IPA** in Xcode: Product → Archive → Distribute App → *Release Testing* (or Ad Hoc / Development), which produces `FlipFocus.ipa`.
2. **Create a GitHub Release** tagged `v1.0` on this repo and upload `FlipFocus.ipa` as an asset. The download URL must match the one in `apps.json`:
   `https://github.com/ICYBAWSS/flipfocus/releases/download/v1.0/FlipFocus.ipa`
3. **Update `apps.json`**: set the version's `size` to the IPA's exact size in **bytes** (`stat -f%z FlipFocus.ipa`). AltStore validates this. Bump `version`, `buildVersion`, `date`, and add a new `versions[]` entry for each subsequent release (keep older entries for update history).

> Note: AltStore installs unsigned/dev-signed IPAs and re-signs them on-device with your Apple ID, so you don't need a distribution certificate — a free Apple ID works, with the usual 7-day resign limit.
