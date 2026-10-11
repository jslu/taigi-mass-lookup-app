module Tokens exposing
    ( Layout(..)
    , ThemeMode(..)
    , layoutFromString
    , layoutToString
    , themeModeFromString
    , themeModeToString
    , toneModeFromString
    , toneModeToString
    )

{-| String <-> type conversions for the user-facing preference enums
(layout choice, tone display mode, theme mode). Kept separate from `Main`
so both the model decoder (ports/flags) and the view can share them.
-}

import Tailo exposing (ToneMode(..))


type Layout
    = Ruby
    | Stacked
    | Side
    | Table


layoutToString : Layout -> String
layoutToString layout =
    case layout of
        Ruby ->
            "ruby"

        Stacked ->
            "stacked"

        Side ->
            "side"

        Table ->
            "table"


layoutFromString : String -> Layout
layoutFromString s =
    case s of
        "stacked" ->
            Stacked

        "side" ->
            Side

        "table" ->
            Table

        _ ->
            Ruby


toneModeToString : ToneMode -> String
toneModeToString mode =
    case mode of
        Diacritic ->
            "diacritic"

        Numeric ->
            "numeric"


toneModeFromString : String -> ToneMode
toneModeFromString s =
    case s of
        "numeric" ->
            Numeric

        _ ->
            Diacritic


type ThemeMode
    = Light
    | Dark
    | SystemTheme


themeModeToString : ThemeMode -> String
themeModeToString mode =
    case mode of
        Light ->
            "light"

        Dark ->
            "dark"

        SystemTheme ->
            "system"


themeModeFromString : String -> ThemeMode
themeModeFromString s =
    case s of
        "light" ->
            Light

        "dark" ->
            Dark

        _ ->
            SystemTheme
