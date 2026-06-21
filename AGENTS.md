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
