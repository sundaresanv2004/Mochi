/// What to call the computer in what the pet says and in the AI prompts.
enum Computer {
    #if os(Windows)
    static let name = "PC"
    #else
    static let name = "Mac"
    #endif
}
