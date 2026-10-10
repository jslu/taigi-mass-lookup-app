module Tokens exposing
    ( Layout(..)
    , layoutFromString
    , layoutToString
    , toneModeFromString
    , toneModeToString
    )

{-| String <-> type conversions for the two user-facing preference enums
(layout choice, tone display mode). Kept separate from `Main` so both the
model decoder (ports) and the view can share them.
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
