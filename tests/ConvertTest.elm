module ConvertTest exposing (suite)

import Convert
import Expect
import Test exposing (Test, describe, test)


suite : Test
suite =
    describe "Convert"
        [ describe "splitSentences"
            [ test "empty string yields no sentences" <|
                \_ -> Convert.splitSentences "" |> Expect.equal []
            , test "single sentence with trailing punctuation" <|
                \_ ->
                    Convert.splitSentences "食飯未？"
                        |> Expect.equal [ { text = "食飯未？", paragraph = 0 } ]
            , test "splits multiple sentences in one paragraph" <|
                \_ ->
                    Convert.splitSentences "食飯未？好ah。"
                        |> Expect.equal
                            [ { text = "食飯未？", paragraph = 0 }
                            , { text = "好ah。", paragraph = 0 }
                            ]
            , test "keeps trailing text without punctuation" <|
                \_ ->
                    Convert.splitSentences "食飯未"
                        |> Expect.equal [ { text = "食飯未", paragraph = 0 } ]
            , test "blank-line separated blocks bump the paragraph index" <|
                \_ ->
                    Convert.splitSentences "第一段。\n\n第二段。"
                        |> Expect.equal
                            [ { text = "第一段。", paragraph = 0 }
                            , { text = "第二段。", paragraph = 1 }
                            ]
            , test "single-newline separated lines each bump the paragraph index when there are no blank lines" <|
                \_ ->
                    Convert.splitSentences "第一行\n第二行"
                        |> Expect.equal
                            [ { text = "第一行", paragraph = 0 }
                            , { text = "第二行", paragraph = 1 }
                            ]
            ]
        , describe "parseFenchi"
            [ test "empty string yields no tokens" <|
                \_ -> Convert.parseFenchi "" |> Expect.equal []
            , test "parses a single han|tailo token" <|
                \_ ->
                    Convert.parseFenchi "食｜tsia̍h"
                        |> Expect.equal [ { han = "食", tailo = "tsia̍h", gloss = "" } ]
            , test "strips hyphens from the han side of multi-syllable words" <|
                \_ ->
                    Convert.parseFenchi "想-袂-曉｜siūnn-bē-hiáu"
                        |> Expect.equal [ { han = "想袂曉", tailo = "siūnn-bē-hiáu", gloss = "" } ]
            , test "parses multiple space-separated tokens" <|
                \_ ->
                    Convert.parseFenchi "食｜tsia̍h 飯｜pn̄g"
                        |> Expect.equal
                            [ { han = "食", tailo = "tsia̍h", gloss = "" }
                            , { han = "飯", tailo = "pn̄g", gloss = "" }
                            ]
            ]
        , describe "isPunct"
            [ test "a comma-only token is punctuation" <|
                \_ -> Convert.isPunct { han = "，", tailo = "", gloss = "" } |> Expect.equal True
            , test "a han word is not punctuation" <|
                \_ -> Convert.isPunct { han = "食", tailo = "tsia̍h", gloss = "" } |> Expect.equal False
            ]
        ]
