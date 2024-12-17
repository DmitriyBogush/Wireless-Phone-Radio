//
//  ContentView.swift
//  WPR
//
//  Created by Dmitriy Bogush on 10/28/22.
//

import SwiftUI
import AVFoundation

var pushToTalk = true;



struct ContentView: View
{
    var audio = AudioSus().initialize();
    @StateObject var session = MultipeerSession();
    
    var body: some View {
        
        if(pushToTalk)
        {
            PushToTalkView(session: session.withAudio(audio: audio), audioRecorder: audio.withSession(session: session))
        }
        else
        {
            ChannelView(model: MyModel())
        }
    }
}


