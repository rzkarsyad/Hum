import Foundation

struct Track: Equatable, Hashable {
    let title: String
    let artist: String
    let album: String
    let duration: TimeInterval?

    init(title: String, artist: String, album: String, duration: TimeInterval? = nil) {
        self.title = title
        self.artist = artist
        self.album = album
        self.duration = duration
    }
}
