//
//  ViewController.swift
//  Calculator
//
//  Created by Jason Hayes on 9/13/17.
//  Copyright © 2017 aasciiworks. All rights reserved.
//

import UIKit

class ViewController: UIViewController {
    
    /// Element used for operand input as well as displaying operation results
    /// Note: AKA "input UI" || "results UI"
    @IBOutlet weak var display: UILabel!
    /// Element used for displaying the running historical log of operand and operations
    /// Note: AKA "history UI"
    @IBOutlet weak var inputHistoryDisplay: UILabel!
    
    var userIsInTheMiddleOfTyping = false
    
    /// Character limit of "input" UI
    let displayLength = 16
    /// Element tracking current "input" operand string length
    var displayEntries = 0
    
    /// Catches and handles numerical button actions in preparation to set operand
    /// Note:  Does NOT modify brain properties
    @IBAction func touchDigit(_ sender: UIButton) {
        let digit = sender.currentTitle!
        
        if userIsInTheMiddleOfTyping {
            if displayEntries < displayLength {
                if (digit != "." || (digit == "." && (display.text!.contains(".") == false))) {
                    let textCurrentlyInDisplay = display.text!
                    display.text = textCurrentlyInDisplay + digit
                    displayEntries += 1
                }
            }
        } else {
            if digit != "." {
                display.text = digit
                userIsInTheMiddleOfTyping = true
                displayEntries += 1
            } else {
                display.text = "0" + digit
                userIsInTheMiddleOfTyping = true
                displayEntries += 2
            }
        }
    }
    
    var displayValue: Double {
        // Returns the prepared operand value from "input" UI
        get {
            return Double(display.text!)!
        }
        // Refreshes the "result" UI with updated value
        // Note: this is the action which triggers the screen refresh
        set {
            display.text = String(newValue)
        }
    }
    
    var displayHistoryValue: String {
        // Returns the prepared historical log
        get {
            return inputHistoryDisplay.text!
        }
        // Refreshes the "history" UI with updated value
        // Note: this is the action which triggers the screen refresh
        set {
            inputHistoryDisplay.text = newValue
        }
    }
    
    /// Create calculator ALU, including the accumulator
    private var brain: CalculatorBrain = CalculatorBrain()
    
    /// Catches and handles all non-numerical button actions, eg:
    /// constants, operators, reset (AKA Clear button)
    @IBAction func performOperation(_ sender: UIButton) {
        if userIsInTheMiddleOfTyping {
            // store a new value in the accumulator
            brain.setOperand(displayValue)
            userIsInTheMiddleOfTyping = false
        }
        if let mathematicalSymbol = sender.currentTitle {
            brain.performOperation(mathematicalSymbol)
        }
        // if the accumulator is empty, reset the calculator to start state
        // otherwise, since we are at the end of performOperation,
        //     trigger the screen refresh(es)
        if let result = brain.result {
            displayValue = result
            displayHistoryValue = brain.history! + (brain.resultIsPending ?? "=")
            displayEntries = 0
        } else {
            display.text = "0"
            displayHistoryValue = "0"
            displayEntries = 0
        }
    }
    
    
}

