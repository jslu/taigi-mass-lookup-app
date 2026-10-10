module Convert exposing
    ( Sentence
    , Token
    , isPunct
    , parseFenchi
    , splitSentences
    )

{-| Conversion helpers — splits text into sentences and parses the ithuan
`分詞` field into token-aligned 漢字 + Tâi-lô pairs.

Ported 1:1 from the original `convert.js`.

-}

import Regex exposing (Regex)


type alias Sentence =
    { text : String
    , paragraph : Int
    }


type alias Token =
    { han : String
    , tailo : String
    , gloss : String
    }


sentPunct : List Char
sentPunct =
    String.toList "。！？，；：!?,;:"


blankLineRegex : Regex
blankLineRegex =
    Regex.fromString "\\n\\s*\\n"
        |> Maybe.withDefault Regex.never


blankLineSplitRegex : Regex
blankLineSplitRegex =
    Regex.fromString "\\n\\s*\\n+"
        |> Maybe.withDefault Regex.never


singleNewlineSplitRegex : Regex
singleNewlineSplitRegex =
    Regex.fromString "\\n+"
        |> Maybe.withDefault Regex.never


{-| Split into sentence-units by Chinese/Latin sentence punctuation. We KEEP
the punctuation as part of the preceding sentence. Returns a list of
{ text, paragraph } — paragraph index increments on blank lines (>= 2
consecutive newlines) or on every "\\n" if the input only uses single line
breaks to separate paragraphs.
-}
splitSentences : String -> List Sentence
splitSentences text =
    if text == "" then
        []

    else
        let
            hasBlankLines =
                Regex.contains blankLineRegex text

            paraBlocks =
                if hasBlankLines then
                    Regex.split blankLineSplitRegex text

                else
                    Regex.split singleNewlineSplitRegex text
        in
        paraBlocks
            |> List.indexedMap splitBlock
            |> List.concat


splitBlock : Int -> String -> List Sentence
splitBlock pIdx block =
    let
        ( sentencesRev, buf ) =
            String.foldl (stepChar pIdx) ( [], "" ) block

        tail =
            String.trim buf

        withTail =
            if tail == "" then
                sentencesRev

            else
                { text = tail, paragraph = pIdx } :: sentencesRev
    in
    List.reverse withTail


stepChar : Int -> Char -> ( List Sentence, String ) -> ( List Sentence, String )
stepChar pIdx ch ( acc, buf ) =
    if ch == '\n' then
        ( acc, buf ++ " " )

    else
        let
            buf2 =
                buf ++ String.fromChar ch
        in
        if List.member ch sentPunct then
            let
                t =
                    String.trim buf2
            in
            if t == "" then
                ( acc, "" )

            else
                ( { text = t, paragraph = pIdx } :: acc, "" )

        else
            ( acc, buf2 )


{-| ithuan returns 分詞 as space-separated "han｜tailo" tokens, where multi-
syllable words use "-" inside both halves (e.g. "想-袂-曉｜siūnn-bē-hiáu").
Neutral-tone particles use a "--" prefix (e.g. "--的｜--ê"). For display we
strip dashes from the han side (tailo's hyphens are meaningful and stay).
-}
parseFenchi : String -> List Token
parseFenchi fenchi =
    if fenchi == "" then
        []

    else
        fenchi
            |> String.split " "
            |> List.filter (\p -> p /= "")
            |> List.map parsePiece


parsePiece : String -> Token
parsePiece piece =
    case String.split "｜" piece of
        rawHan :: tailoRest :: [] ->
            { han = String.replace "-" "" rawHan
            , tailo = tailoRest
            , gloss = ""
            }

        _ ->
            { han = String.replace "-" "" piece
            , tailo = ""
            , gloss = ""
            }


punctRegex : Regex
punctRegex =
    Regex.fromString "^[\\s。！？，；：、,.!?;:‧·…—\\-—()（）「」『』\"\"''《》]+$"
        |> Maybe.withDefault Regex.never


isPunct : Token -> Bool
isPunct token =
    Regex.contains punctRegex token.han
