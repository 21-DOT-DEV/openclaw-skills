import NTaskLib

// Entry point for the ntask CLI executable
// This is a thin wrapper that delegates to NTaskLib for all functionality
@main
struct EntryPoint {
    static func main() async {
        await NTaskCommand.main()
    }
}
