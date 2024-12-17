import SwiftUI
import AVFoundation

class MyModel: ObservableObject
{
    @Published var channel = 0
}

struct PushToTalkView: View
{
    @StateObject private var model = MyModel()
    @StateObject var session: MultipeerSession
    var audioRecorder: AudioSus!
    @State private var navigation = false;
    @State private var isPressed = false;
    @State private var handsfree = false;
    
    @Environment(\.presentationMode) var presentationMode;
    var body: some View
    {
        NavigationView
        {
            VStack
            {
                header: do
                {
                    NavigationLink(destination: ChannelView(model: model), isActive: $navigation)
                {
                Button(action:
                {
                    AudioServicesPlaySystemSound(1117)
                    navigation = true;
                })
                {
                    Text(verbatim: "Channel: \n \(model.channel)")
                        .frame(width: 200, height: 50)
                        .foregroundColor(Color.white)
                        .multilineTextAlignment(.center)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .buttonStyle(PlainButtonStyle())
                        .navigationTitle("Wireless Phone Radio")
                }.buttonStyle(PlainButtonStyle())
                    
                }.onReceive(model.$channel) { newValue in
                    session.send(ID: model.channel)
                } // After the channel id is changed send it to all peers.
            }
            Spacer()
                Button(action:
                {
                    AudioServicesPlaySystemSound(1117)
                })
                {
                    Text("Talk")
                        .frame(width: 300, height: 300)
                        .frame(alignment: .center)
                        .foregroundColor(Color.white)
                        .font(.system(size: 145, weight: .bold, design: .rounded))
                        .background(isPressed ? Color.red : Color.blue)
                        .multilineTextAlignment(.center)
                        .clipShape(Circle())
                        .frame(alignment: .bottom)
                }.buttonStyle(PlainButtonStyle())
                    .onLongPressGesture(minimumDuration: 0.5, pressing: { pressing in
                        withAnimation(.easeOut(duration: 1.0))
                        {
                            self.isPressed = pressing
                        }
                        if pressing
                        {
                            audioRecorder.toggleRecord()
                        }
                        else
                        {
                            audioRecorder.toggleRecord()
                        }
                    }, perform: { })
                    .scaleEffect(isPressed ? 1.2: 1.0)

                Spacer(minLength: 60)
                
                // Change channel button 
                HStack
                {
                    Button(action:
                    {
                        AudioServicesPlaySystemSound(handsfree ? 1118 : 1117)
                        audioRecorder.toggleRecord()
                        handsfree = (handsfree ? false : true)
                    })
                    {
                        Text("Hands Free")
                            .frame(width: 110, height: 110)
                            .foregroundColor(Color.white)
                            .multilineTextAlignment(.center)
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .background(handsfree ? Color.red : Color.init(red: 0.3, green: 0.9, blue: 0.7))
                            .clipShape(Circle())
                            .frame(maxWidth: . infinity,  alignment: .center)
                    }.buttonStyle(PlainButtonStyle())
                }
            }.scaledToFit()
        }
    }
    
    struct ContentView_Previews: PreviewProvider
    {
        static var previews: some View
        {
            PushToTalkView(session: MultipeerSession());
        }
    }
}


