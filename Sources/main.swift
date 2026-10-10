import Foundation

enum Failure: Error, CustomStringConvertible {
    case invalid(String)
    var description: String { switch self { case .invalid(let message): return message } }
}
func require(_ condition: Bool, _ message: String) throws {
    if !condition { throw Failure.invalid(message) }
}
func numeric(_ value: String) throws -> Double {
    guard let parsed = Double(value), parsed.isFinite else { throw Failure.invalid("Finite number required") }
    return parsed
}
func input(_ columns: Int) throws -> [[String]] {
    var rows: [[String]] = []
    while let line = readLine() {
        try require(rows.count < 100000, "Input capacity exceeded")
        try require(line.utf8.count <= 8192, "Input record too large")
        let fields = line.split(separator: ",", omittingEmptySubsequences: false).map(String.init)
        try require(fields.count == columns && fields.allSatisfy { !$0.isEmpty }, "Invalid CSV row")
        rows.append(fields)
    }
    try require(!rows.isEmpty, "Missing input")
    return rows
}
func output<T: Encodable>(_ value: T) throws {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    let data = try encoder.encode(value)
    guard let text = String(data: data, encoding: .utf8) else { throw Failure.invalid("Encoding failed") }
    print(text)
}

struct Survey { let year: Double; let thickness: Double }
struct Forecast: Codable {
    let slopeMmPerYear: Double
    let slopeSigma: Double
    let currentThickness: Double
    let remainingYears: Double?
    let proposedInspectionYears: Double
}
func forecast(_ surveys: [Survey], minimum: Double) throws -> Forecast {
    try require(surveys.count >= 3 && minimum > 0, "At least three surveys and positive minimum thickness required")
    var previous = -Double.infinity
    for survey in surveys { try require(survey.year > previous && survey.thickness > 0, "Invalid survey order or thickness"); previous = survey.year }
    let n = Double(surveys.count)
    let meanTime = surveys.reduce(0) { $0 + $1.year } / n
    let meanThickness = surveys.reduce(0) { $0 + $1.thickness } / n
    let xx = surveys.reduce(0) { $0 + pow($1.year - meanTime, 2) }
    let xy = surveys.reduce(0) { $0 + ($1.year - meanTime) * ($1.thickness - meanThickness) }
    let slope = xy / xx
    let residual = surveys.reduce(0) { $0 + pow($1.thickness - meanThickness - slope * ($1.year - meanTime), 2) }
    let sigma = sqrt(residual / (n - 2) / xx)
    let current = surveys.last!.thickness
    let rate = max(0, -slope + 2 * sigma)
    let remaining: Double? = current <= minimum ? 0 : (rate > 1e-12 ? (current - minimum) / rate : nil)
    return Forecast(slopeMmPerYear: slope, slopeSigma: sigma, currentThickness: current, remainingYears: remaining, proposedInspectionYears: min(2, max(0, (remaining ?? 4) / 2)))
}
func test() throws {
    let f = try forecast([Survey(year: 0, thickness: 10), Survey(year: 1, thickness: 9.5), Survey(year: 2, thickness: 9)], minimum: 7)
    try require(abs(f.slopeMmPerYear + 0.5) < 1e-12 && f.remainingYears == 4, "Loss forecast mismatch")
    let noLoss = try forecast([Survey(year: 0, thickness: 10), Survey(year: 1, thickness: 10), Survey(year: 2, thickness: 10)], minimum: 7)
    try require(noLoss.remainingYears == nil, "Stable wall must have no finite extrapolation")
}
func run() throws {
    let surveys = try input(2).map { Survey(year: try numeric($0[0]), thickness: try numeric($0[1])) }
    try output(forecast(surveys, minimum: 7))
}

do {
    try require(CommandLine.arguments.count == 1 || Array(CommandLine.arguments.dropFirst()) == ["--self-test"], "Unsupported command arguments")
    if Array(CommandLine.arguments.dropFirst()) == ["--self-test"] { try test(); print("Tests passed") }
    else { try run() }
} catch {
    FileHandle.standardError.write(Data("\(error)\n".utf8))
    exit(2)
}
