//
//  AudioSus.swift
//  WPR
//

import Foundation
import AVFoundation
import Accelerate
import MultipeerConnectivity

class AudioSus : NSObject
{
    private var audioEngine: AVAudioEngine!
    private var mic: AVAudioInputNode!
    private var micTapped = false
    
    private var mixerNode: AVAudioMixerNode!
    private var session: MultipeerSession!
    private var playerNodes = [AVAudioPlayerNode?](repeating:nil, count:8)
    private var players = [MCPeerID : AVAudioPlayerNode]()
    private var freeNodes = Set<AVAudioPlayerNode>()
    
    private var playerCount = 0
    
    var processBufferSize:UInt32 = 1
    var bufferIndex = 0
    var recordFormat: AVAudioFormat!
    var susFormat: AVAudioFormat! = nil
    
    func initialize() -> AudioSus
    {
        configureAudioSession()
        audioEngine = AVAudioEngine()
        mic = audioEngine.inputNode
        recordFormat = mic.inputFormat(forBus: 0)
        susFormat = AVAudioFormat(commonFormat: recordFormat!.commonFormat, sampleRate: recordFormat!.sampleRate/4, channels: recordFormat!.channelCount, interleaved: recordFormat!.isInterleaved)
        processBufferSize = UInt32(recordFormat.sampleRate)/(40)

        mixerNode = AVAudioMixerNode()

        audioEngine.attach(mixerNode)
        audioEngine.connect(mixerNode, to: audioEngine.outputNode, format: self.susFormat!)
        startEngine()
        
        for i in 0..<8
        {
            playerNodes[i] = AVAudioPlayerNode()
            audioEngine.attach(playerNodes[i]!)
            audioEngine.connect(playerNodes[i]!, to: mixerNode, format: self.susFormat!)
            playerNodes[i]!.play(at: nil)
            freeNodes.insert(playerNodes[i]!)
        }
        
        return self;
    }

    func withSession(session: MultipeerSession) -> AudioSus
    {
        self.session = session
        return self
    }
    
    func orderPlayerNode(peer: MCPeerID) -> Bool
    {
        if (players[peer] == nil && !freeNodes.isEmpty)
        {
            players[peer] = freeNodes.removeFirst()
            return true
        }
        
        return false
    }
    
    func releasePlayerNode(peer: MCPeerID)
    {
        let node = players[peer]
        
        if(node != nil)
        {
            players[peer] = nil
            freeNodes.insert(node!)
        }
    }

    func copyAudioBufferBytes(_ audioBuffer: AVAudioPCMBuffer) -> [UInt8]
    {
        let srcLeft = audioBuffer.floatChannelData![0]
        let bytesPerFrame = audioBuffer.format.streamDescription.pointee.mBytesPerFrame
        let numBytes = Int(bytesPerFrame * audioBuffer.frameLength)

        var audioByteArray = [UInt8](repeating: 0, count: numBytes)

        srcLeft.withMemoryRebound(to: UInt8.self, capacity: numBytes)
        {
            srcByteData in
            audioByteArray.withUnsafeMutableBufferPointer
            {
                $0.baseAddress!.initialize(from: srcByteData, count: numBytes)
            }
        }
        return audioByteArray
    }

    func toggleRecord()
    {
        self.bufferIndex = 0;
        
        if micTapped
        {
            mic.removeTap(onBus: 0);
            micTapped = false
            return
        }

        let formatConverter =  AVAudioConverter(from: recordFormat!, to: susFormat!)!

        mic.installTap(onBus: 0, bufferSize: self.processBufferSize*4, format: self.recordFormat!)
        {
            (buffer, when) in
            let pcmBuffer = AVAudioPCMBuffer(pcmFormat: self.susFormat!, frameCapacity: buffer.frameCapacity / 4)
            var error: NSError? = nil
            
            let inputBlock: AVAudioConverterInputBlock =
            {
                inNumPackets, outStatus in
                outStatus.pointee = AVAudioConverterInputStatus.haveData
                return buffer
            }
            
            formatConverter.convert(to: pcmBuffer!, error: &error, withInputFrom: inputBlock)

            self.session.writeDataToStream(pointer: pcmBuffer!.floatChannelData![0], count: self.processBufferSize * 4)
        }
        micTapped = true
        startEngine()
    }

    func scheduleAudioData(peer: MCPeerID, pcmBuffer: AVAudioPCMBuffer)
    {
        players[peer]!.scheduleBuffer(pcmBuffer, at: nil)
    }

    private func configureAudioSession()
    {
        do
        {
            try AVAudioSession.sharedInstance().setCategory(AVAudioSession.Category.playAndRecord, options: [.mixWithOthers, .defaultToSpeaker])
            try AVAudioSession.sharedInstance().setActive(true)
        }
        catch
        {
            print("Problem while starting engine.")
        }
    }

    private func startEngine()
    {
        guard !audioEngine.isRunning
        else
        {
            return
        }

        do
        {
            try audioEngine.start()
        }
        catch
        {
            print("Problem starting engine.")
        }
    }

    private func stopAudioPlayback()
    {
        audioEngine.stop()
        audioEngine.reset()
    }
}
