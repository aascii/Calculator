//
//  CalculatorBrain.swift
//  Calculator
//
//  Created by Jason Hayes on 9/19/17.
//  Copyright © 2017 aasciiworks. All rights reserved.
//

import Foundation

struct CalculatorBrain {
    
    /// Latest result of calculation along with a history of operands and operations
    private var accumulator: (value: Double?,history: String) = (nil, "")
    
    /// Types of things the calculator can perform
    private enum Operation {
        case constant(Double)
        case random
        case unaryOperation((Double) -> Double)
        case binaryOperation((Double,Double) -> Double)
        case equals
        case clearHistory
    }
    
    /// Stores "..." while in the middle of an operation; otherwise nil
    var resultIsPending: String?
    
    private var operations: Dictionary<String,Operation> = [
        "RND" : Operation.random,
        "π" : Operation.constant(Double.pi),
        "e" : Operation.constant(M_E),
        "√" : Operation.unaryOperation(sqrt),
        "𝑦ⁿ" : Operation.binaryOperation(pow),
        "10ⁿ" : Operation.unaryOperation(__exp10),
        "log" : Operation.unaryOperation(log),
        "cos" : Operation.unaryOperation(cos),
        "sin" : Operation.unaryOperation(sin),
        "±" : Operation.unaryOperation({ -$0 }),
        "×" : Operation.binaryOperation({ $0 * $1 }),
        "÷" : Operation.binaryOperation({ $0 / $1 }),
        "+" : Operation.binaryOperation({ $0 + $1 }),
        "−" : Operation.binaryOperation({ $0 - $1 }),
        "=" : Operation.equals,
        "∁" : Operation.clearHistory
    ]
    
    mutating func performOperation(_ symbol: String) {
        if let operation = operations[symbol] {
            switch operation {
            case .random:
                let maxPossibleNum = Double(UInt32.max)
                let arc4randomNum = Double(arc4random())
                accumulator.value = arc4randomNum / maxPossibleNum
                if resultIsPending != nil {
                    accumulator.history += symbol
                } else {
                    accumulator.history = symbol
                }
            case .constant(let numericalValue):
                accumulator.value = numericalValue
                if resultIsPending != nil {
                    accumulator.history += symbol
                } else {
                    accumulator.history = symbol
                }
            case .unaryOperation(let function):
                if accumulator.value != nil {
                    if resultIsPending != nil {
                        let charsToRemove = String(accumulator.value!).characters.count
                        let rangeToRemove = accumulator.history.index(accumulator.history.endIndex, offsetBy: -charsToRemove)..<accumulator.history.endIndex
                        accumulator.history.removeSubrange(rangeToRemove)
                        accumulator.history = accumulator.history + String(symbol) + "(" + String(accumulator.value!) + ")"
                    } else {
                        accumulator.history = String(symbol) + "(" + accumulator.history + ")"
                    }
                    accumulator.value = function(accumulator.value!)
                }
            case .binaryOperation(let function):
                if accumulator.value != nil {
                    if resultIsPending != nil {
                        performPendingBinaryOperation()
                    }
                    pendingBinaryOperation = PendingBinaryOperation(function: function, firstOperand: accumulator.value!)
                    if symbol == "×" || symbol == "÷" {
                        accumulator.history = "(" + accumulator.history + ")" + String(symbol)
                    } else {
                        accumulator.history += String(symbol)
                    }
                    resultIsPending = "..."
                }
            case .equals:
                performPendingBinaryOperation()
                resultIsPending = nil
            case .clearHistory:
                accumulator = (nil, "")
                resultIsPending = nil
                pendingBinaryOperation = nil
            }
        }
    }
    
    /// Returns result of pending binary operation:
    /// Runs ALU clock on the pending operation with contents from
    /// pending operation struct and accumulator;
    /// Closes operation by clearing pending status
    private mutating func performPendingBinaryOperation() {
        if pendingBinaryOperation != nil && accumulator.value != nil {
            accumulator.value = pendingBinaryOperation!.perform(with: accumulator.value!)
            pendingBinaryOperation = nil
        }
    }
    
    /// Stores pending operator with its first operand
    private var pendingBinaryOperation: PendingBinaryOperation?
    
    /// Collection including a pending operator and its first operand
    private struct PendingBinaryOperation {
        let function: (Double,Double) -> Double
        let firstOperand: Double
        
        func perform(with secondOperand: Double) -> Double {
            return function(firstOperand, secondOperand)
        }
    }
    
    /// Sets the accumulator with passed-in operand and records in historical log
    mutating func setOperand(_ operand: Double) {
        accumulator.value = operand
        if resultIsPending != nil {
            accumulator.history += String(operand)
        } else {
            accumulator.history = String(operand)
        }
    }
    
    var result: Double? {
        get {
            return accumulator.value
        }
    }
    
    var history: String? {
        get {
            return accumulator.history
        }
    }
}
