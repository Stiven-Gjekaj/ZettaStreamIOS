import Testing
@testable import ZettaCore

struct FaultLogTests {
    @Test func eachKindOfLineGivesItsFault() {
        #expect(FaultLog.fault(["Codec `hevc' (HEVC) is not supported."]) == .decoder)
        #expect(FaultLog.fault(["VLC could not decode the format \"av01\""]) == .decoder)
        #expect(FaultLog.fault(["HTTP 403 error"]) == .refused)
        #expect(FaultLog.fault(["access denied by the server"]) == .refused)
        #expect(FaultLog.fault(["cannot resolve example.com port 443: no address"]) == .noConnection)
        #expect(FaultLog.fault(["connection timed out"]) == .noConnection)
        #expect(FaultLog.fault(["no suitable demux module for `https/://example.com/a'"]) == .notVideo)
        #expect(FaultLog.fault(["connection reset by peer"]) == .network)
        #expect(FaultLog.fault(["something strange"]) == .other(name: "player error"))
        #expect(FaultLog.fault([]) == .other(name: "player error"))
    }

    @Test func theCauseWinsOverAGeneralLine() {
        let lines = ["HTTP 404 error", "Your input can't be opened", "VLC is unable to open the MRL"]
        #expect(FaultLog.fault(lines) == .refused)
        #expect(FaultLog.reason(lines) == "HTTP 404 error")
        // The case of the letters does not count.
        #expect(FaultLog.fault(["CONNECTION REFUSED"]) == .noConnection)
    }

    @Test func aNumberThatIsNotAStatusIsNotARefusal() {
        #expect(FaultLog.fault(["picture 404 is late"]) != .refused)
        #expect(FaultLog.fault(["http 200 ok", "socket closed"]) == .network)
    }

    @Test func theReasonIsShort() {
        let long = String(repeating: "a", count: 200)
        #expect(FaultLog.reason([long])?.count == 80)
        #expect(FaultLog.reason([]) == nil)
        #expect(FaultLog.reason(["  odd line  "]) == "odd line")
    }

    @Test func aStopBeforeTheEndIsAFault() {
        #expect(PlayerErrors.endedEarly(position: 600_000, duration: 1_400_000))
        #expect(!PlayerErrors.endedEarly(position: 1_390_000, duration: 1_400_000))
        #expect(!PlayerErrors.endedEarly(position: 1_370_000, duration: 1_400_000))
        #expect(PlayerErrors.endedEarly(position: 1_369_999, duration: 1_400_000))
        // A live channel has no length. It must not end.
        #expect(PlayerErrors.endedEarly(position: 5_000_000, duration: 0))
    }
}
