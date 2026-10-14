# raybans-meta

Open-source iOS experiments for Ray-Ban Meta glasses (Gen 2), built on Meta's Wearables Device Access Toolkit (DAT).

## How this actually works

Your code runs as an **iOS app on your iPhone** — nothing is uploaded to or executed on the glasses themselves. The app opens a *session* with the glasses over Bluetooth, and the DAT SDK (`MWDATCore`, `MWDATCamera`) gives the app access to the glasses' camera, mic (via Bluetooth HFP), and speakers. Registration and permission grants happen through the Meta AI app, which deeplinks back to your app. The glasses just run Meta firmware.

## First slice: Snap Journal

Tap a button → capture a photo from the glasses camera mid-stream → save it to a local journal with a timestamp. The smallest useful vertical slice: registration → session → photo capture → local storage.

## Layout

- `ios/` — iOS app sources + Xcode setup steps (`SnapJournal`)
- `docs/SETUP.md` — prerequisites and Developer Center checklist
- `docs/ARCHITECTURE.md` — system design starter with open decisions

## Official docs

- [Integration overview](https://wearables.developer.meta.com/docs/develop/dat/build-overview/)
- [iOS integration guide](https://wearables.developer.meta.com/docs/develop/dat/build-integration-ios/)
- [iOS SDK + sample app](https://github.com/facebook/meta-wearables-dat-ios)
