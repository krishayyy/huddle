import Foundation
import MultipeerConnectivity

/// Thin wrapper over MultipeerConnectivity. Works over Bluetooth/peer-to-peer Wi‑Fi,
/// so friends in the same room don't even need internet.
final class PeerSession: NSObject {
    static let serviceType = "huddle-app"   // matches NSBonjourServices in Info.plist

    let myPeer: MCPeerID
    private let session: MCSession
    private var advertiser: MCNearbyServiceAdvertiser?
    private var browser: MCNearbyServiceBrowser?

    var onReceive: ((Data, MCPeerID) -> Void)?
    var onPeersChanged: (([MCPeerID]) -> Void)?
    var onRoomsChanged: (([MCPeerID: [String: String]]) -> Void)?

    private var rooms: [MCPeerID: [String: String]] = [:]   // discovery info: "room", optional "spot"

    var connectedPeers: [MCPeerID] { session.connectedPeers }

    init(peerID: String) {
        myPeer = MCPeerID(displayName: peerID)
        session = MCSession(peer: myPeer, securityIdentity: nil, encryptionPreference: .required)
        super.init()
        session.delegate = self
    }

    deinit { stop() }

    /// `spot` is the ID of the NFC coaster this huddle was started from, so people who tap the
    /// same coaster land in the same room without picking from a list.
    func advertise(roomName: String, spot: String? = nil) {
        var info = ["room": roomName]
        if let spot { info["spot"] = spot }
        let adv = MCNearbyServiceAdvertiser(peer: myPeer, discoveryInfo: info,
                                            serviceType: Self.serviceType)
        adv.delegate = self
        adv.startAdvertisingPeer()
        advertiser = adv
    }

    func browse() {
        let b = MCNearbyServiceBrowser(peer: myPeer, serviceType: Self.serviceType)
        b.delegate = self
        b.startBrowsingForPeers()
        browser = b
    }

    func invite(_ peer: MCPeerID) {
        browser?.invitePeer(peer, to: session, withContext: nil, timeout: 15)
    }

    func send(_ data: Data, to peers: [MCPeerID]) {
        guard !peers.isEmpty else { return }
        try? session.send(data, toPeers: peers, with: .reliable)
    }

    func stop() {
        advertiser?.stopAdvertisingPeer(); advertiser = nil
        browser?.stopBrowsingForPeers(); browser = nil
        session.disconnect()
    }
}

extension PeerSession: MCSessionDelegate {
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        onPeersChanged?(session.connectedPeers)
    }
    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        onReceive?(data, peerID)
    }
    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
}

extension PeerSession: MCNearbyServiceAdvertiserDelegate {
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID,
                    withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        invitationHandler(true, session)
    }
}

extension PeerSession: MCNearbyServiceBrowserDelegate {
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String: String]?) {
        var entry = info ?? [:]
        if entry["room"] == nil { entry["room"] = peerID.displayName }
        rooms[peerID] = entry
        onRoomsChanged?(rooms)
    }
    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        rooms[peerID] = nil
        onRoomsChanged?(rooms)
    }
}
