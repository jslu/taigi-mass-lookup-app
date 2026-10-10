module Main exposing (main)

import Browser
import Convert exposing (Sentence, Token)
import Dict exposing (Dict)
import Html exposing (Html, button, div, h1, h3, header, p, span, text, textarea)
import Html.Attributes as Attr exposing (class, disabled, placeholder, style)
import Html.Events exposing (onClick, onInput, onMouseEnter, onMouseLeave)
import Html.Keyed
import Http
import Json.Decode as Decode exposing (Decoder)
import Json.Encode as Encode
import Ports
import Process
import Tailo exposing (ToneMode(..))
import Task
import Tokens exposing (Layout(..))
import Url



-- MODEL


type RemoteTokens
    = Loading
    | Loaded (List Token)
    | Failed String


type alias Selection =
    { key : String
    , token : Token
    }


type alias Model =
    { text : String
    , submitted : String
    , sentences : List Sentence
    , tokensBySentence : Dict String RemoteTokens
    , pendingParagraphs : List (List Sentence)
    , currentBatch : List String
    , activeIdx : Int
    , layout : Layout
    , toneMode : ToneMode
    , selected : Maybe Selection
    , copiedAll : Bool
    , copiedLineIdx : Maybe Int
    }


sample : String
sample =
    "街仔底總仔共仔兩間福州人開ê剃頭店，頭到hit間號做「明星」，是我一个查某同學ê老爸開--ê，另外一間khah遠--ê叫做「萬國」。Kám是囡仔人lóng小面神mā有淡薄仔pì-sù ê款，頭改阿母hiàm我出去外口剪頭鬃，明其知khah遠mā是行去「萬國」hia交關。差不多beh收尾ê時，剃頭師傅問我頂頭beh拍khah薄--無？Tùn-tenn兩、三秒我tsiah應好；論真我家己mā m̄知影啥mi̍h號做拍薄。"


init : Decode.Value -> ( Model, Cmd Msg )
init storedTweaks =
    let
        ( layout, toneMode ) =
            decodeTweaks storedTweaks
    in
    ( { text = ""
      , submitted = ""
      , sentences = []
      , tokensBySentence = Dict.empty
      , pendingParagraphs = []
      , currentBatch = []
      , activeIdx = -1
      , layout = layout
      , toneMode = toneMode
      , selected = Nothing
      , copiedAll = False
      , copiedLineIdx = Nothing
      }
    , Cmd.none
    )


decodeTweaks : Decode.Value -> ( Layout, ToneMode )
decodeTweaks value =
    let
        layout =
            Decode.decodeValue (Decode.field "layout" Decode.string) value
                |> Result.map Tokens.layoutFromString
                |> Result.withDefault Ruby

        toneMode =
            Decode.decodeValue (Decode.field "toneMode" Decode.string) value
                |> Result.map Tokens.toneModeFromString
                |> Result.withDefault Diacritic
    in
    ( layout, toneMode )



-- UPDATE


type Msg
    = TextChanged String
    | Submit
    | LoadSample
    | Clear
    | TaskKeyDown Bool Bool String
    | SetLayout Layout
    | SetToneMode ToneMode
    | GotTokens String (Result Http.Error (List Token))
    | ActivateRow Int
    | DeactivateRows
    | WordClicked String Token
    | ClosePopover
    | CopyAll
    | CopyAllDone
    | CopyLine Int
    | CopyLineDone Int
    | RetrySentence String


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        TextChanged s ->
            ( { model | text = s }, Cmd.none )

        TaskKeyDown ctrlOrMeta _ key ->
            if ctrlOrMeta && key == "Enter" then
                update Submit model

            else
                ( model, Cmd.none )

        Submit ->
            submit model

        LoadSample ->
            if model.text == "" then
                ( { model | text = sample }, Cmd.none )

            else
                ( model, Cmd.none )

        Clear ->
            ( { model
                | text = ""
                , submitted = ""
                , activeIdx = -1
                , sentences = []
              }
            , Cmd.none
            )

        SetLayout layout ->
            ( { model | layout = layout }, saveTweaksCmd layout model.toneMode )

        SetToneMode toneMode ->
            ( { model | toneMode = toneMode }, saveTweaksCmd model.layout toneMode )

        GotTokens sentence result ->
            let
                remote =
                    case result of
                        Ok toks ->
                            Loaded toks

                        Err err ->
                            Failed (httpErrorToString err)

                stillWaiting =
                    List.filter (\t -> t /= sentence) model.currentBatch

                model1 =
                    { model
                        | tokensBySentence = Dict.insert sentence remote model.tokensBySentence
                        , currentBatch = stillWaiting
                    }
            in
            if List.isEmpty stillWaiting then
                startNextBatch model1

            else
                ( model1, Cmd.none )

        ActivateRow idx ->
            ( { model | activeIdx = idx }, Cmd.none )

        DeactivateRows ->
            ( { model | activeIdx = -1 }, Cmd.none )

        WordClicked key token ->
            ( { model | selected = Just { key = key, token = token } }, Cmd.none )

        ClosePopover ->
            ( { model | selected = Nothing }, Cmd.none )

        CopyAll ->
            ( { model | copiedAll = True }
            , Cmd.batch [ copyAllCmd model, resetAfter 1600 CopyAllDone ]
            )

        CopyAllDone ->
            ( { model | copiedAll = False }, Cmd.none )

        CopyLine idx ->
            case List.drop idx model.sentences |> List.head of
                Nothing ->
                    ( model, Cmd.none )

                Just sentence ->
                    case Dict.get sentence.text model.tokensBySentence of
                        Just (Loaded toks) ->
                            ( { model | copiedLineIdx = Just idx }
                            , Cmd.batch
                                [ Ports.copyToClipboard (lineText toks model.toneMode)
                                , resetAfter 1400 (CopyLineDone idx)
                                ]
                            )

                        _ ->
                            ( model, Cmd.none )

        CopyLineDone idx ->
            if model.copiedLineIdx == Just idx then
                ( { model | copiedLineIdx = Nothing }, Cmd.none )

            else
                ( model, Cmd.none )

        RetrySentence sentence ->
            ( { model | tokensBySentence = Dict.insert sentence Loading model.tokensBySentence }
            , fetchTokens sentence
            )


{-| Split the submitted text into sentences, then fetch them one paragraph
at a time: all sentences belonging to the first paragraph are requested
concurrently, and the next paragraph's batch only starts once every
sentence in the current batch has settled (loaded or failed). Already-
converted sentences (e.g. re-submitting text that shares a prefix with a
prior submission) are skipped and don't block their paragraph's batch.
-}
submit : Model -> ( Model, Cmd Msg )
submit model =
    let
        sentences =
            Convert.splitSentences model.text

        paragraphs =
            Convert.groupByParagraph sentences

        isNew s =
            not (Dict.member s.text model.tokensBySentence)

        pendingParagraphs =
            paragraphs
                |> List.map (List.filter isNew)
                |> List.filter (not << List.isEmpty)
    in
    startNextBatch
        { model
            | submitted = model.text
            , sentences = sentences
            , pendingParagraphs = pendingParagraphs
            , currentBatch = []
            , activeIdx = -1
        }


{-| Pop the next paragraph's sentences off the queue, mark them `Loading`,
and fire their HTTP requests concurrently. If the queue is empty (all
paragraphs have been dispatched already), this is a no-op.
-}
startNextBatch : Model -> ( Model, Cmd Msg )
startNextBatch model =
    case model.pendingParagraphs of
        [] ->
            ( model, Cmd.none )

        batch :: rest ->
            let
                keys =
                    List.map .text batch

                tokensBySentence =
                    List.foldl (\key d -> Dict.insert key Loading d) model.tokensBySentence keys

                cmd =
                    Cmd.batch (List.map fetchTokens keys)
            in
            ( { model
                | pendingParagraphs = rest
                , currentBatch = keys
                , tokensBySentence = tokensBySentence
              }
            , cmd
            )


saveTweaksCmd : Layout -> ToneMode -> Cmd Msg
saveTweaksCmd layout toneMode =
    Ports.saveTweaks
        (Encode.object
            [ ( "layout", Encode.string (Tokens.layoutToString layout) )
            , ( "toneMode", Encode.string (Tokens.toneModeToString toneMode) )
            ]
        )


resetAfter : Float -> Msg -> Cmd Msg
resetAfter ms msg =
    Process.sleep ms |> Task.perform (\_ -> msg)


copyAllCmd : Model -> Cmd Msg
copyAllCmd model =
    let
        lines =
            buildCopyAllLines model.sentences model.tokensBySentence model.toneMode
    in
    Ports.copyToClipboard (String.join "\n\n" lines)


buildCopyAllLines : List Sentence -> Dict String RemoteTokens -> ToneMode -> List String
buildCopyAllLines sentences tokensBySentence toneMode =
    let
        step sentence ( prevPara, acc ) =
            let
                paraBreak =
                    if prevPara /= Just sentence.paragraph && prevPara /= Nothing then
                        [ "" ]

                    else
                        []

                line =
                    case Dict.get sentence.text tokensBySentence of
                        Just (Loaded toks) ->
                            lineText toks toneMode

                        _ ->
                            sentence.text
            in
            ( Just sentence.paragraph, acc ++ paraBreak ++ [ line ] )
    in
    sentences
        |> List.foldl step ( Nothing, [] )
        |> Tuple.second


lineText : List Token -> ToneMode -> String
lineText tokens toneMode =
    let
        han =
            tokens |> List.map .han |> String.concat

        romaji =
            tokens
                |> List.map
                    (\t ->
                        if Convert.isPunct t then
                            t.han

                        else
                            Tailo.toToneMode t.tailo toneMode
                    )
                |> String.join " "
                |> collapsePunctSpacing
                |> String.trim
    in
    han ++ "\n" ++ romaji


{-| Mirrors the original's `.replace(/\s+([，。！？；：])/g, '$1')` —
collapse a space that precedes full-width sentence punctuation.
-}
collapsePunctSpacing : String -> String
collapsePunctSpacing s =
    String.foldr
        (\ch acc ->
            case acc of
                ' ' :: rest ->
                    if isFullWidthPunct ch then
                        ch :: rest

                    else
                        ch :: ' ' :: rest

                _ ->
                    ch :: acc
        )
        []
        s
        |> String.fromList


isFullWidthPunct : Char -> Bool
isFullWidthPunct ch =
    List.member ch [ '，', '。', '！', '？', '；', '：' ]


fetchTokens : String -> Cmd Msg
fetchTokens sentence =
    Http.post
        { url = "/api/tau"
        , body = Http.stringBody "application/x-www-form-urlencoded" ("taibun=" ++ percentEncode sentence)
        , expect = Http.expectJson (GotTokens sentence) tokensDecoder
        }


percentEncode : String -> String
percentEncode =
    Url.percentEncode


tokensDecoder : Decoder (List Token)
tokensDecoder =
    Decode.field "分詞" Decode.string
        |> Decode.map Convert.parseFenchi


httpErrorToString : Http.Error -> String
httpErrorToString err =
    case err of
        Http.BadUrl u ->
            "Bad URL: " ++ u

        Http.Timeout ->
            "Conversion failed (timeout)"

        Http.NetworkError ->
            "Conversion failed (network error)"

        Http.BadStatus code ->
            "Conversion failed (" ++ String.fromInt code ++ ")"

        Http.BadBody body ->
            "Conversion failed: " ++ body



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.none



-- VIEW


view : Model -> Html Msg
view model =
    div [ class "app-shell" ]
        [ viewHeader
        , viewInputCard model
        , viewResultsOrEmpty model
        , viewFootNote
        ]


viewHeader : Html Msg
viewHeader =
    header [ class "app-header" ]
        [ div []
            [ h1 [ class "app-title" ]
                [ span [] [ text "Taigi" ]
                , text " "
                , span [ class "accent" ] [ text "Mass Lookup" ]
                ]
            , div [ class "app-subtitle" ]
                [ text "Paste any 台語文 passage — get sentence-by-sentence 漢字 ↔ Tâi-lô." ]
            ]
        , div [ class "brand-mark" ] [ text "台羅 · Hàn-lô" ]
        ]


viewInputCard : Model -> Html Msg
viewInputCard model =
    let
        charCount =
            String.length model.text
    in
    div [ class "input-card" ]
        [ div [ class "input-toolbar" ]
            [ div [ class "input-toolbar-left" ]
                [ span [ class "dot" ] []
                , span [] [ text "Source text" ]
                ]
            , div [ class "input-toolbar-right" ]
                [ button
                    [ class "btn btn-ghost"
                    , onClick LoadSample
                    , disabled (model.text /= "")
                    ]
                    [ text "Load sample" ]
                , button
                    [ class "btn btn-ghost"
                    , onClick Clear
                    , disabled (model.text == "" && model.submitted == "")
                    ]
                    [ text "Clear" ]
                ]
            ]
        , textarea
            [ class "taigi-input taigi-text"
            , placeholder "貼一篇台語文（漢字、Tâi-lô，抑是 Hàn-lô 攏會使）⋯"
            , Attr.value model.text
            , onInput TextChanged
            ]
            []
        , div [ class "input-footer" ]
            [ div []
                [ if charCount > 0 then
                    text (formatCount charCount ++ " characters")

                  else
                    text "Tip: ⌘/Ctrl + Enter to convert"
                ]
            , div [ style "display" "flex", style "gap" "8px" ]
                [ button
                    [ class "btn btn-primary btn-large"
                    , onClick Submit
                    , disabled (String.trim model.text == "" || model.text == model.submitted)
                    ]
                    [ text "Convert" ]
                ]
            ]
        ]


formatCount : Int -> String
formatCount n =
    String.fromInt n


viewResultsOrEmpty : Model -> Html Msg
viewResultsOrEmpty model =
    let
        sentenceCount =
            List.length model.sentences
    in
    if sentenceCount > 0 then
        viewResults model

    else if model.submitted == "" then
        viewEmptyState

    else
        text ""


viewResults : Model -> Html Msg
viewResults model =
    let
        sentenceCount =
            List.length model.sentences
    in
    div []
        [ div [ class "results-meta" ]
            [ span []
                [ span [ class "count" ] [ text (String.fromInt sentenceCount) ]
                , text (" sentence" ++ pluralSuffix sentenceCount)
                ]
            , span [ class "divider" ] []
            , button [ class "btn btn-secondary", onClick CopyAll ]
                [ text
                    (if model.copiedAll then
                        "Copied!"

                     else
                        "Copy all"
                    )
                ]
            ]
        , viewResultsControls model
        , Html.Keyed.node "div"
            [ class "results-list", onMouseLeave DeactivateRows ]
            (viewSentenceRows model)
        ]


pluralSuffix : Int -> String
pluralSuffix n =
    if n > 1 then
        "s"

    else
        ""


viewResultsControls : Model -> Html Msg
viewResultsControls model =
    div [ class "results-controls" ]
        [ segToggle "Layout"
            (Tokens.layoutToString model.layout)
            [ ( "ruby", "Ruby", SetLayout Ruby )
            , ( "stacked", "Stacked", SetLayout Stacked )
            , ( "side", "Side", SetLayout Side )
            , ( "table", "Table", SetLayout Table )
            ]
        , segToggle "Tone"
            (Tokens.toneModeToString model.toneMode)
            [ ( "diacritic", "â ē í", SetToneMode Diacritic )
            , ( "numeric", "a5 e7 i2", SetToneMode Numeric )
            ]
        ]


segToggle : String -> String -> List ( String, String, Msg ) -> Html Msg
segToggle label currentValue options =
    div [ class "results-control" ]
        [ span [ class "results-control-label" ] [ text label ]
        , div [ class "seg-toggle", Attr.attribute "role" "radiogroup", Attr.attribute "aria-label" label ]
            (options
                |> List.map
                    (\( value, optLabel, msg ) ->
                        button
                            [ Attr.attribute "role" "radio"
                            , Attr.attribute "aria-checked" (boolToString (currentValue == value))
                            , class
                                (if currentValue == value then
                                    "is-active"

                                 else
                                    ""
                                )
                            , onClick msg
                            ]
                            [ text optLabel ]
                    )
            )
        ]


boolToString : Bool -> String
boolToString b =
    if b then
        "true"

    else
        "false"


viewSentenceRows : Model -> List ( String, Html Msg )
viewSentenceRows model =
    model.sentences
        |> List.indexedMap Tuple.pair
        |> List.concatMap
            (\( i, s ) ->
                let
                    prev =
                        List.drop (i - 1) model.sentences |> List.head

                    isParaBreak =
                        case prev of
                            Just p ->
                                p.paragraph /= s.paragraph

                            Nothing ->
                                False

                    breakNode =
                        if isParaBreak then
                            [ ( "break-" ++ String.fromInt i, viewParagraphBreak ) ]

                        else
                            []
                in
                breakNode
                    ++ [ ( String.fromInt i ++ ":" ++ String.left 12 s.text
                         , viewSentenceRow model i s
                         )
                       ]
            )


viewParagraphBreak : Html Msg
viewParagraphBreak =
    div [ class "paragraph-break", Attr.attribute "aria-hidden" "true" ]
        [ span [ class "pb-line" ] []
        , span [ class "pb-mark" ]
            [ span [ class "pb-pilcrow" ] [ text "¶" ]
            , span [] [ text "New paragraph" ]
            ]
        , span [ class "pb-line" ] []
        ]


viewSentenceRow : Model -> Int -> Sentence -> Html Msg
viewSentenceRow model idx sentence =
    let
        isActive =
            model.activeIdx == idx

        remote =
            Dict.get sentence.text model.tokensBySentence
    in
    div
        [ class ("sentence-row" ++ activeClassSuffix isActive)
        , onMouseEnter (ActivateRow idx)
        ]
        [ div [ class "row-index" ] [ text (padIndex idx) ]
        , viewRowBody model idx sentence remote
        , div [ class "row-actions" ]
            [ button
                [ class
                    ("icon-btn"
                        ++ (if model.copiedLineIdx == Just idx then
                                " copied"

                            else
                                ""
                           )
                    )
                , onClick (CopyLine idx)
                , Attr.title "Copy this line"
                , Attr.attribute "aria-label" "Copy"
                ]
                [ text
                    (if model.copiedLineIdx == Just idx then
                        "✓"

                     else
                        "⧉"
                    )
                ]
            ]
        , viewPopoverFor model idx remote
        ]


activeClassSuffix : Bool -> String
activeClassSuffix isActive =
    if isActive then
        " is-active"

    else
        ""


padIndex : Int -> String
padIndex idx =
    let
        n =
            String.fromInt (idx + 1)
    in
    if String.length n < 2 then
        "0" ++ n

    else
        n


viewRowBody : Model -> Int -> Sentence -> Maybe RemoteTokens -> Html Msg
viewRowBody model idx sentence remote =
    case remote of
        Nothing ->
            viewConvertingRow sentence

        Just Loading ->
            viewConvertingRow sentence

        Just (Failed err) ->
            viewErrorRow sentence err

        Just (Loaded tokens) ->
            viewLayout model idx tokens


viewConvertingRow : Sentence -> Html Msg
viewConvertingRow sentence =
    div []
        [ div [ class "row-status" ]
            [ span [ class "pulse" ] []
            , span [] [ text "Converting…" ]
            ]
        , div
            [ class "taigi-text"
            , style "font-size" "19px"
            , style "line-height" "32px"
            , style "color" "var(--text-02)"
            ]
            [ text sentence.text ]
        ]


viewErrorRow : Sentence -> String -> Html Msg
viewErrorRow sentence _ =
    div []
        [ div [ class "row-status error" ]
            [ span [ class "pulse" ] []
            , span [] [ text "Couldn't convert this sentence." ]
            , button
                [ class "btn btn-ghost"
                , style "height" "22px"
                , style "padding" "0 8px"
                , style "font-size" "11px"
                , style "margin-left" "8px"
                , onClick (RetrySentence sentence.text)
                ]
                [ text "Retry" ]
            ]
        , div [ class "taigi-text", style "font-size" "19px", style "line-height" "32px" ]
            [ text sentence.text ]
        ]


viewLayout : Model -> Int -> List Token -> Html Msg
viewLayout model lineIdx tokens =
    case model.layout of
        Ruby ->
            viewRubyLine model lineIdx tokens

        Stacked ->
            viewStackedLine model lineIdx tokens

        Side ->
            viewSideLine model lineIdx tokens

        Table ->
            viewTableLine model.toneMode tokens


tokenKey : Int -> Int -> String
tokenKey lineIdx i =
    String.fromInt lineIdx ++ "-" ++ String.fromInt i


isSelected : Model -> String -> Bool
isSelected model key =
    case model.selected of
        Just sel ->
            sel.key == key

        Nothing ->
            False


viewRubyLine : Model -> Int -> List Token -> Html Msg
viewRubyLine model lineIdx tokens =
    div [ class "ruby-line taigi-text" ]
        (tokens
            |> List.indexedMap
                (\i t ->
                    let
                        key =
                            tokenKey lineIdx i

                        punct =
                            Convert.isPunct t

                        tailo =
                            Tailo.toToneMode t.tailo model.toneMode

                        classes =
                            "ruby-token"
                                ++ (if punct then
                                        " punct"

                                    else
                                        ""
                                   )
                                ++ (if isSelected model key then
                                        " is-selected"

                                    else
                                        ""
                                   )

                        clickAttrs =
                            if punct then
                                []

                            else
                                [ onClick (WordClicked key t) ]
                    in
                    span (class classes :: clickAttrs)
                        [ span [ class "ruby-romaji" ]
                            [ text
                                (if tailo /= "" then
                                    tailo

                                 else if punct then
                                    ""

                                 else
                                    "\u{00A0}"
                                )
                            ]
                        , span [ class "ruby-han taigi-text" ] [ text t.han ]
                        ]
                )
        )


viewStackedLine : Model -> Int -> List Token -> Html Msg
viewStackedLine model lineIdx tokens =
    div [ class "stacked-line" ]
        [ div [ class "stacked-han taigi-text" ]
            (tokens
                |> List.indexedMap
                    (\i t ->
                        let
                            key =
                                tokenKey lineIdx i

                            punct =
                                Convert.isPunct t

                            classes =
                                "stacked-token"
                                    ++ (if punct then
                                            " punct"

                                        else
                                            ""
                                       )
                                    ++ (if isSelected model key then
                                            " is-selected"

                                        else
                                            ""
                                       )

                            clickAttrs =
                                if punct then
                                    []

                                else
                                    [ onClick (WordClicked key t) ]
                        in
                        span (class classes :: clickAttrs) [ text t.han ]
                    )
            )
        , div [ class "stacked-romaji" ]
            (tokens
                |> List.indexedMap
                    (\i t ->
                        let
                            key =
                                tokenKey lineIdx i

                            punct =
                                Convert.isPunct t

                            tailo =
                                Tailo.toToneMode t.tailo model.toneMode
                        in
                        if punct then
                            span [ class "stacked-token punct" ] [ text t.han ]

                        else
                            span
                                [ class
                                    ("stacked-token"
                                        ++ (if isSelected model key then
                                                " is-selected"

                                            else
                                                ""
                                           )
                                    )
                                , onClick (WordClicked key t)
                                ]
                                [ text
                                    (if tailo /= "" then
                                        tailo

                                     else
                                        "·"
                                    )
                                ]
                    )
            )
        ]


viewSideLine : Model -> Int -> List Token -> Html Msg
viewSideLine model lineIdx tokens =
    div [ class "side-line" ]
        [ div [ class "side-col-han taigi-text" ]
            (tokens
                |> List.indexedMap
                    (\i t ->
                        let
                            key =
                                tokenKey lineIdx i

                            punct =
                                Convert.isPunct t

                            classes =
                                "side-token"
                                    ++ (if punct then
                                            " punct"

                                        else
                                            ""
                                       )
                                    ++ (if isSelected model key then
                                            " is-selected"

                                        else
                                            ""
                                       )

                            clickAttrs =
                                if punct then
                                    []

                                else
                                    [ onClick (WordClicked key t) ]
                        in
                        span (class classes :: clickAttrs) [ text t.han ]
                    )
            )
        , div [ class "side-col-romaji" ]
            (tokens
                |> List.indexedMap
                    (\i t ->
                        let
                            key =
                                tokenKey lineIdx i

                            punct =
                                Convert.isPunct t

                            tailo =
                                Tailo.toToneMode t.tailo model.toneMode
                        in
                        if punct then
                            span [ class "side-token punct" ] [ text t.han ]

                        else
                            span
                                [ class
                                    ("side-token"
                                        ++ (if isSelected model key then
                                                " is-selected"

                                            else
                                                ""
                                           )
                                    )
                                , onClick (WordClicked key t)
                                ]
                                [ text
                                    (if tailo /= "" then
                                        tailo

                                     else
                                        "·"
                                    )
                                ]
                    )
            )
        ]


viewTableLine : ToneMode -> List Token -> Html Msg
viewTableLine toneMode tokens =
    let
        han =
            tokens |> List.map .han |> String.concat

        romaji =
            tokens
                |> List.map
                    (\t ->
                        if Convert.isPunct t then
                            t.han

                        else
                            let
                                tl =
                                    Tailo.toToneMode t.tailo toneMode
                            in
                            if tl /= "" then
                                tl

                            else
                                "·"
                    )
                |> String.join " "
                |> collapsePunctSpacing
    in
    div [ class "table-line" ]
        [ div [ class "table-row" ]
            [ div [ class "table-label" ] [ text "漢字" ]
            , div [ class "table-cell taigi-text" ] [ text han ]
            ]
        , div [ class "table-row" ]
            [ div [ class "table-label" ] [ text "Tâi-lô" ]
            , div [ class "table-cell romaji" ] [ text romaji ]
            ]
        ]


viewPopoverFor : Model -> Int -> Maybe RemoteTokens -> Html Msg
viewPopoverFor model idx remote =
    case model.selected of
        Nothing ->
            text ""

        Just sel ->
            if String.startsWith (String.fromInt idx ++ "-") sel.key then
                viewPopover model.toneMode sel

            else
                text ""


viewPopover : ToneMode -> Selection -> Html Msg
viewPopover toneMode sel =
    div [ class "word-popover" ]
        [ div [ class "pop-han taigi-text" ] [ text sel.token.han ]
        , div [ class "pop-romaji" ]
            [ text
                (if sel.token.tailo /= "" then
                    Tailo.toToneMode sel.token.tailo toneMode

                 else
                    "—"
                )
            ]
        , div [ class "pop-divider" ] []
        , div [ class "pop-gloss-label" ] [ text "Meaning" ]
        , div [ class "pop-gloss pop-stub" ] [ text "No detailed lookup yet." ]
        ]


viewEmptyState : Html Msg
viewEmptyState =
    div [ class "empty-state" ]
        [ div [ class "es-icon" ] [ text "≡" ]
        , h3 [] [ text "No text yet" ]
        , p []
            [ text "Paste a Taigi passage above and press Convert. Each sentence will appear below with aligned 漢字 and Tâi-lô. Click any word to see its 漢字 and Tâi-lô." ]
        ]


viewFootNote : Html Msg
viewFootNote =
    div [ class "foot-note" ]
        [ text "Tâi-lô (台羅) is the Ministry of Education's romanization system for Taiwanese Hokkien. Conversions are provided by the "
        , Html.a [ Attr.href "https://suisiann.ithuan.tw/", Attr.target "_blank", Attr.rel "noreferrer" ]
            [ text "意傳科技 ithuan" ]
        , text " 「台文音讀網」 service — verify with a dictionary for important uses."
        ]



-- MAIN


main : Program Decode.Value Model Msg
main =
    Browser.element
        { init = init
        , update = update
        , view = view
        , subscriptions = subscriptions
        }
