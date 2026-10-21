import Testing
@testable import ZettaCore

struct SubtitleLabelsTests {
    @Test func codesBecomeLanguageNames() {
        #expect(SubtitleLabels.languageName("eng") == "English")
        #expect(SubtitleLabels.languageName("sq") == "Albanian")
        #expect(SubtitleLabels.languageName("") == "Subtitle")
        #expect(SubtitleLabels.languageName("xx-unknown") == "xx-unknown")
        #expect(SubtitleLabels.languageName("English") == "English")
    }

    @Test func tracksInOneLanguageAreNumbered() {
        let labels = SubtitleLabels.labels([
            Subtitle(url: "a", lang: "eng"), Subtitle(url: "b", lang: "sqi"), Subtitle(url: "c", lang: "eng"),
        ])
        #expect(labels.map(\.label) == ["English 1", "Albanian", "English 2"])
        #expect(labels.map(\.subtitle.url) == ["a", "b", "c"])
    }

    @Test func theCodesOfOpenSubtitlesBecomeNames() {
        #expect(SubtitleLabels.languageName("pob") == "Portuguese (Brazil)")
        #expect(SubtitleLabels.languageTag("pob") == "pt-BR")
        #expect(SubtitleLabels.languageTag("sqi") == "sq")
        #expect(SubtitleLabels.languageName("alb") == "Albanian")
        #expect(SubtitleLabels.languageName("cze") == "Czech")
    }

    @Test func thePreferredLanguageComesFirstWithAFewTracksOfEachLanguage() {
        let subs = (1...5).map { Subtitle(url: "p\($0)", lang: "pob") }
            + (1...5).map { Subtitle(url: "e\($0)", lang: "eng") }
            + [Subtitle(url: "s1", lang: "sqi")]
        #expect(SubtitleLabels.arrange(subs, preferred: "en").map(\.url) == ["e1", "e2", "e3", "p1", "p2", "p3", "s1"])
        #expect(SubtitleLabels.arrange(subs, preferred: "").map(\.url) == ["p1", "p2", "p3", "e1", "e2", "e3", "s1"])
    }
}
