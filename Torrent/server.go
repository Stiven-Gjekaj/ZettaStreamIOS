package zettatorrent

import (
	"io"
	"net/http"
	"path"
	"strconv"
	"strings"
	"time"

	"github.com/anacrolix/torrent"
)

// serveStream sends a file of an open torrent. http.ServeContent reads the
// Range header, so the player can seek. The reader is responsive: it gives
// the data as soon as a piece is complete. Its read-ahead is the download
// window of the file, so the pieces after the read position download first.
func serveStream(w http.ResponseWriter, r *http.Request) {
	hash := strings.ToLower(r.PathValue("hash"))
	index, err := strconv.Atoi(r.PathValue("index"))
	if err != nil {
		http.NotFound(w, r)
		return
	}
	eng.mu.Lock()
	s := eng.streams[hash]
	eng.mu.Unlock()
	if s == nil || s.index != index {
		http.NotFound(w, r)
		return
	}
	reader := s.file.NewReader()
	defer reader.Close()
	reader.SetResponsive()
	reader.SetReadahead(s.window)
	// The read stops when the player closes the connection.
	reader.SetContext(r.Context())
	name := path.Base(s.file.DisplayPath())
	w.Header().Set("Content-Type", mimeType(name))
	http.ServeContent(w, r, name, time.Time{}, &trackedReader{Reader: reader, s: s})
}

// trackedReader records the read position, so that Stats can give the
// size of the buffer ahead of the player.
type trackedReader struct {
	torrent.Reader
	s   *stream
	pos int64
}

func (t *trackedReader) Read(b []byte) (int, error) {
	n, err := t.Reader.Read(b)
	t.pos += int64(n)
	t.s.readPos.Store(t.pos)
	return n, err
}

func (t *trackedReader) Seek(offset int64, whence int) (int64, error) {
	p, err := t.Reader.Seek(offset, whence)
	if err == nil {
		t.pos = p
		// ServeContent seeks to the end to find the size. That is not a
		// read position.
		if whence != io.SeekEnd {
			t.s.readPos.Store(p)
		}
	}
	return p, err
}
