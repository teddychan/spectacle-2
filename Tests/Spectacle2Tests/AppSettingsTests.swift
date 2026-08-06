import Testing
import Foundation
@testable import Spectacle2

// AppSettings' hand-written init(from:) is a persisted-schema migration path: an OLD stored
// payload containing only launchAtLogin/showInMenuBar must still decode, with the three newer
// fields (gapSize, skipGapTopEdge, dragSnapEnabled) taking their defaults instead of throwing
// and resetting everything.

@Test func decodingLegacyPayloadKeepsNewerFieldDefaults() throws {
    let json = #"{"launchAtLogin":true,"showInMenuBar":false}"#
    let settings = try JSONDecoder().decode(AppSettings.self, from: Data(json.utf8))

    #expect(settings.launchAtLogin == true)
    #expect(settings.showInMenuBar == false)
    #expect(settings.gapSize == 0)
    #expect(settings.skipGapTopEdge == false)
    #expect(settings.dragSnapEnabled == true)
}

@Test func decodingEmptyPayloadYieldsDefaultValue() throws {
    let settings = try JSONDecoder().decode(AppSettings.self, from: Data("{}".utf8))
    #expect(settings == AppSettings())
}

@Test func roundTripPreservesEveryFieldForNonDefaultValue() throws {
    var settings = AppSettings()
    settings.launchAtLogin = true
    settings.showInMenuBar = false
    settings.gapSize = 12
    settings.skipGapTopEdge = true
    settings.dragSnapEnabled = false

    let data = try JSONEncoder().encode(settings)
    let decoded = try JSONDecoder().decode(AppSettings.self, from: data)
    #expect(decoded == settings)
}

@Test func decodingPayloadWithNewerFieldPresentUsesStoredValue() throws {
    let json = #"""
    {"launchAtLogin":false,"showInMenuBar":true,"gapSize":7,"skipGapTopEdge":true,"dragSnapEnabled":false}
    """#
    let settings = try JSONDecoder().decode(AppSettings.self, from: Data(json.utf8))

    #expect(settings.gapSize == 7)
    #expect(settings.skipGapTopEdge == true)
    #expect(settings.dragSnapEnabled == false)
}
