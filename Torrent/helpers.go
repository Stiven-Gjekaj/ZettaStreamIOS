package zettatorrent

import (
	"net/url"
	"path"
	"strings"
)

// defaultTrackers are public trackers. They help to find peers when the
// addon gives no tracker.
var defaultTrackers = []string{
	"udp://tracker.opentrackr.org:1337/announce",
	"udp://open.stealth.si:80/announce",
	"udp://tracker.torrent.eu.org:451/announce",
	"udp://exodus.desync.com:6969/announce",
	"udp://tracker.openbittorrent.com:6969/announce",
	"udp://open.demonii.com:1337/announce",
}

var videoExtensions = map[string]bool{
	"mkv": true, "mp4": true, "m4v": true, "avi": true, "webm": true, "mov": true,
	"ts": true, "m2ts": true, "wmv": true, "flv": true, "mpg": true, "mpeg": true,
}

const (
	mb = int64(1024 * 1024)
	// edgeBytes is the size of the head and of the tail of the file. A
	// player reads the index of the file there before it plays.
	edgeBytes = 8 * mb
	// minUpload is the default upload limit in bytes per second. Peers send
	// less to a client that sends nothing.
	minUpload = 4 * 1024
	// metadataTimeoutSeconds is the time that Play waits for the torrent
	// information.
	metadataTimeoutSeconds = 60
)

// isInfoHash tells if text is a 40 digit hex info hash.
func isInfoHash(text string) bool {
	if len(text) != 40 {
		return false
	}
	for _, c := range strings.ToLower(text) {
		if !(c >= '0' && c <= '9' || c >= 'a' && c <= 'f') {
			return false
		}
	}
	return true
}

// parseTrackers reads a list of trackers, one on each line. Stremio addons
// give a tracker as "tracker:udp://..." and a DHT node as "dht:...". The
// list keeps the trackers, removes the DHT nodes, and adds the default
// trackers. Each tracker occurs one time only.
func parseTrackers(text string) []string {
	seen := map[string]bool{}
	var out []string
	add := func(t string) {
		if t == "" || seen[t] {
			return
		}
		seen[t] = true
		out = append(out, t)
	}
	for _, line := range strings.Split(text, "\n") {
		line = strings.TrimSpace(line)
		switch {
		case strings.HasPrefix(line, "tracker:"):
			add(strings.TrimPrefix(line, "tracker:"))
		case strings.HasPrefix(line, "dht:"):
		case strings.Contains(line, "://"):
			add(line)
		}
	}
	for _, t := range defaultTrackers {
		add(t)
	}
	return out
}

// magnet makes a magnet link from an info hash, a list of trackers (one on
// each line), and a display name.
func magnet(infoHash, trackers, name string) string {
	var b strings.Builder
	b.WriteString("magnet:?xt=urn:btih:")
	b.WriteString(strings.ToLower(infoHash))
	if strings.TrimSpace(name) != "" {
		b.WriteString("&dn=")
		b.WriteString(url.QueryEscape(name))
	}
	for _, t := range parseTrackers(trackers) {
		b.WriteString("&tr=")
		b.WriteString(url.QueryEscape(t))
	}
	return b.String()
}

func extension(name string) string {
	return strings.ToLower(strings.TrimPrefix(path.Ext(name), "."))
}

// isVideo tells if the name has the extension of a video file.
func isVideo(name string) bool {
	return videoExtensions[extension(name)]
}

// chooseFile selects the file to play. It takes the preferred index when it
// is a video. Otherwise it takes the largest video, and the largest file
// when there is no video. It gives -1 when there is no file.
func chooseFile(names []string, sizes []int64, preferred int) int {
	if len(names) == 0 || len(names) != len(sizes) {
		return -1
	}
	if preferred >= 0 && preferred < len(names) && isVideo(names[preferred]) {
		return preferred
	}
	best := -1
	for i, n := range names {
		if isVideo(n) && (best < 0 || sizes[i] > sizes[best]) {
			best = i
		}
	}
	if best >= 0 {
		return best
	}
	for i := range names {
		if best < 0 || sizes[i] > sizes[best] {
			best = i
		}
	}
	return best
}

// windowBytes is the size of the window that downloads ahead of the read
// position: about 1/30 of the file, from 24 MB to 96 MB. A fixed large
// window downloads much data that a viewer who stops early never needs.
func windowBytes(fileSize int64) int64 {
	w := fileSize / 30
	if w < 24*mb {
		w = 24 * mb
	}
	if w > 96*mb {
		w = 96 * mb
	}
	return w
}

// edgePieces gives the piece ranges of the head and the tail of a file. The
// file has the pieces from begin to end, end not included. Each range is
// [first, last), and the two ranges can overlap.
func edgePieces(begin, end int, pieceLength int64) (headEnd, tailBegin int) {
	n := int((edgeBytes + pieceLength - 1) / pieceLength)
	if n < 1 {
		n = 1
	}
	headEnd = begin + n
	if headEnd > end {
		headEnd = end
	}
	tailBegin = end - n
	if tailBegin < begin {
		tailBegin = begin
	}
	return headEnd, tailBegin
}

// mimeType gives the content type for the name of a video file.
func mimeType(name string) string {
	switch extension(name) {
	case "mkv":
		return "video/x-matroska"
	case "mp4", "m4v", "mov":
		return "video/mp4"
	case "webm":
		return "video/webm"
	case "avi":
		return "video/x-msvideo"
	case "ts", "m2ts":
		return "video/mp2t"
	}
	return "application/octet-stream"
}

// uploadLimit gives the upload limit in bytes per second. A negative value
// gives the default limit. Zero means no limit.
func uploadLimit(bytesPerSecond int) int {
	if bytesPerSecond < 0 {
		return minUpload
	}
	return bytesPerSecond
}
