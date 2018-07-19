//
//  ViewController.swift
//  MyMetronomeDemo
//
//  Created by ITFuser on 19/07/18.
//  Copyright © 2018 ITFuser. All rights reserved.
//

import UIKit

class ViewController: UIViewController,MetronomeDelegate {
    @IBOutlet var timesignaturelabel: UILabel!
    
    
    @IBOutlet var tempolabel: UILabel!
    
    @IBOutlet var rythmlabel: UILabel!
    
    @IBOutlet var tempostepper: UIStepper!
    
    @IBOutlet var timesigmature: UIStepper!
    let delegate = UIApplication.shared.delegate as! AppDelegate

    override func viewDidLoad() {
        super.viewDidLoad()
        
        timesigmature.value = 4
        
     delegate.MetronomeEngine.delegate = self
       delegate.MetronomeEngine.setTimesignature(4)
        delegate.MetronomeEngine.setTempo(50)
        delegate.MetronomeEngine.start()
        
        tempolabel.text = "50"
        timesignaturelabel.text = "4"
        
        // Do any additional setup after loading the view, typically from a nib.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func metronomeTicking(_ metronome: AVMetronome, bar: Int, beat: Int) {
        
        print("BTS \(beat)")
        DispatchQueue.main.async {
            self.rythmlabel.text = "\(beat)"

        }
        
    }
    
    
    @IBAction func timeincrease(_ sender: Any) {
        
        if(delegate.MetronomeEngine.timeSignature > 1 && delegate.MetronomeEngine.timeSignature < 16)
        {
            delegate.MetronomeEngine.setTimesignature(Int(timesigmature.value))
        
            timesignaturelabel.text="\(timesigmature.value)"
        }
        
    }
    
    @IBAction func bpmincrease(_ sender: Any) {
        
        if(delegate.MetronomeEngine.tempoBPM > 20 && delegate.MetronomeEngine.timeSignature < 240)
        {
            delegate.MetronomeEngine.setTempo(Int(tempostepper.value))
        
            tempolabel.text="\(tempostepper.value)"
        }
        
    }
    
}

