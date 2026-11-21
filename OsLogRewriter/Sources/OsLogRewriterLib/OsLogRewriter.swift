// Copyright (c) 2010-2026 Contributors to the openHAB project
//
// See the NOTICE file(s) distributed with this work for additional
// information.
//
// This program and the accompanying materials are made available under the
// terms of the Eclipse Public License 2.0 which is available at
// http://www.eclipse.org/legal/epl-2.0
//
// SPDX-License-Identifier: EPL-2.0

import Foundation
import SwiftParser
import SwiftSyntax
import SwiftSyntaxBuilder

/// Helper class to recursively remove trivia from all syntax nodes
final class TriviaRemover: SyntaxRewriter {
    override func visit(_ token: TokenSyntax) -> TokenSyntax {
        token.with(\.leadingTrivia, []).with(\.trailingTrivia, [])
    }
}

final class OsLogRewriter: SyntaxRewriter {
    func buildLoggerCall(format: String, args: [ExprSyntax], severity: String, indentation: Trivia = []) -> ExprSyntax {
        var segments: [StringLiteralSegmentListSyntax.Element] = []

        // Handle simple case with no format arguments
        if args.isEmpty {
            segments.append(.stringSegment(StringSegmentSyntax(content: .stringSegment(format))))
        } else {
            // Split format string by common format specifiers and interleave with arguments
            let formatPatterns = ["%{public}@", "%{PUBLIC}@", "%@", "%d", "%ld", "%s"]

            var argIndex = 0

            // Find and replace format specifiers in order
            var remainingFormat = format

            for pattern in formatPatterns {
                while let range = remainingFormat.range(of: pattern), argIndex < args.count {
                    // Add text before the pattern
                    let beforeText = String(remainingFormat[..<range.lowerBound])
                    if !beforeText.isEmpty {
                        segments.append(.stringSegment(StringSegmentSyntax(content: .stringSegment(beforeText))))
                    }

                    // Handle the argument - check if it's already a string interpolation
                    let currentArg = args[argIndex]
                    let processedArg = simplifyStringInterpolation(currentArg)

                    // Clean trivia from the processed argument to prevent multiline formatting
                    let cleanedArg = cleanAllTrivia(from: processedArg)

                    // Add the interpolated argument
                    segments.append(.expressionSegment(ExpressionSegmentSyntax(
                        backslash: .backslashToken(),
                        leftParen: .leftParenToken(),
                        expressions: LabeledExprListSyntax {
                            LabeledExprSyntax(expression: cleanedArg)
                        },
                        rightParen: .rightParenToken()
                    )))

                    argIndex += 1
                    remainingFormat = String(remainingFormat[range.upperBound...])
                }
            }

            // Add any remaining text
            if !remainingFormat.isEmpty {
                segments.append(.stringSegment(StringSegmentSyntax(content: .stringSegment(remainingFormat))))
            }

            // If no format specifiers were found, just use the original format
            if segments.isEmpty {
                segments.append(.stringSegment(StringSegmentSyntax(content: .stringSegment(format))))
            }
        }

        let stringExpr = StringLiteralExprSyntax(
            openingQuote: .stringQuoteToken(),
            segments: StringLiteralSegmentListSyntax(segments),
            closingQuote: .stringQuoteToken()
        )

        return ExprSyntax(
            FunctionCallExprSyntax(
                leadingTrivia: .newline + indentation,
                calledExpression: ExprSyntax(
                    MemberAccessExprSyntax(
                        base: ExprSyntax(DeclReferenceExprSyntax(baseName: .identifier("logger"))),
                        name: .identifier(severity)
                    )
                ),
                leftParen: .leftParenToken(),
                arguments: LabeledExprListSyntax {
                    LabeledExprSyntax(
                        expression: ExprSyntax(stringExpr),
                        trailingComma: nil
                    )
                },
                rightParen: .rightParenToken()
            ).with(\.trailingTrivia, [])
        )
    }

    /// Helper function to recursively clean all trivia from a syntax node
    func cleanAllTrivia(from expr: ExprSyntax) -> ExprSyntax {
        let triviaRemover = TriviaRemover()
        return ExprSyntax(triviaRemover.visit(expr))
    }

    /// Helper function to extract indentation from trivia
    func extractIndentation(from trivia: Trivia) -> Trivia {
        // Look for the last newline and extract spaces/tabs after it
        var indentationPieces: [TriviaPiece] = []
        var foundNewline = false

        for piece in trivia.reversed() {
            switch piece {
            case .newlines, .carriageReturns, .carriageReturnLineFeeds:
                foundNewline = true
            case let .spaces(count):
                if foundNewline {
                    indentationPieces.append(.spaces(count))
                } else if !foundNewline {
                    // If we haven't found a newline yet, this might be leading spaces
                    indentationPieces.append(.spaces(count))
                }
            case let .tabs(count):
                if foundNewline {
                    indentationPieces.append(.tabs(count))
                } else if !foundNewline {
                    indentationPieces.append(.tabs(count))
                }
            default:
                if foundNewline {
                    break
                }
            }
        }

        return Trivia(pieces: indentationPieces.reversed())
    }

    /// Helper function to detect indentation from the context of the os_log call
    func detectIndentationLevel(_ node: FunctionCallExprSyntax) -> Trivia {
        // First try to extract from the node's own leading trivia
        let directIndentation = extractIndentation(from: node.leadingTrivia)
        if !directIndentation.isEmpty {
            return directIndentation
        }

        // If that doesn't work, try to find indentation by looking at the parent context
        // We'll walk up the syntax tree to find a node with meaningful indentation
        return findContextualIndentation(node) ?? Trivia.spaces(8) // fallback
    }

    /// Helper function to find indentation from parent context
    func findContextualIndentation(_ node: some SyntaxProtocol) -> Trivia? {
        var current: (any SyntaxProtocol)? = node

        while let currentNode = current {
            // Check if this node has meaningful leading trivia with indentation
            if let indentation = extractMeaningfulIndentation(from: currentNode.leadingTrivia) {
                return indentation
            }

            // Move to parent
            current = currentNode.parent
        }

        return nil
    }

    /// Helper function to extract meaningful indentation (non-empty)
    func extractMeaningfulIndentation(from trivia: Trivia) -> Trivia? {
        let extracted = extractIndentation(from: trivia)
        return extracted.isEmpty ? nil : extracted
    }

    /// Helper function to simplify string interpolations like "\(value)" to just value
    func simplifyStringInterpolation(_ expr: ExprSyntax) -> ExprSyntax {
        // Check if this is a string literal
        guard let stringLiteral = expr.as(StringLiteralExprSyntax.self) else {
            return expr
        }

        // Handle the case where the string literal is just a single interpolation
        // This could be 1 segment (just interpolation) or 3 segments (empty + interpolation + empty)

        if stringLiteral.segments.count == 1 {
            // Single segment - check if it's an interpolation
            if case let .expressionSegment(expressionSegment) = stringLiteral.segments.first,
               expressionSegment.expressions.count == 1,
               let innerExpr = expressionSegment.expressions.first?.expression {
                return innerExpr
            }
        } else if stringLiteral.segments.count == 3 {
            // Three segments - check if it's empty + interpolation + empty
            let segments = Array(stringLiteral.segments)

            // Check if first and last are empty string segments
            if case let .stringSegment(firstSegment) = segments[0],
               case let .expressionSegment(middleSegment) = segments[1],
               case let .stringSegment(lastSegment) = segments[2],
               firstSegment.content.text.isEmpty,
               lastSegment.content.text.isEmpty,
               middleSegment.expressions.count == 1,
               let innerExpr = middleSegment.expressions.first?.expression {
                return innerExpr
            }
        }

        // Otherwise return the original expression
        return expr
    }

    override func visit(_ node: FunctionCallExprSyntax) -> ExprSyntax {
        guard
            let calledExpression = node.calledExpression.as(DeclReferenceExprSyntax.self),
            calledExpression.baseName.text == "os_log"
        else {
            return super.visit(node)
        }

        // Detect the proper indentation level from context
        let originalIndentation = detectIndentationLevel(node)

        var messageArg: ExprSyntax?
        var formatArgs: [ExprSyntax] = []
        var severity = "info" // Default fallback

        // Parse arguments in order
        for arg in node.arguments {
            switch arg.label?.text {
            case nil:
                // Unlabeled arguments - first is message, rest are format args
                if messageArg == nil {
                    messageArg = arg.expression
                } else {
                    formatArgs.append(arg.expression)
                }

            case "log":
                // Skip the log parameter (e.g., log: .default)
                continue

            case "type":
                if let severityArg = arg.expression.as(MemberAccessExprSyntax.self) {
                    switch severityArg.declName.baseName.text {
                    case "debug":
                        severity = "debug"
                    case "info":
                        severity = "info"
                    case "error", "fault":
                        severity = "error"
                    default:
                        severity = "info"
                    }
                }

            default:
                // Any other labeled arguments are treated as format args
                formatArgs.append(arg.expression)
            }
        }

        guard let msg = messageArg?.as(StringLiteralExprSyntax.self) else {
            // If we can't parse the message as a string literal, skip transformation
            return super.visit(node)
        }

        let format = msg.segments.compactMap { segment -> String in
            if let text = segment.as(StringSegmentSyntax.self)?.content.text {
                return text
            }
            return ""
        }
        .joined()

        // Clean up the format string - remove extra whitespace and normalize line breaks
        let cleanedFormat = format.replacingOccurrences(of: "\n", with: " ")
            .replacing(/\s+/, with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return buildLoggerCall(format: cleanedFormat, args: formatArgs, severity: severity, indentation: originalIndentation)
    }
}

/// Public API for the library
public func rewriteOsLogCalls(in sourceCode: String) throws -> String {
    let syntaxTree = Parser.parse(source: sourceCode)
    let rewriter = OsLogRewriter()
    let result = rewriter.visit(syntaxTree)
    return result.description
}

public func rewriteOsLogCallsInFile(at path: String) throws -> String {
    let sourceText = try String(contentsOfFile: path)
    return try rewriteOsLogCalls(in: sourceText)
}
