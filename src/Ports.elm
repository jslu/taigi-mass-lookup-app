port module Ports exposing
    ( copyToClipboard
    , saveTweaks
    , setThemeAttribute
    )

{-| JS interop boundary. Everything the original app did via direct
`localStorage` / `navigator.clipboard` calls now crosses through here.
See `index.html` for the corresponding JS-side port wiring.

Reading the persisted preference back happens via Elm's `flags` (passed at
`Elm.Main.init`) rather than a port + subscription, since it is only ever
needed once, at startup.

-}

import Json.Encode as Encode


{-| Persist the user's layout + tone-mode + theme-mode preference.
Fire-and-forget; the JS side writes it to `localStorage` under the same key
the original app used ("taigi-mass-lookup:tweaks"), so switching branches
does not lose a user's saved preference.
-}
port saveTweaks : Encode.Value -> Cmd msg


{-| Copy arbitrary text to the clipboard via `navigator.clipboard.writeText`.
-}
port copyToClipboard : String -> Cmd msg


{-| Set the `data-theme` attribute on `<html>` to "light" or "dark", or
clear it (empty string) for System mode. This is the one bit of theme
switching Elm cannot do itself, since the mounted Elm node never includes
the `<html>` element. The CSS in `lib/unifi-tokens.css` does the rest:
`data-theme="light"` / `data-theme="dark"` force a palette, and no
attribute at all falls back to `prefers-color-scheme` (System mode) live,
with no JS listener needed.
-}
port setThemeAttribute : String -> Cmd msg
