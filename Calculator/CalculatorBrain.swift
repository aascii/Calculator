//
//  CalculatorBrain.swift
//  Calculator
//
//  Created by Jason Hayes on 9/19/17.
//  Copyright © 2017 aasciiworks. All rights reserved.
//

import Foundation

/// Types of entries stored in the "stack" of user input: operands (including
/// mathematical variables) and operations to be evaluated.
private enum Entries {
    case number(Double)
    case opcode(String)
    case mathvariable(String)
}

/// Array of elements representing a mathematical formula
/// Note: may be empty, a single value, or an incomplete binary operation
private var stack = [Entries]()

/// Optional collection of stored variable names and matching values
private var variablesInMemory: [String: Double]? = nil

struct CalculatorBrain {
    
    /// Types of operations the calculator can perform
    private enum Operation {
        case constant(Double)
        case random
        case unaryOperation((Double) -> Double)
        case binaryOperation((Double,Double) -> Double)
        case equals
        case clearHistory
    }
    
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
    
    /// DEPRECATE
    /// Stores "..." while in the middle of an operation; otherwise nil
    var resultIsPending: String?
    
    /// Inserts a mathematical operation onto the stack & runs the ALU if enough
    /// operands are available; or in the case of a binary operation with second
    /// operand not available yet, queues a pending operation.
    mutating func performOperation(_ symbol: String) {
        stack.append(Entries.opcode(symbol))
        results = evaluate(using: variablesInMemory)
        if results.isPending {
            resultIsPending = "..."
        } else {
            resultIsPending = nil
        }
    }
    
    /// Inserts operand into stack
    /// Note: this setOperand takes an unlabeled Double
    mutating func setOperand(_ operand: Double) {
        stack.append(Entries.number(operand))
        results = evaluate(using: variablesInMemory)
        if results.isPending {
            resultIsPending = "..."
        } else {
            resultIsPending = nil
        }
    }
    
    /// Inserts operand into stack
    /// Note: this setOperand takes a labelled String, ie a mathematical variable
    mutating func setOperand(variable named: String) {
        stack.append(Entries.mathvariable(named))
        results = evaluate(using: variablesInMemory)
        if results.isPending {
            resultIsPending = "..."
        } else {
            resultIsPending = nil
        }
    }
    
    /// Performs all the mathematical operations possible given the stack and
    /// a dictionary of mathematical variable names and values
    func evaluate(using variables: Dictionary<String,Double>? = nil)
        -> (result: Double?, isPending: Bool, description: String){
            if stack.isEmpty == false {
                var result: Double?
                var isPending = false
                var description = " "
                var secondOperand: Double? = nil
                var subExpressionDepth = 0
                var subExpression = ""
                
                /// Stores pending operator with its first operand
                var pendingBinaryOperation: PendingBinaryOperation?
                
                /// Collection including a pending operator and its first operand
                struct PendingBinaryOperation {
                    let function: (Double,Double) -> Double
                    let firstOperand: Double
                    
                    func perform(with secondOperand: Double) -> Double {
                        return function(firstOperand, secondOperand)
                    }
                }
                /// Returns result of pending binary operation:
                /// Runs ALU clock on the pending operation with contents from
                /// pending operation struct and accumulator;
                /// Closes operation by clearing pending status
                func performPendingBinaryOperation() {
                    result =
                        pendingBinaryOperation!.perform(with: secondOperand!)
                    pendingBinaryOperation = nil
                }
                
                /// Represents main loop of calculator brain
                /// Sequences through stack entries to interpret operands and
                /// operators for evaluation, executing results in-line
                for (index,stackEntry) in stack.enumerated() {
                    switch stackEntry {
                    /// attempt to evaluate with an assigned variable
                    case .mathvariable(let stackVariable):
                        var keyValue: Double
                        if let substituteValues = variablesInMemory {
                            if let substituteValue =
                                substituteValues[stackVariable] {
                                keyValue = substituteValue
                            } else {
                                keyValue = 0
                            }
                        } else {
                            keyValue = 0
                        }
                        if isPending && secondOperand != nil {
                            isPending = false
                        }
                        if isPending {
                            secondOperand = keyValue
                            description += String(stackVariable)
                        } else {
                            result = keyValue
                            description = String(stackVariable)
                        }
                    case .number(let stackNumber):
                        let formattedEntryString = formatEntry(stackNumber)
                        if isPending && secondOperand != nil {
                            isPending = false
                        }
                        if isPending {
                            secondOperand = stackNumber
                            description += String(formattedEntryString)
                        } else {
                            result = stackNumber
                            description = String(formattedEntryString)
                        }
                    case .opcode(let stackOpcode):
                        if let operation = operations[stackOpcode] {
                            switch operation {
                            case .random:
                                let maxPossibleNum = Double(UInt32.max)
                                let arc4randomNum = Double(arc4random())
                                if isPending && secondOperand != nil {
                                    isPending = false
                                }
                                if isPending {
                                    secondOperand =
                                        arc4randomNum / maxPossibleNum
                                    description += stackOpcode
                                } else {
                                    result =
                                        arc4randomNum / maxPossibleNum
                                    description = stackOpcode
                                }
                            case .constant(let numericalValue):
                                if isPending && secondOperand != nil {
                                    isPending = false
                                }
                                if isPending {
                                    secondOperand = numericalValue
                                    description += stackOpcode
                                } else {
                                    result = numericalValue
                                    description = stackOpcode
                                }
                            case .unaryOperation(let function):
                                if result != nil {
                                    if isPending {
                                        var charsToRemove = 0
                                        if subExpressionDepth == 0 {
                                            let previousEntry = stack[index - 1]
                                            var lastEntry = ""
                                            switch previousEntry {
                                            case .opcode(let previousString):
                                                lastEntry = previousString
                                                charsToRemove =
                                                    lastEntry.characters.count
                                            case .number(let previousNumber):
                                                lastEntry =
                                                    formatEntry(previousNumber)
                                                charsToRemove =
                                                    lastEntry.characters.count
                                            case .mathvariable(let previousVariable):
                                                lastEntry = previousVariable
                                                charsToRemove =
                                                    lastEntry.characters.count
                                            }
                                            subExpression = lastEntry
                                        } else {
                                            charsToRemove =
                                                subExpression.characters.count
                                        }
                                        let rangeToRemove =
                                            description.index(
                                                description.endIndex,
                                                offsetBy: -charsToRemove
                                                )..<description.endIndex
                                        description.removeSubrange(rangeToRemove)
                                        subExpression = stackOpcode + "(" +
                                            subExpression + ")"
                                        description =
                                            description + subExpression
                                        result = function(secondOperand!)
                                        secondOperand = result!
                                    } else {
                                        description = stackOpcode + "(" +
                                            description + ")"
                                        result = function(result!)
                                    }
                                    subExpressionDepth += 1
                                }
                            case .binaryOperation(let function):
                                if result != nil {
                                    if isPending {
                                        performPendingBinaryOperation()
                                    }
                                    pendingBinaryOperation =
                                        PendingBinaryOperation(
                                            function: function,
                                            firstOperand: result!)
                                    if stackOpcode == "×" || stackOpcode == "÷" {
                                        description = "(" + description
                                            + ")" + stackOpcode
                                    } else {
                                        description += stackOpcode
                                    }
                                    isPending = true
                                    subExpressionDepth = 0
                                }
                            case .equals:
                                if pendingBinaryOperation != nil {
                                    performPendingBinaryOperation()
                                }
                                isPending = false
                                pendingBinaryOperation = nil
                                secondOperand = nil
                                subExpression = ""
                                subExpressionDepth = 0
                            case .clearHistory:
                                result = nil
                                description = " "
                                isPending = false
                                stack = []
                                pendingBinaryOperation = nil
                                secondOperand = nil
                                subExpression = ""
                                subExpressionDepth = 0
                            }
                        }
                        
                    }
                }
                return (result, isPending, description)
            } else {
                return (nil, false, "0")
            }
            
    }
    
    /// Ensures numbers are formatted not to be longer than necessary
    /// and does limit input to 9 integer digits
    private func formatEntry(_ stackNumber: Double) -> String {
        let rawStringValue = String(stackNumber)
        let formatTextFromStack = NumberFormatter()
        formatTextFromStack.maximumIntegerDigits = 9
        formatTextFromStack.minimumFractionDigits = 0
        formatTextFromStack.maximumFractionDigits = 6
        if let formattedTextNumber =
            formatTextFromStack.number(from: rawStringValue) {
            let formattedText = formatTextFromStack.string(from: formattedTextNumber)
            return formattedText!
        } else {
            return "error"
        }
    }
    
    
    /// Stores the result of each run of the calculator brain
    /// but does not share this tuple with the UI - see result, history, etc
    private var results: (result: Double?, isPending: Bool, description: String)
        = (nil, false, " ")
    
    /// Accumulator value as a Double if not nil
    var result: Double? {
        get {
            return results.result
        }
    }
    
    /// Accumulator history as a String if not nil
    var history: String? {
        get {
            return results.description
        }
    }
}
