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
    /// Element used for displaying running historical log of operand+operations
    /// Note: AKA "history UI"
    @IBOutlet weak var inputHistoryDisplay: UILabel!

    @IBOutlet weak var mathVariableDisplay: UILabel!

    @IBOutlet weak var errorMessageDisplay: UILabel!

    var userIsInTheMiddleOfTyping = false

    /// Character limit of "input" UI
    let displayLength = 16
    /// Element tracking current "input" operand string length
    var displayEntries = 0
    /// Element tracking number of "input" operand decimal places
    /// to allow "0" vales after "."
    var displayDecimalPlacesUsed = 0

    /// Constants for formatting display elements
    let maxIntDigits = 9
    let minFracDigits = 0
    let maxFracDigits = 6

    /// Catches & handles numerical button actions in preparation to set operand
    /// Note:  Does NOT modify brain properties
    @IBAction func touchDigit(_ sender: UIButton) {
        let digit = sender.currentTitle!

        if userIsInTheMiddleOfTyping {
            if displayEntries < displayLength {
                if digit != "." || (digit == "." && (display.text!.contains(".") == false)) {
                    var textCurrentlyInDisplay = display.text!
                    let rawStringValue = textCurrentlyInDisplay + digit
                    switch digit {
                    case "⬅︎", "Undo":
                        textCurrentlyInDisplay.remove(at: textCurrentlyInDisplay.index(before:
                            textCurrentlyInDisplay.endIndex))
                        if textCurrentlyInDisplay == "" { textCurrentlyInDisplay = "0" }
                        display.text = textCurrentlyInDisplay
                        displayEntries -= 2
                        if textCurrentlyInDisplay.contains(".") { displayDecimalPlacesUsed -= 1 }
                    case ".":
                        display.text = rawStringValue
                        displayDecimalPlacesUsed = 0
                    case "0":
                        if display.text!.contains(".") &&
                            displayDecimalPlacesUsed < maxFracDigits {
                            display.text = rawStringValue
                            displayDecimalPlacesUsed += 1
                        } else {
                            // a reasonable usage for falling through
                            //swiftlint:disable:next fallthrough
                            fallthrough
                        }
                    default:
                        let formatTextInDisplay = NumberFormatter()
                        formatTextInDisplay.maximumIntegerDigits = maxIntDigits
                        formatTextInDisplay.minimumFractionDigits = minFracDigits
                        formatTextInDisplay.maximumFractionDigits = maxFracDigits
                        let formattedTextNumber = formatTextInDisplay.number(from: rawStringValue)
                        let formattedText = formatTextInDisplay.string(from: formattedTextNumber!)
                        if display.text!.contains(".") && displayDecimalPlacesUsed < maxFracDigits {
                            display.text = formattedText!
                            displayDecimalPlacesUsed += 1
                        } else if display.text!.contains(".") == false {
                            display.text = formattedText!
                        } else {
                            break
                        }
                    }
                }
                displayEntries += 1
            }
        } else {
            switch digit {
            case ".":
                display.text = "0" + digit
                userIsInTheMiddleOfTyping = true
                displayDecimalPlacesUsed = 0
                displayEntries += 2
            case "⬅︎", "Undo":
                break
            default:
                display.text = digit
                userIsInTheMiddleOfTyping = true
                displayEntries += 1
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
            // noformat            display.text = String(newValue)
            let rawStringValue = String(newValue)
            switch rawStringValue {
            case "inf", "nan":
                display.text = rawStringValue
            default:
                let formatTextInDisplay = NumberFormatter()
                formatTextInDisplay.maximumIntegerDigits = 9
                formatTextInDisplay.minimumFractionDigits = 0
                formatTextInDisplay.maximumFractionDigits = 6
                if let formattedTextNumber = formatTextInDisplay.number(from: rawStringValue) {
                    let formattedText = formatTextInDisplay.string(from: formattedTextNumber)
                    display.text = formattedText!
                }
            }
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

    var displayMathVariableValue: Double {
        // Returns the prepared operand value from "math variable" UI
        get {
            return Double(mathVariableDisplay.text!)!
        }
        // Refreshes the "math variable" UI with updated value
        // Note: this is the action which triggers the screen refresh
        set {
            let rawStringValue = String(newValue)
            switch rawStringValue {
            case "inf", "nan":
                mathVariableDisplay.text = rawStringValue
            default:
                let formatTextInDisplay = NumberFormatter()
                formatTextInDisplay.maximumIntegerDigits = 9
                formatTextInDisplay.minimumFractionDigits = 0
                formatTextInDisplay.maximumFractionDigits = 6
                if let formattedTextNumber = formatTextInDisplay.number(from: rawStringValue) {
                    let formattedText = formatTextInDisplay.string(from: formattedTextNumber)
                    mathVariableDisplay.text = formattedText!
                }
            }
        }
    }

    /// Create calculator ALU, including the accumulator
    private var brain: CalculatorBrain = CalculatorBrain()

    /// Catches and handles all non-numerical button actions, eg:
    /// constants, operators, reset (AKA Clear button)
    @IBAction func performOperation(_ sender: UIButton) {
        if userIsInTheMiddleOfTyping {
            // store a new value on the stack
            brain.setOperand(displayValue)
            userIsInTheMiddleOfTyping = false
        }
        if let mathematicalSymbol = sender.currentTitle {
            brain.performOperation(mathematicalSymbol)
        }
        let results = brain.evaluate(using: nil)
        // if brain stack is empty, reset the calculator display to start state.
        // otherwise, since we are at the end of evaluation,
        //     trigger the screen refresh(es)
        screenRefresh(results)
    }

    @IBAction func insertMathVariable(_ sender: UIButton) {
        let mathVariable = sender.currentTitle!

        if userIsInTheMiddleOfTyping {
            userIsInTheMiddleOfTyping = false
        }
        brain.setOperand(variable: mathVariable)
        let results = brain.evaluate(using: nil)

        // if brain stack is empty, reset the calculator display to start state.
        // otherwise, trigger the screen refresh(es)
        screenRefresh(results)
    }

    @IBAction func setMathVariableValue(_ sender: UIButton) {
        let button = sender.currentTitle!
        let mathVariable = String(button.substring(from:
            button.index(button.endIndex, offsetBy: -1)))

        if userIsInTheMiddleOfTyping {
            userIsInTheMiddleOfTyping = false
        }

        displayMathVariableValue = displayValue

        let results = brain.evaluate(using: [mathVariable!: displayValue])

        // if brain stack is empty, reset the calculator display to start state.
        // otherwise, trigger the screen refresh(es)
        screenRefresh(results)
    }

    @IBAction func setUndoAction(_ sender: UIButton) {
        if userIsInTheMiddleOfTyping {
            // already handled by touchDigit()
            return
        }
        if let mathematicalSymbol = sender.currentTitle {
            brain.performOperation(mathematicalSymbol)
        }
        // run twice to mark, then execute, any "undo" action
        var results = brain.evaluate(using: nil)
        results = brain.evaluate(using: nil)
        // if brain stack is empty, reset the calculator display to start state.
        // otherwise, since we are at the end of evaluation,
        //     trigger the screen refresh(es)
        screenRefresh(results)
    }

    @IBAction func clearMemoryDisplay(_ sender: UIButton) {
        displayMathVariableValue = 0
    }

    private func screenRefresh(_ results:
        (result: Double?, isPending: Bool, description: String,
        error: String?)) {
        if let result = results.result {
            displayValue = result
            displayHistoryValue = results.description
            if results.isPending {
                displayHistoryValue += "..."
            } else {
                displayHistoryValue += "="
            }
            displayEntries = 0
            errorMessageDisplay.text = results.error ?? ""

        } else {
            display.text = "0"
            displayHistoryValue = " "
            displayEntries = 0
            errorMessageDisplay.text = ""
        }
    }
}
