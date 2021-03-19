import Foundation

enum TableCellAlignment {
    case left
    case right
}

enum TerminalTextColor: Int {
    // https://github.com/mtynior/ColorizeSwift/blob/master/Sources/ColorizeSwift/ColorizeSwift.swift
    case black = 0
    case red = 31
    case green = 32
    case yellow = 33
    case blue = 34

    var codeString: String {
        #if DEBUG
            return ""
        #else
            return "\u{001B}[\(self.rawValue)m"
        #endif
    }
}

struct HeaderCell {
    let text: String
    let alignment: TableCellAlignment
    
    init(_ text: String, alignment: TableCellAlignment = .left) {
        self.text = text
        self.alignment = alignment
    }
}

struct TableCell {
    let text: String
    let color: TerminalTextColor
    
    init(_ text: String, color: TerminalTextColor = .black) {
        self.text = text
        self.color = color
    }
}

struct Table {
    static func renderTable(withHeaders headers: [HeaderCell], rows: [[TableCell]]) -> String {
        // TODO: Improve formatting
        // - Add border around whole table?
        // - Add lines between each row?
        let columnCount = headers.count
        var columnWidths = headers.map { $0.text.count }
        rows.forEach { row in
            guard row.count == headers.count else {
                Prompt.exitStonks(withMessage: "Number of columns in a row didn't match number of headers")
            }
            (0..<columnCount).forEach { columnIndex in
                columnWidths[columnIndex] = max(columnWidths[columnIndex], row[columnIndex].text.count)
            }
        }
        
        var allRowsIncludingHeader = rows
        allRowsIncludingHeader.insert(headers.map({ TableCell($0.text) }), at: 0)
        
        var allRowsWithSpacing = [[TableCell]]()
        allRowsIncludingHeader.forEach { row in
            var spacedRow = [TableCell]()
            (0..<columnCount).forEach { columnIndex in
                let width = columnWidths[columnIndex]
                let alignment = headers[columnIndex].alignment
                let cell = row[columnIndex]
                let paddingWidthToAdd = width - cell.text.count
                let padding = String(repeating: " ", count: paddingWidthToAdd)
                var newText: String
                switch alignment {
                case .left:
                    newText = cell.text + padding
                case .right:
                    newText = padding + cell.text
                }
                if cell.color != .black {
                    newText = cell.color.codeString + newText + TerminalTextColor.black.codeString
                }
                spacedRow.append(TableCell(newText, color: cell.color))
            }
            allRowsWithSpacing.append(spacedRow)
        }
        
        let columnDivider = " | "
        var finalLines = [String]()
        allRowsWithSpacing.forEach { row in
            finalLines.append(row.map({ $0.text }).joined(separator: columnDivider))
        }
        
        // The header line won't have any colors, so we can get an accurate length from it
        let lengthOfSeparatorLine = finalLines[0].count
        finalLines.insert(String(repeating: "-", count: lengthOfSeparatorLine), at: 1)
        
        return finalLines.joined(separator: "\n")
    }
    
    static func renderQuickTable(withRows rows: [[String]]) -> String {
        let headers = [
            HeaderCell("", alignment: .left),
            HeaderCell("", alignment: .right)
        ]
        let tableRows = rows.map { (row: [String]) -> [TableCell] in
            let left = TableCell(row[0])
            let right = TableCell(row[1])
            return [left, right]
        }
        let table = Table.renderTable(withHeaders: headers, rows: tableRows)
        return table
    }
}
