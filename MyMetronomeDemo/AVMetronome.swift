//
//
//
// https://developer.apple.com/library/content/samplecode/HelloMetronome/Listings/HelloMetronome_main_m.html
//

import Foundation
import AVFoundation

 protocol MetronomeDelegate: class {
     func metronomeTicking(_ metronome: AVMetronome, bar: Int, beat: Int)
}

struct Globals {
    static let kBipDurationSeconds: Double = 0.200
    static let kTempoChangeResponsivenessSeconds: Double = 0.250
    
 
}

class AVMetronome : NSObject {
    
    
    var delegate : MetronomeDelegate?
    
    var engine: AVAudioEngine = AVAudioEngine()
    var player: AVAudioPlayerNode = AVAudioPlayerNode()
    var soundBuffer = [AVAudioPCMBuffer?]()
    
    var bufferNumber: Int = 0
    var bufferSampleRate: Float64 = 0.0
    
    var syncQueue: DispatchQueue? = nil
    
    
   
    var isOn: Bool = false
    var isFirstBeat: Bool = false
    var playerStarted: Bool = false
    var didRegisterTap: Bool = false
    
   
    let minTempo: Int = 50
    let maxTempo: Int = 220
    let possibleTimeSignatures = [1,2,3,4]
    
    var timeSignature: Int =  0
    var tempoBPM: Int = 0
    var tempoInterval: Double = 0
    var beatNumber: Int = 0
    var nextBeatSampleTime: AVAudioFramePosition = AVAudioFramePosition(0)
    var beatsToScheduleAhead: Int = 0
    var beatsScheduled: Int = 0
    
   
   
    // ------------
    
    override init() {
        super.init()
        
      
        let format = AVAudioFormat(standardFormatWithSampleRate: 44100.0, channels: 2)

        let freq1 = 440.0
        let freq2 = 261.6
   
        
        let periods1 = Int(Globals.kBipDurationSeconds * freq1)
        let periods2 = Int(Globals.kBipDurationSeconds * freq2)
        
       
        let bipFrames1 = UInt32(Double(periods1) * 1/freq1 * Double((format?.sampleRate)!))
        let bipFrames2 = UInt32(Double(periods2) * 1/freq2 * Double((format?.sampleRate)!))
        
       
        soundBuffer.append(AVAudioPCMBuffer(pcmFormat: format!, frameCapacity: bipFrames1))
        soundBuffer.append(AVAudioPCMBuffer(pcmFormat: format!, frameCapacity: bipFrames2)) //1
      
        
        soundBuffer[0]?.frameLength = bipFrames1
        soundBuffer[1]?.frameLength = bipFrames2
        
 
        let wg1 = TriangleWaveGenerator(sampleRate: Float((format?.sampleRate)!))                     // A 440
        let wg2 = TriangleWaveGenerator(sampleRate: Float((format?.sampleRate)!), frequency: 900.6)   // Middle C
       // A3
        wg1.render(soundBuffer[0]!)
        wg2.render(soundBuffer[1]!)
        
        // Connect player -> output, with the format of the buffers we're playing.
        let output: AVAudioOutputNode = engine.outputNode
        
        engine.attach(player)
        engine.connect(player, to: output, fromBus: 0, toBus: 0, format: format)
        
        bufferSampleRate = (format?.sampleRate)!
        
        // Create a serial dispatch queue for synchronizing callbacks.
        syncQueue = DispatchQueue(label: "Metronome")
        
       
    }
    
    deinit {
        self.stop()
        
        engine.detach(player)
        soundBuffer[0] = nil
        soundBuffer[1] = nil
       
    }
    
 
    
   func getBeatInTimeSignature() -> Int { return self.beatNumber % self.timeSignature + 1}
    
    func getAbsoluteBeat() -> Int { return self.beatNumber }

    func getInterval() -> Double { return self.tempoInterval }
    
    func scheduleBeats() {
        if (!isOn) { return }
        
        while (beatsScheduled < beatsToScheduleAhead) {
            
            // Schedule the beat.
            let secondsPerBeat = self.getInterval()
            let samplesPerBeat = AVAudioFramePosition(secondsPerBeat * Double(bufferSampleRate))
            let beatSampleTime: AVAudioFramePosition = AVAudioFramePosition(nextBeatSampleTime)
            let playerBeatTime: AVAudioTime = AVAudioTime(sampleTime: AVAudioFramePosition(beatSampleTime), atRate: bufferSampleRate)
            // This time is relative to the player's start time.
            
            player.scheduleBuffer(soundBuffer[self.bufferNumber]!, at: playerBeatTime, options: AVAudioPlayerNodeBufferOptions(rawValue: 0), completionHandler: {
                self.syncQueue!.sync() {
                  
                  self.bufferNumber = min(self.getBeatInTimeSignature()%self.timeSignature, 1)
                    
                    self.beatsScheduled -= 1

                    self.incrementBeat()
                    self.scheduleBeats()
                }
            })
            
            beatsScheduled += 1
            
            if (!playerStarted) {
                
              
                player.play()
                playerStarted = true
            }
            

      
            
      //animate UI
         let callbackBeat = self.getAbsoluteBeat() % self.possibleTimeSignatures.max()!
                let nodeBeatTime: AVAudioTime = player.nodeTime(forPlayerTime: playerBeatTime)!

                let dispatchTime = DispatchTime(uptimeNanoseconds: nodeBeatTime.hostTime ) //+ latencyHostTicks)
                
                DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: dispatchTime) {
                    if (self.isOn) {
  
                        
                        self.delegate?.metronomeTicking(self, bar: 0, beat: callbackBeat)
                        
                        self.didRegisterTap = false
                        self.isFirstBeat = false
                    }
                }
           
            
          
            scheduleNextBeatTime(samplesFromLastBeat: samplesPerBeat)
        }
    }
    
    func scheduleNextBeatTime(samplesFromLastBeat: AVAudioFramePosition) {
        self.nextBeatSampleTime += AVAudioFramePosition(samplesFromLastBeat)
    }
    
    func scheduleNextBeatTime(samplesFromNow: AVAudioFramePosition) {
        let now = AVAudioFramePosition((player.playerTime(forNodeTime: player.lastRenderTime!)?.sampleTime)!)
//        print("Now: \(now)")
        self.nextBeatSampleTime = now + samplesFromNow
    }
    
    @discardableResult func start() -> Bool {
        // Start the engine without playing anything yet.
        do {
            try engine.start()
            print("\nSTARTING")
            
            isOn = true
            isFirstBeat = true
            
            nextBeatSampleTime = 0
            beatNumber = 0
            bufferNumber = 0
            
            self.syncQueue!.sync() {
            
                self.scheduleBeats()
            }
            
            return true
        } catch {
            print("\(error)")
            return false
        }
    }
    
    func stop() {
        print("Stopping")
        isOn = false;
        playerStarted = false
        didRegisterTap = false
        
        player.stop()
        player.reset()
        engine.stop()
        
        nextBeatSampleTime = 0
        beatNumber = 0
        bufferNumber = 0
        
      
    }
    
    func playNow() {
        player.play()
    }
    
    
    
    func setTempo(_ tempo: Int) {
        if (tempo <= self.maxTempo && tempo >= self.minTempo) {
            self.tempoBPM = tempo
            print("Set Tempo to \(tempo)")
            self.tempoInterval = 60.0 / Double(tempoBPM)
            beatsToScheduleAhead = Int(Int32(Globals.kTempoChangeResponsivenessSeconds / self.tempoInterval))
            if (beatsToScheduleAhead < 1) { beatsToScheduleAhead = 1 }
         
          
        }
    }
   
    
    func incrementBeat() {
        self.beatNumber += 1
    }
    
 
    
    func setTimesignature(_ newTS: Int) {
       
        print("Set timeSignature to \(newTS)")
        self.timeSignature = newTS
        
    }
    
}
