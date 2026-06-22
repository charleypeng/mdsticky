# Project Rules

## Language
- All code, identifiers, strings, and comments must use **English**
- User-facing text goes through `tr("key")` for i18n
- Add translations to `Localizable.xcstrings`

## i18n
- Every user-visible string must be wrapped in `tr("English text")`
- Corresponding entries must exist in `Localizable.xcstrings` with `en` and `zh-Hans` translations
- Never hardcode Chinese text in `.swift` files
- `tr()` function loads from the correct `.lproj` bundle at runtime

## Release
- Build unsigned DMG to avoid macOS "developer cannot be verified" prompt:
  ```
  xcodebuild -project mdsticky/mdsticky.xcodeproj -scheme mdsticky -configuration Release build CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO
  ```
- Create DMG with `hdiutil`:
  ```
  hdiutil create bin/mdsticky-{version}.dmg -volname "mdsticky-{version}" -srcfolder {tmpdir} -ov -format UDZO
  ```
