//
//  MultipeerSession.swift
//  WPR
//

import MultipeerConnectivity
import os
import AVFoundation

class MultipeerSession: NSObject, ObservableObject
{
    @Published var connectedPeers: [MCPeerID] = []
    @Published var channelID: Int = 0
    
    var audio: AudioSus?
    var connections = [MCPeerID : OutputStream?]()
    var peerIncoming = [MCPeerID : InputStream?]()
    var peersInChannel = Set<MCPeerID>()
    var streamOwners = [InputStream : MCPeerID]()
    var streamBuffers = [InputStream : [UInt8]]()
    var streamPositions = [InputStream : Int]()
    var outputStream: OutputStream?
    var err: Error? = nil;
    private let serviceType = "wpr"
    private let myPeerId = MCPeerID(displayName: UIDevice.current.name)
    private let serviceAdvertiser: MCNearbyServiceAdvertiser
    private let serviceBrowser: MCNearbyServiceBrowser
    private let session: MCSession
    private let log = Logger()
    private var maxNumberBytes: Int = 1;
    
    func withAudio(audio: AudioSus) -> MultipeerSession
    {
        self.audio = audio;
        maxNumberBytes = Int(audio.processBufferSize*4);
        return self;
    }
    
    func startStream()
    {
        do
        {
            try session.connectedPeers.forEach{ peer in
                if (connections[peer] == nil)
                {
                    print("ATTACH STREAM TO", peer.displayName)
                    try connections[peer] = session.startStream(withName: peer.displayName, toPeer: peer as MCPeerID)
                }
                
                if let outputStream = connections[peer] {
                    outputStream!.delegate = self
                    outputStream!.schedule(in: RunLoop.main, forMode:RunLoop.Mode.default)
                    outputStream!.open()
                }
            }
        }
        catch
        {
            print("UNABLE TO INITIALIZE OUTPUT STREAM");
        }
    }
    
    func writeDataToStream(pointer: UnsafeRawPointer, count: UInt32)
    {
        for (_, stream) in connections
        {
            if (stream != nil)
            {
                stream?.write(pointer, maxLength: Int(count));
            }
        }
    }
    
    // Send current channel id to all other connected users used for grouping.
    func send(ID: Int)
    {
        var isChanging = (self.channelID != ID)
        
        log.info("Sending channel ID: \(ID) to \(self.session.connectedPeers.count) peers.")
        
        self.channelID = ID
        let data = withUnsafeBytes(of: ID) { Data($0) }
        
        if !session.connectedPeers.isEmpty
        {
            do
            {
                if (isChanging)
                {
                    for peerID in peersInChannel
                    {
                        self.disconnectFromPeer(peerID: peerID)
                    }
                }

                try session.send(data, toPeers: session.connectedPeers, with: .reliable)
            }
            catch
            {
                log.error("Error sending channel ID.")
            }
        }
        
    }
    
    func disconnectFromPeer(peerID: MCPeerID)
    {
        audio!.releasePlayerNode(peer: peerID)
        self.connections[peerID]??.close()
        self.connections[peerID] = nil
        self.peersInChannel.remove(peerID);
        let stream = self.peerIncoming[peerID]
        self.peerIncoming[peerID] = nil
        
        if(stream != nil)
        {
            stream!!.close()
            self.streamOwners[stream!!] = nil
            self.streamBuffers[stream!!] = nil
            self.streamPositions[stream!!] = nil
        }
    }

    func bytesToAudioBuffer(_ buf: [UInt8]) -> AVAudioPCMBuffer
    {
        let fmt = audio!.recordFormat!
        let frameLength = UInt32(buf.count) / fmt.streamDescription.pointee.mBytesPerFrame

        let audioBuffer = AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: frameLength)!
        audioBuffer.frameLength = frameLength

        let dstLeft = audioBuffer.floatChannelData![0]

        buf.withUnsafeBufferPointer
        {
            let src = UnsafeRawPointer($0.baseAddress!).bindMemory(to: Float.self, capacity: Int(frameLength))
            dstLeft.initialize(from: src, count: Int(frameLength))
        }

        return audioBuffer
    }

    override init()
    {
        session = MCSession(peer: myPeerId, securityIdentity: nil, encryptionPreference: .none)
        serviceAdvertiser = MCNearbyServiceAdvertiser(peer: myPeerId, discoveryInfo: nil, serviceType: serviceType)
        serviceBrowser = MCNearbyServiceBrowser(peer: myPeerId, serviceType: serviceType)

        super.init()

        session.delegate = self
        serviceAdvertiser.delegate = self
        serviceBrowser.delegate = self

        serviceAdvertiser.startAdvertisingPeer()
        serviceBrowser.startBrowsingForPeers()
    }
    deinit
    {
        serviceAdvertiser.stopAdvertisingPeer()
        serviceBrowser.stopBrowsingForPeers()
    }
}

extension MultipeerSession: StreamDelegate
{
    func stream(_ aStream: Stream, handle eventCode: Stream.Event)
    {
        switch(eventCode)
        {
            case Stream.Event.hasBytesAvailable:
                let input = aStream as! InputStream
                var buffer = [UInt8](repeating: 0, count: maxNumberBytes);
                let numberBytes = input.read(&buffer, maxLength: maxNumberBytes);
                var bufferIndex = streamPositions[input]!;
                let peerID = streamOwners[input]!;
                
                for i in 0..<numberBytes
                {
                    streamBuffers[input]![bufferIndex] = buffer[i]
                    bufferIndex += 1;

                    if (bufferIndex >= self.maxNumberBytes)
                    {
                        let audioSample = bytesToAudioBuffer(streamBuffers[input]!);
                        audio?.scheduleAudioData(peer: peerID, pcmBuffer: audioSample);
                        bufferIndex = 0
                    }
                }
                
                streamPositions[input] = bufferIndex
            case Stream.Event.hasSpaceAvailable:
                break
            default:
                break
        }
    }
}

extension MultipeerSession: MCNearbyServiceAdvertiserDelegate
{
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error)
    {
        log.error("ServiceAdvertiser didNotStartAdvertisingPeer: \(String(describing: error))")
    }

    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void)
    {
        log.info("didReceiveInvitationFromPeer \(peerID)")
        invitationHandler(true, session)
    }
}

extension MultipeerSession: MCNearbyServiceBrowserDelegate
{
    func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error)
    {
        log.error("ServiceBrowser didNotStartBrowsingForPeers: \(String(describing: error))")
    }

    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String: String]?)
    {
        log.info("ServiceBrowser found peer: \(peerID)")
        browser.invitePeer(peerID, to: session, withContext: nil, timeout: 10)
    }

    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID)
    {
        log.info("ServiceBrowser lost peer: \(peerID)")
    }
}

extension MultipeerSession: MCSessionDelegate
{
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState)
    {
        log.info("Peer '\(peerID.displayName)' changed state to: \(state.rawValue)")
        DispatchQueue.main.async
        {
            self.connectedPeers = session.connectedPeers
            switch state
            {
                case .connected:
                    self.log.info("Connected to: \(peerID.displayName)")
                case .notConnected:
                    self.log.info("Disconnect from: \(peerID.displayName)")
                    self.disconnectFromPeer(peerID: peerID)
                @unknown default:
                    break
            }
        }
    }

    // Recieve channel id from other users.
    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID)
    {
        var channelNum = 0;
        let _ = withUnsafeMutableBytes(of: &channelNum, {data.copyBytes(to: $0)} )

        log.info("Recieved channel number: \(channelNum) from: \(peerID.displayName)")
        if (!peersInChannel.contains(peerID))
        {
            if (self.channelID == channelNum)
            {
                peersInChannel.insert(peerID)
                if (connections[peerID] == nil)
                {
                    log.info("Attached stream to: \(peerID.displayName)")
                    do
                    {
                        try connections[peerID] = session.startStream(withName: peerID.displayName, toPeer: peerID as MCPeerID)
                    }
                    catch
                    {
                        log.error("Unable to attach stream to: \(peerID.displayName).");
                    }
                    
                    send(ID: self.channelID);
                }
                
                if let outputStream = connections[peerID]
                {
                    outputStream!.delegate = self
                    outputStream!.schedule(in: RunLoop.main, forMode:RunLoop.Mode.default)
                    outputStream!.open()
                }
            }
        }
        else
        {
            if (self.channelID != channelNum)
            {
                log.info("Soft disconnect from peer: \(peerID.displayName)")
                self.disconnectFromPeer(peerID: peerID)
            }
        }
    }

    public func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID)
    {
        log.info("Stream attached from \(peerID.displayName)");
        
        if(!audio!.orderPlayerNode(peer: peerID))
        {
            log.error("FATAL ERROR: COULD NOT ALLOCATE A PLAYER NODE!")
            return
        }
        
        stream.delegate = self
        stream.schedule(in: RunLoop.main, forMode: RunLoop.Mode.default)
        stream.open()

        streamOwners[stream] = peerID
        peerIncoming[peerID] = stream
        streamPositions[stream] = 0
        streamBuffers[stream] = [UInt8](repeating: 0, count: maxNumberBytes)
    }

    public func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress)
    {
        log.error("Receiving resources is not supported")
    }

    public func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?)
    {
        log.error("Receiving resources is not supported")
    }
}
