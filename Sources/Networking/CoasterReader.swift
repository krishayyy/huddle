import Foundation
#if canImport(CoreNFC)
@preconcurrency import CoreNFC
#endif

/// Reads a "Huddle coaster": any cheap NFC sticker (NTAG213/215) placed in the middle of a table.
/// Each coaster holds a short ID like "huddle:3fa9c1". Everyone who taps the same coaster ends up
/// in the same huddle. A blank sticker is set up automatically the first time someone taps it.
///
/// iPhones can't NFC-tap each other directly, so the coaster is the shared thing you tap.
/// Needs the "NFC Tag Reading" capability (paid Apple developer account) and a real iPhone.
@MainActor
final class CoasterReader: NSObject, ObservableObject {
    nonisolated static let prefix = "huddle:"

    @Published private(set) var lastError: String?

    var isAvailable: Bool {
        #if canImport(CoreNFC)
        NFCNDEFReaderSession.readingAvailable
        #else
        false
        #endif
    }

    private var onSpot: ((String) -> Void)?

    #if canImport(CoreNFC)
    private var session: NFCNDEFReaderSession?

    func scan(_ onSpot: @escaping (String) -> Void) {
        guard isAvailable else { lastError = "This phone can't read NFC."; return }
        lastError = nil
        self.onSpot = onSpot
        let s = NFCNDEFReaderSession(delegate: self, queue: nil, invalidateAfterFirstRead: false)
        s.alertMessage = "Hold the top of your phone on the Huddle coaster."
        s.begin()
        session = s
    }

    fileprivate func found(_ spot: String) {
        let cb = onSpot
        onSpot = nil
        session = nil
        cb?(spot)
    }

    fileprivate func failed(_ message: String?) {
        session = nil
        onSpot = nil
        lastError = message
    }
    #else
    func scan(_ onSpot: @escaping (String) -> Void) { lastError = "This phone can't read NFC." }
    #endif

    #if canImport(CoreNFC)
    /// Pulls a Huddle spot ID out of a tag's text or URL records.
    nonisolated static func spot(in message: NFCNDEFMessage?) -> String? {
        for record in message?.records ?? [] {
            let text = record.wellKnownTypeTextPayload().0 ?? record.wellKnownTypeURIPayload()?.absoluteString
            if let text, let r = text.range(of: prefix) {
                let id = String(text[r.upperBound...]).prefix(16).filter { $0.isLetter || $0.isNumber }
                if !id.isEmpty { return String(id) }
            }
        }
        return nil
    }
    #endif
}

#if canImport(CoreNFC)
extension CoasterReader: NFCNDEFReaderSessionDelegate {
    nonisolated func readerSession(_ session: NFCNDEFReaderSession, didDetectNDEFs messages: [NFCNDEFMessage]) {}

    nonisolated func readerSession(_ session: NFCNDEFReaderSession, didDetect tags: [NFCNDEFTag]) {
        guard let tag = tags.first else { return }
        session.connect(to: tag) { error in
            if error != nil { session.invalidate(errorMessage: "Couldn't read that. Try again."); return }
            tag.queryNDEFStatus { status, _, _ in
                tag.readNDEF { message, _ in
                    if let id = Self.spot(in: message) {
                        session.alertMessage = "Joining your huddle 🫂"
                        session.invalidate()
                        Task { @MainActor in self.found(id) }
                        return
                    }
                    // Blank or foreign sticker: turn it into a Huddle coaster if we're allowed to.
                    guard status == .readWrite else {
                        session.invalidate(errorMessage: "That tag isn't a Huddle coaster.")
                        return
                    }
                    let id = String(UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(10)).lowercased()
                    guard let record = NFCNDEFPayload.wellKnownTypeTextPayload(string: Self.prefix + id, locale: Locale(identifier: "en")) else {
                        session.invalidate(errorMessage: "Couldn't set up that coaster.")
                        return
                    }
                    tag.writeNDEF(NFCNDEFMessage(records: [record])) { error in
                        if error != nil { session.invalidate(errorMessage: "Couldn't set up that coaster."); return }
                        session.alertMessage = "New Huddle coaster ready ✨"
                        session.invalidate()
                        Task { @MainActor in self.found(id) }
                    }
                }
            }
        }
    }

    nonisolated func readerSession(_ session: NFCNDEFReaderSession, didInvalidateWithError error: Error) {
        let code = (error as? NFCReaderError)?.code
        // Closing the sheet or a normal finish isn't an error worth showing.
        let quiet = code == .readerSessionInvalidationErrorUserCanceled
            || code == .readerSessionInvalidationErrorFirstNDEFTagRead
        Task { @MainActor in
            guard self.onSpot != nil else { return }      // already handled a tag
            self.failed(quiet ? nil : "Couldn't read the coaster. Try again.")
        }
    }
}
#endif
