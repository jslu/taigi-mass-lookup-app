module Tailo exposing
    ( ToneMode(..)
    , applyTone
    , diacriticWordToNumeric
    , numericWordToDiacritic
    , toToneMode
    )

{-| Tâi-lô helpers — convert between diacritic and numeric tone notation.

Tâi-lô tones 1-9 (and 0 for neutral). Tone marks go on the syllable nucleus.
Ported 1:1 from the original `tailo.js`.

-}

import Dict exposing (Dict)
import Regex exposing (Regex)


type ToneMode
    = Diacritic
    | Numeric


{-| Vowel priority for placing the tone mark in Tâi-lô (TL):

1.  "oo" -> on first 'o'
2.  a > e > o > u > i (then syllabic m / n / ng)

-}
vowelPriority : List String
vowelPriority =
    [ "a", "e", "o", "u", "i" ]


{-| tone -> diacritic char map by base vowel.

1 = unmarked, 2 = acute, 3 = grave, 4 = unmarked (entering tone, ends p/t/k/h),
5 = circumflex, 6 = caron (rare in TL), 7 = macron, 8 = vertical line above,
9 = double acute.

-}
toneMarks : Dict String (Dict Int String)
toneMarks =
    Dict.fromList
        [ ( "a", Dict.fromList [ ( 1, "a" ), ( 2, "á" ), ( 3, "à" ), ( 4, "a" ), ( 5, "â" ), ( 6, "ǎ" ), ( 7, "ā" ), ( 8, "a̍" ), ( 9, "a̋" ), ( 0, "a" ) ] )
        , ( "e", Dict.fromList [ ( 1, "e" ), ( 2, "é" ), ( 3, "è" ), ( 4, "e" ), ( 5, "ê" ), ( 6, "ě" ), ( 7, "ē" ), ( 8, "e̍" ), ( 9, "e̋" ), ( 0, "e" ) ] )
        , ( "i", Dict.fromList [ ( 1, "i" ), ( 2, "í" ), ( 3, "ì" ), ( 4, "i" ), ( 5, "î" ), ( 6, "ǐ" ), ( 7, "ī" ), ( 8, "i̍" ), ( 9, "i̋" ), ( 0, "i" ) ] )
        , ( "o", Dict.fromList [ ( 1, "o" ), ( 2, "ó" ), ( 3, "ò" ), ( 4, "o" ), ( 5, "ô" ), ( 6, "ǒ" ), ( 7, "ō" ), ( 8, "o̍" ), ( 9, "ő" ), ( 0, "o" ) ] )
        , ( "u", Dict.fromList [ ( 1, "u" ), ( 2, "ú" ), ( 3, "ù" ), ( 4, "u" ), ( 5, "û" ), ( 6, "ǔ" ), ( 7, "ū" ), ( 8, "u̍" ), ( 9, "ű" ), ( 0, "u" ) ] )
        , ( "m", Dict.fromList [ ( 1, "m" ), ( 2, "ḿ" ), ( 3, "m̀" ), ( 4, "m" ), ( 5, "m̂" ), ( 6, "m̌" ), ( 7, "m̄" ), ( 8, "m̍" ), ( 9, "m̋" ), ( 0, "m" ) ] )
        , ( "n", Dict.fromList [ ( 1, "n" ), ( 2, "ń" ), ( 3, "ǹ" ), ( 4, "n" ), ( 5, "n̂" ), ( 6, "ň" ), ( 7, "n̄" ), ( 8, "n̍" ), ( 9, "n̋" ), ( 0, "n" ) ] )
        ]


{-| Reverse map: any vowel-with-diacritic char -> ( base, tone ).
-}
reverseMarks : Dict String ( String, Int )
reverseMarks =
    toneMarks
        |> Dict.toList
        |> List.concatMap
            (\( base, byTone ) ->
                byTone
                    |> Dict.toList
                    |> List.map (\( tone, ch ) -> ( ch, ( base, tone ) ))
            )
        |> List.foldl
            (\( ch, pair ) acc ->
                if Dict.member ch acc then
                    acc

                else
                    Dict.insert ch pair acc
            )
            Dict.empty


{-| Place a tone mark in a syllable (returns diacritic form).
-}
applyTone : String -> Int -> String
applyTone syllable rawTone =
    let
        tone =
            if rawTone == 0 then
                1

            else
                rawTone

        lower =
            String.toLower syllable

        target =
            findTarget lower
    in
    case target of
        Nothing ->
            syllable

        Just idx ->
            markAt syllable idx tone


findTarget : String -> Maybe Int
findTarget lower =
    case String.indexes "oo" lower of
        idx :: _ ->
            Just idx

        [] ->
            case firstVowelIndex lower vowelPriority of
                Just idx ->
                    Just idx

                Nothing ->
                    if String.startsWith "ng" lower then
                        Just 0

                    else if lower == "m" || lower == "mh" then
                        Just 0

                    else if lower == "n" || lower == "nh" then
                        Just 0

                    else
                        Nothing


firstVowelIndex : String -> List String -> Maybe Int
firstVowelIndex lower vowels =
    case vowels of
        [] ->
            Nothing

        v :: rest ->
            case String.indexes v lower of
                idx :: _ ->
                    Just idx

                [] ->
                    firstVowelIndex lower rest


markAt : String -> Int -> Int -> String
markAt syllable idx tone =
    let
        chars =
            String.toList syllable
    in
    case List.drop idx chars |> List.head of
        Nothing ->
            syllable

        Just ch ->
            let
                base =
                    String.fromChar (Char.toLower ch)
            in
            case Dict.get base toneMarks of
                Nothing ->
                    syllable

                Just map_ ->
                    let
                        markedLower =
                            Dict.get tone map_ |> Maybe.withDefault (String.fromChar ch)

                        marked =
                            if Char.isUpper ch then
                                capitalize markedLower

                            else
                                markedLower

                        before =
                            String.left idx syllable

                        after =
                            String.dropLeft (idx + 1) syllable
                    in
                    before ++ marked ++ after


capitalize : String -> String
capitalize s =
    case String.uncons s of
        Nothing ->
            s

        Just ( first, rest ) ->
            String.cons (Char.toUpper first) rest


{-| Convert a numeric-tailo syllable like "thau5" -> "thâu".
-}
numericSyllableToDiacritic : String -> String
numericSyllableToDiacritic syl =
    case Regex.find numericSyllableRegex syl of
        [ match ] ->
            case match.submatches of
                [ Just base, Just toneStr ] ->
                    case String.toInt toneStr of
                        Just tone ->
                            applyTone base tone

                        Nothing ->
                            syl

                _ ->
                    syl

        _ ->
            syl


numericSyllableRegex : Regex
numericSyllableRegex =
    Regex.fromString "^([A-Za-z'-]+?)([0-9])$"
        |> Maybe.withDefault Regex.never


numericSyllableFullRegex : Regex
numericSyllableFullRegex =
    Regex.fromString "^[A-Za-z'-]+\\d$"
        |> Maybe.withDefault Regex.never


{-| Convert a numeric-tailo word with hyphens, e.g. "lo2-pe7" -> "ló-pē".
-}
numericWordToDiacritic : String -> String
numericWordToDiacritic word =
    splitKeepSeparators word
        |> List.map
            (\part ->
                if Regex.contains numericSyllableFullRegex part then
                    numericSyllableToDiacritic part

                else
                    part
            )
        |> String.concat


{-| Split on "-", "·", "‧" while keeping the separators as their own pieces.
-}
splitKeepSeparators : String -> List String
splitKeepSeparators word =
    Regex.find separatorRegex word
        |> List.foldl
            (\match ( lastEnd, acc ) ->
                let
                    before =
                        String.slice lastEnd match.index word
                in
                ( match.index + String.length match.match
                , match.match :: (if before == "" then acc else before :: acc)
                )
            )
            ( 0, [] )
        |> (\( lastEnd, acc ) ->
                let
                    tail =
                        String.dropLeft lastEnd word
                in
                List.reverse
                    (if tail == "" then
                        acc

                     else
                        tail :: acc
                    )
           )


separatorRegex : Regex
separatorRegex =
    Regex.fromString "-|·|‧"
        |> Maybe.withDefault Regex.never


{-| Map of bare combining diacritic marks (as used on consonants like m/n,
which have no precomposed codepoint for circumflex/macron/etc.) to the tone
they represent. Mirrors the decomposition fallback in the original
`diacriticSyllableToNumeric` in tailo.js.
-}
combiningMarkTones : Dict Char Int
combiningMarkTones =
    Dict.fromList
        [ ( '\u{0301}', 2 ) -- acute
        , ( '\u{0300}', 3 ) -- grave
        , ( '\u{0302}', 5 ) -- circumflex
        , ( '\u{0304}', 7 ) -- macron
        , ( '\u{030D}', 8 ) -- vertical line above
        , ( '\u{030B}', 9 ) -- double acute
        ]


{-| Strip diacritic from a syllable, return ( base, tone ).

Most vowels (a/e/i/o/u) have precomposed tone-marked codepoints, handled via
`reverseMarks`. Some consonants (m/n) only carry a *bare combining* diacritic
mark with no precomposed form (e.g. "n̂" = 'n' + U+0302) — those fall through
to `combiningMarkTones` instead of being appended to the base string.

-}
diacriticSyllableToNumeric : String -> ( String, Int )
diacriticSyllableToNumeric syl =
    let
        ( base, tone ) =
            String.foldl
                (\ch ( b, t ) ->
                    let
                        chStr =
                            String.fromChar ch
                    in
                    case Dict.get chStr reverseMarks of
                        Just ( markBase, markTone ) ->
                            ( b ++ markBase, markTone )

                        Nothing ->
                            case Dict.get ch combiningMarkTones of
                                Just markTone ->
                                    ( b, markTone )

                                Nothing ->
                                    ( b ++ chStr, t )
                )
                ( "", 1 )
                syl

        endsInStop =
            String.endsWith "p" base
                || String.endsWith "t" base
                || String.endsWith "k" base
                || String.endsWith "h" base
    in
    if endsInStop && tone == 1 then
        ( base, 4 )

    else
        ( base, tone )


diacriticCharClassRegex : Regex
diacriticCharClassRegex =
    Regex.fromString "[A-Za-zàáâāǎèéêēěìíîīǐòóôōǒùúûūǔńňǹḿ]"
        |> Maybe.withDefault Regex.never


{-| Convert a diacritic word to numeric: "thâu-mn̂g" -> "thau5-mng5".
-}
diacriticWordToNumeric : String -> String
diacriticWordToNumeric word =
    splitKeepSeparators word
        |> List.map
            (\part ->
                if part == "-" || part == "·" || part == "‧" then
                    part

                else if Regex.contains diacriticCharClassRegex part && String.length part >= 1 then
                    let
                        ( base, tone ) =
                            diacriticSyllableToNumeric part
                    in
                    base ++ String.fromInt tone

                else
                    part
            )
        |> String.concat


numericWordRegex : Regex
numericWordRegex =
    Regex.fromString "[A-Za-z'-]+\\d(?:-[A-Za-z'-]+\\d)*"
        |> Maybe.withDefault Regex.never


diacriticWordRegex : Regex
diacriticWordRegex =
    Regex.fromString "[A-Za-zàáâāǎèéêēěìíîīǐòóôōǒùúûūǔńňǹḿ'-]+"
        |> Maybe.withDefault Regex.never


alreadyNumericRegex : Regex
alreadyNumericRegex =
    Regex.fromString "^[A-Za-z'-]+\\d(?:-[A-Za-z'-]+\\d)*$"
        |> Maybe.withDefault Regex.never


{-| Apply tone mode to a tâi-lô string (whole sentence or word).
-}
toToneMode : String -> ToneMode -> String
toToneMode tailo mode =
    if tailo == "" then
        tailo

    else
        case mode of
            Numeric ->
                Regex.replace diacriticWordRegex
                    (\match ->
                        if Regex.contains alreadyNumericRegex match.match then
                            match.match

                        else
                            diacriticWordToNumeric match.match
                    )
                    tailo

            Diacritic ->
                Regex.replace numericWordRegex
                    (\match -> numericWordToDiacritic match.match)
                    tailo
