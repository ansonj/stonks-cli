import Foundation

enum TableCellAlignment {
    case left
    case right
}

enum TerminalTextColor: Int {
    // https://github.com/mtynior/ColorizeSwift/blob/master/Source/ColorizeSwift.swift
    case black = 0
    case red = 31
    case green = 32
    case yellow = 33
    case blue = 34

    var codeString: String {
        return "\u{001B}[\(self.rawValue)m"
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
                let newText: String
                switch alignment {
                case .left:
                    newText = cell.text + padding
                case .right:
                    newText = padding + cell.text
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
        
        let lengthOfLongestLine = finalLines.map({ $0.count }).max() ?? 0
        finalLines.insert(String(repeating: "-", count: lengthOfLongestLine), at: 1)
        
        return finalLines.joined(separator: "\n")
    }
}
