//
//  ChannelView.swift
//  WPR
//

import SwiftUI

struct ChannelView: View
{
    @ObservedObject var model: MyModel

    @State private var channel = 0
    @State private var channelText = ""

    @Environment(\.presentationMode) var presentationMode
    
    
    var body: some View
    {
        VStack
        {
            header: do
            {
                Text("Enter Channel Number")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .frame(alignment: .top)
            }
            TextEditor(text: $channelText)
            .onChange(of: channelText, perform: { newValue in
                channelText = String(newValue.prefix(9))
                let parsed = Int(channelText)
                channel = (parsed == nil ? 0 : parsed!)
            })
            .font(.system(size: 30, weight: .bold, design: .rounded))
            .multilineTextAlignment(.center)
            .disableAutocorrection(true)
            .frame(maxWidth: 300, maxHeight: 50,alignment: .center)
            .border(Color.blue)
            .textFieldStyle(.roundedBorder)
            .keyboardType(.numberPad)
            .navigationBarBackButtonHidden(true)

            Button(action:
            {
                if (channel != 0)
                {
                    model.channel = channel;
                }
                presentationMode.wrappedValue.dismiss()
            })
            {
                Text("Enter")
                    
                    .frame(width: 100, height: 100)
                    .frame(alignment: .center)
                    .foregroundColor(Color.white)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .background(Color.blue)
                    .multilineTextAlignment(.center)
                    .clipShape(Circle())
                    .frame(alignment: .bottom)
            }.buttonStyle(PlainButtonStyle())
            .padding()
            
            if(channel != 0)
            {
                Text("Switching to Channel: ")
                Text(verbatim: "\(channel)")
            
            }
            Spacer()
        }
    }
}

struct ChannelView_Previews: PreviewProvider
{
    static var previews: some View
    {
        ChannelView(model: MyModel())
    }
}
