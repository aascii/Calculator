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
    case remove
}

/// Array of elements representing a mathematical formula
/// Note: may be empty, a single value, or an incomplete binary operation
private var stack = [Entries]()

/// Optional collection of stored variable names and matching values
private var variablesInMemory: [String: Double] = [:]

enum NumericalError: Error {
    case notANumber
    case infinite
}

// Due to external requirements, acquit this struct from being too long
//swiftlint:disable:next type_body_length
struct CalculatorBrain {
    /// Types of operations the calculator can perform
    private enum Operation {
        case constant(Double)
        case random
        case unaryOperation((Double) -> Double)
        case binaryOperation((Double, Double) -> Double)
        case equals
        case clearHistory
        case undo
    }

    private var operations: [String: Operation] = [
        "RND": Operation.random,
        "π": Operation.constant(Double.pi),
        "e": Operation.constant(M_E),
        "√": Operation.unaryOperation(sqrt),
        "𝑦ⁿ": Operation.binaryOperation(pow),
        "10ⁿ": Operation.unaryOperation(__exp10),
        "log": Operation.unaryOperation(log),
        "cos": Operation.unaryOperation(cos),
        "sin": Operation.unaryOperation(sin),
        "±": Operation.unaryOperation({ -$0 }),
        "×": Operation.binaryOperation({ $0 * $1 }),
        "÷": Operation.binaryOperation({ $0 / $1 }),
        "+": Operation.binaryOperation({ $0 + $1 }),
        "−": Operation.binaryOperation({ $0 - $1 }),
        "=": Operation.equals,
        "∁": Operation.clearHistory,
        "Undo": Operation.undo
    ]

    /// Inserts a mathematical operation onto the stack & runs the ALU if enough
    /// operands are available; or in the case of a binary operation with second
    /// operand not available yet, queues a pending operation.
    mutating func performOperation(_ symbol: String) {
        stack.append(Entries.opcode(symbol))
    }

    /// Inserts operand into stack
    /// Note: this setOperand takes an unlabeled Double
    mutating func setOperand(_ operand: Double) {
        stack.append(Entries.number(operand))
    }

    /// Inserts operand into stack
    /// Note: this setOperand takes a labelled String, ie a mathematical variable
    mutating func setOperand(variable named: String) {
        stack.append(Entries.mathvariable(named))
    }

    /// Performs all the mathematical operations possible given the stack and
    /// a dictionary of mathematical variable names and values
    // Large Tuple return is an externally specified API requirement
    // disabled_rules: - large_tuple added to .swiftlint.yml
    // - cyclomatic_complexity is also disabled, and a bug should be filed for this
    func evaluate(using variables: [String: Double]? = nil)
        -> (result: Double?, isPending: Bool, description: String, error: String?) {
            if variables != nil {
                for (key, value) in variables! { variablesInMemory[key] = value }
            }
            if stack.isEmpty == false {

                var result: Double?
                var isPending = false
                var description = " "
                var secondOperand: Double? = nil
                var subExpressionDepth = 0
                var subExpression = ""
                var errorDescription: String?

                /// Stores pending operator with its first operand
                var pendingBinaryOperation: PendingBinaryOperation?

                /// Collection including a pending operator and its first operand
                struct PendingBinaryOperation {
                    let function: (Double, Double) -> Double
                    let firstOperand: Double
                    let opcode: String

                    func perform(with secondOperand: Double) -> Double { return function(firstOperand, secondOperand) }
                }

                func reportUnaryError(with numericalValue: Double) throws
                    -> Double {
                        if numericalValue.isNaN { throw NumericalError.notANumber }
                        if numericalValue.isInfinite { throw NumericalError.infinite }
                        return numericalValue
                }

                func reportBinaryError(with numericalValue: Double) throws
                    -> Double {
                        let resultValue = pendingBinaryOperation!.perform(with: numericalValue)
                        if resultValue.isNaN { throw NumericalError.notANumber }
                        if resultValue.isInfinite { throw NumericalError.infinite }
                        return resultValue
                }

                /// Represents main loop of calculator brain
                /// Sequences through stack entries to interpret operands and
                /// operators for evaluation, executing results in-line
                for (index, stackEntry) in stack.enumerated() {
                    switch stackEntry {
                    /// clear entry from previous .undo
                    case .remove:
                        stack.remove(at: (index + 1))
                        stack.remove(at: index)
                        return (result, isPending, description, errorDescription)
                    /// attempt to evaluate with an assigned variable
                    case .mathvariable(let stackVariable):
                        var keyValue: Double
                        if let substituteValue = variablesInMemory[stackVariable] {
                            keyValue = substituteValue
                        } else { keyValue = 0 }
                        if isPending && secondOperand != nil { isPending = false }
                        if isPending {
                            secondOperand = keyValue
                            description += String(stackVariable)
                        } else {
                            result = keyValue
                            description = String(stackVariable)
                        }
                    case .number(let stackNumber):
                        let formattedEntryString = formatEntry(stackNumber)
                        if isPending && secondOperand != nil { isPending = false }
                        if isPending {
                            secondOperand = stackNumber
                            description += String(formattedEntryString)
                        } else {
                            result = stackNumber
                            description = String(formattedEntryString)
                        }
                    case .opcode(let stackOpcode):

                        /// Returns result of pending binary operation:
                        /// Runs ALU clock on the pending operation with contents
                        /// from pending operation struct and accumulator;
                        /// Closes operation by clearing pending status
                        func performPendingBinaryOperation() {
                            do {
                                result = try reportBinaryError(with: secondOperand!)
                            } catch NumericalError.notANumber {
                                errorDescription = "Not A Number!" + "result from " +
                                    pendingBinaryOperation!.opcode + "(" + String(secondOperand!) + ")"
                                result = sqrt(-1) // force set result.isNaN
                            } catch NumericalError.infinite {
                                errorDescription = "infinite! " + "result from " +
                                    pendingBinaryOperation!.opcode + "(" + String(secondOperand!) + ")"
                                result = 1 / 0  // force set result.isInfinite
                            } catch {
                                errorDescription = "unknown Binary error!"
                            }
                            pendingBinaryOperation = nil
                        }

                        if let operation = operations[stackOpcode] {
                            switch operation {
                            case .undo:
                                if index > 0 {
                                    stack[index] = .remove
                                    stack[(index - 1)] = .remove
                                } else {
                                    stack = []
                                    return (result, isPending, description, errorDescription)
                                }
                            case .random:
                                let maxPossibleNum = Double(UInt32.max)
                                let arc4randomNum = Double(arc4random())
                                if isPending && secondOperand != nil { isPending = false }
                                if isPending {
                                    secondOperand = arc4randomNum / maxPossibleNum
                                    description += stackOpcode
                                } else {
                                    result = arc4randomNum / maxPossibleNum
                                    description = stackOpcode
                                }
                            case .constant(let numericalValue):
                                if isPending && secondOperand != nil { isPending = false }
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
                                            case .remove:
                                                // should never be here!
                                                errorDescription = "'undo' bug!"
                                            case .opcode(let previousString):
                                                lastEntry = previousString
                                                charsToRemove = lastEntry.count
                                            case .number(let previousNumber):
                                                lastEntry = formatEntry(previousNumber)
                                                charsToRemove = lastEntry.count
                                            case .mathvariable(let previousVariable):
                                                lastEntry = previousVariable
                                                charsToRemove = lastEntry.count
                                            }
                                            subExpression = lastEntry
                                        } else {
                                            charsToRemove = subExpression.count
                                        }
                                        let rangeToRemove =
                                            description.index(description.endIndex,
                                                              offsetBy: -charsToRemove)..<description.endIndex
                                        description.removeSubrange(rangeToRemove)
                                        subExpression = stackOpcode + "(" + subExpression + ")"
                                        description += subExpression
                                        do {
                                            result = try reportUnaryError(with: function(secondOperand!))
                                        } catch NumericalError.notANumber {
                                            errorDescription = "Not A Number!" + "result from " + stackOpcode +
                                                "(" + String(secondOperand!) + ")"
                                            result = sqrt(-1) // force set result.isNaN
                                        } catch NumericalError.infinite {
                                            errorDescription = "infinite! " + "result from " + stackOpcode +
                                                "(" + String(secondOperand!) + ")"
                                            result = 1 / 0  // force set result.isInfinite
                                        } catch {
                                            errorDescription = "unknown Unary error!"
                                        }
                                        secondOperand = result!
                                    } else {
                                        description = stackOpcode + "(" + description + ")"
                                        do {
                                            result = try reportUnaryError(with: function(result!))
                                        } catch NumericalError.notANumber {
                                            errorDescription = "Not A Number! " +
                                                "result from " + stackOpcode + "(" + String(result!) + ")"
                                            result = sqrt(-1) // force set result.isNaN
                                        } catch NumericalError.infinite {
                                            errorDescription = "infinite! " +
                                                "result from " + stackOpcode + "(" + String(result!) + ")"
                                            result = 1 / 0  // force set result.isInfinite
                                        } catch {
                                            errorDescription = "unknown Unary error!"
                                        }
                                    }
                                    subExpressionDepth += 1
                                }
                            case .binaryOperation(let function):
                                if result != nil {
                                    if isPending {
                                        performPendingBinaryOperation()
                                        secondOperand = nil
                                    }
                                    pendingBinaryOperation =
                                        PendingBinaryOperation(function: function, firstOperand: result!,
                                                               opcode: stackOpcode)
                                    if stackOpcode == "×" || stackOpcode == "÷" {
                                        description = "(" + description + ")" + stackOpcode
                                    } else {
                                        description += stackOpcode
                                    }
                                    isPending = true
                                    subExpressionDepth = 0
                                }
                            case .equals:
                                if pendingBinaryOperation != nil {
                                    performPendingBinaryOperation()
                                    secondOperand = nil
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
                                variablesInMemory = [:]
                                pendingBinaryOperation = nil
                                secondOperand = nil
                                subExpression = ""
                                subExpressionDepth = 0
                            }
                        }

                    }
                }
                return (result, isPending, description, errorDescription)
            } else {
                return (nil, false, "0", nil)
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
        if let formattedTextNumber = formatTextFromStack.number(from: rawStringValue) {
            let formattedText = formatTextFromStack.string(from: formattedTextNumber)
            return formattedText!
        } else {
            return "format bug!"
        }
    }

    /// DEPRECATE
    /// Accumulator value as a Double if not nil
    var result: Double? {
        let results = evaluate(using: nil)
        return results.result
    }

    /// DEPRECATE
    /// Accumulator history as a String if not nil
    var history: String? {
        let results = evaluate(using: nil)
        return results.description
    }

    /// DEPRECATE
    /// Stores "..." while in the middle of an operation; otherwise nil
    var resultIsPending: String? {
        let results = evaluate(using: nil)
        var resultPendingValue: String?
        if results.isPending {
            resultPendingValue = "..."
        } else {
            resultPendingValue = nil
        }
        return resultPendingValue
    }
}
