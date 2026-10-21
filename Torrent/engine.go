// Package zettatorrent is the torrent engine of ZettaStream for iOS.
//
// It downloads one file of a torrent and serves it on 127.0.0.1, so that the
// player can play it before the download is complete. gomobile binds the
// exported functions of this package. They use only types that gomobile
// can bind.
package zettatorrent

import (
	"encoding/json"
	"errors"
	"fmt"
	"net"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"sync/atomic"
	"time"

	"github.com/anacrolix/torrent"
	"github.com/anacrolix/torrent/metainfo"
	"github.com/anacrolix/torrent/storage"
	"golang.org/x/time/rate"
)

// stream is one file of a torrent that the local server streams.
type stream struct {
	t       *torrent.Torrent
	file    *torrent.File
	index   int
	window  int64
	readPos atomic.Int64

	mu        sync.Mutex
	lastBytes int64
	lastTime  time.Time
	rate      int64
}

type engine struct {
	mu       sync.Mutex
	client   *torrent.Client
	dataDir  string
	server   *http.Server
	listener net.Listener
	streams  map[string]*stream
}

var eng = &engine{streams: map[string]*stream{}}

// configure changes the client configuration before the client starts.
// Tests use it to turn off the DHT and the trackers.
var configure = func(*torrent.ClientConfig) {}

// onAdded receives each torrent that Play adds, before Play waits for the
// information. Tests use it to give the address of a local peer.
var onAdded = func(*torrent.Torrent) {}

// metadataTimeout is the time that Play waits for the torrent information.
var metadataTimeout = metadataTimeoutSeconds * time.Second

// Start starts the torrent client and the local HTTP server. The engine
// keeps the data in dataDir and removes the data of an earlier run. The
// upload limit is in bytes per second. Zero means no limit, and a negative
// value gives the default limit of 4 KB/s. A second call does nothing.
func Start(dataDir string, uploadLimitBytesPerSecond int) error {
	eng.mu.Lock()
	defer eng.mu.Unlock()
	if eng.client != nil {
		return nil
	}
	if dataDir == "" {
		return errors.New("the data folder is empty")
	}
	dir := filepath.Join(dataDir, "torrents")
	// The data of an earlier run is not necessary. Remove it.
	if err := os.RemoveAll(dir); err != nil {
		return fmt.Errorf("remove old data: %w", err)
	}
	if err := os.MkdirAll(dir, 0o755); err != nil {
		return fmt.Errorf("make the data folder: %w", err)
	}
	cfg := newConfig(dir, uploadLimit(uploadLimitBytesPerSecond))
	configure(cfg)
	cl, err := torrent.NewClient(cfg)
	if err != nil {
		return fmt.Errorf("start the torrent client: %w", err)
	}
	// The URL says 127.0.0.1, so the server listens on that address only.
	// Only this device can connect.
	ln, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		cl.Close()
		return fmt.Errorf("start the local server: %w", err)
	}
	mux := http.NewServeMux()
	mux.HandleFunc("/stream/{hash}/{index}", serveStream)
	srv := &http.Server{Handler: mux, ReadHeaderTimeout: 10 * time.Second}
	go srv.Serve(ln)
	eng.client = cl
	eng.dataDir = dir
	eng.server = srv
	eng.listener = ln
	return nil
}

func newConfig(dir string, upload int) *torrent.ClientConfig {
	cfg := torrent.NewDefaultClientConfig()
	cfg.DataDir = dir
	// Each torrent has its own folder, so Stop can delete it. The engine
	// deletes the files, so it does not keep the piece state on disk.
	cfg.DefaultStorage = storage.NewFileOpts(storage.NewFileClientOpts{
		ClientBaseDir: dir,
		TorrentDirMaker: func(base string, _ *metainfo.Info, ih metainfo.Hash) string {
			return filepath.Join(base, ih.HexString())
		},
		PieceCompletion: storage.NewMapPieceCompletion(),
	})
	// The app does not seed after the download.
	cfg.Seed = false
	cfg.NoDHT = false
	// A random port does not collide with another app.
	cfg.ListenPort = 0
	if upload > 0 {
		// The burst must hold one request of 16 KiB, or the client panics.
		cfg.UploadRateLimiter = rate.NewLimiter(rate.Limit(upload), 16*1024)
	} else {
		cfg.UploadRateLimiter = rate.NewLimiter(rate.Inf, 0)
	}
	return cfg
}

// Port gives the port of the local HTTP server, or 0 before Start.
func Port() int {
	eng.mu.Lock()
	defer eng.mu.Unlock()
	if eng.listener == nil {
		return 0
	}
	return eng.listener.Addr().(*net.TCPAddr).Port
}

// Play adds the torrent, waits for its information, and starts the download
// of one file. It gives the local URL of that file. fileIdx is the index
// that the addon gave, or -1. trackers has one tracker on each line. Play
// can take up to a minute, so do not call it on the main thread.
func Play(infoHash string, fileIdx int, trackers string, displayName string) (string, error) {
	hash := strings.ToLower(strings.TrimSpace(infoHash))
	if !isInfoHash(hash) {
		return "", fmt.Errorf("%q is not an info hash", infoHash)
	}
	eng.mu.Lock()
	cl := eng.client
	if s := eng.streams[hash]; s != nil {
		eng.mu.Unlock()
		return streamURL(hash, s.index), nil
	}
	eng.mu.Unlock()
	if cl == nil {
		return "", errors.New("the engine is not started")
	}
	// One torrent gets the information and then the data, so the peers that
	// it finds keep sending.
	t, err := cl.AddMagnet(magnet(hash, trackers, displayName))
	if err != nil {
		return "", fmt.Errorf("add the torrent: %w", err)
	}
	onAdded(t)
	select {
	case <-t.GotInfo():
	case <-time.After(metadataTimeout):
		drop(hash, t)
		return "", fmt.Errorf("no peer sent the torrent information in %d seconds", int(metadataTimeout/time.Second))
	case <-cl.Closed():
		return "", errors.New("the engine stopped")
	}
	files := t.Files()
	names := make([]string, len(files))
	sizes := make([]int64, len(files))
	for i, f := range files {
		names[i] = f.DisplayPath()
		sizes[i] = f.Length()
	}
	index := chooseFile(names, sizes, fileIdx)
	if index < 0 {
		drop(hash, t)
		return "", errors.New("the torrent has no file")
	}
	for i, f := range files {
		if i != index {
			f.SetPriority(torrent.PiecePriorityNone)
		}
	}
	f := files[index]
	s := &stream{t: t, file: f, index: index, window: windowBytes(f.Length())}
	s.primeEdges()
	eng.mu.Lock()
	if eng.client != cl {
		eng.mu.Unlock()
		return "", errors.New("the engine stopped")
	}
	if old := eng.streams[hash]; old != nil {
		eng.mu.Unlock()
		return streamURL(hash, old.index), nil
	}
	eng.streams[hash] = s
	eng.mu.Unlock()
	return streamURL(hash, index), nil
}

// primeEdges downloads the head and the tail of the file before the player
// reads. A player reads the index of the file there. The pieces have a
// normal priority. The reader of the player gives a higher priority to the
// pieces at the read position, so those come first.
func (s *stream) primeEdges() {
	begin, end := s.file.BeginPieceIndex(), s.file.EndPieceIndex()
	if end <= begin {
		return
	}
	headEnd, tailBegin := edgePieces(begin, end, s.t.Info().PieceLength)
	for i := begin; i < headEnd; i++ {
		s.t.Piece(i).SetPriority(torrent.PiecePriorityNormal)
	}
	for i := tailBegin; i < end; i++ {
		s.t.Piece(i).SetPriority(torrent.PiecePriorityNormal)
	}
}

func streamURL(hash string, index int) string {
	return fmt.Sprintf("http://127.0.0.1:%d/stream/%s/%d", Port(), hash, index)
}

// statsJSON is the answer of Stats.
type statsJSON struct {
	Peers        int   `json:"peers"`
	Seeders      int   `json:"seeders"`
	DownloadRate int64 `json:"downloadRate"`
	FileDone     int64 `json:"fileDone"`
	FileSize     int64 `json:"fileSize"`
	ReadPosition int64 `json:"readPosition"`
	BufferAhead  int64 `json:"bufferAhead"`
	Window       int64 `json:"window"`
}

// Stats gives the state of a torrent as JSON, or an empty string when the
// torrent is not open. downloadRate is in bytes per second since the last
// call. fileDone counts the downloaded bytes of the file that plays.
// bufferAhead counts the downloaded bytes after the read position, up to the
// first missing piece.
func Stats(infoHash string) string {
	hash := strings.ToLower(strings.TrimSpace(infoHash))
	eng.mu.Lock()
	s := eng.streams[hash]
	eng.mu.Unlock()
	if s == nil {
		return ""
	}
	st := s.t.Stats()
	out := statsJSON{
		Peers:        st.ActivePeers,
		Seeders:      st.ConnectedSeeders,
		DownloadRate: s.sampleRate(st.BytesReadUsefulData.Int64()),
		FileDone:     s.file.BytesCompleted(),
		FileSize:     s.file.Length(),
		ReadPosition: s.readPos.Load(),
		BufferAhead:  s.bufferAhead(),
		Window:       s.window,
	}
	b, _ := json.Marshal(out)
	return string(b)
}

// sampleRate gives the download rate since the last sample. A sample that
// comes less than one second after the last one gives the last rate again.
func (s *stream) sampleRate(total int64) int64 {
	s.mu.Lock()
	defer s.mu.Unlock()
	now := time.Now()
	if s.lastTime.IsZero() {
		s.lastTime, s.lastBytes = now, total
		return 0
	}
	dt := now.Sub(s.lastTime)
	if dt < time.Second {
		return s.rate
	}
	s.rate = int64(float64(total-s.lastBytes) / dt.Seconds())
	s.lastTime, s.lastBytes = now, total
	return s.rate
}

func (s *stream) bufferAhead() int64 {
	info := s.t.Info()
	if info == nil {
		return 0
	}
	pl := info.PieceLength
	fileOff := s.file.Offset()
	end := fileOff + s.file.Length()
	pos := fileOff + s.readPos.Load()
	var have int64
	for p := int(pos / pl); p < s.file.EndPieceIndex(); p++ {
		if !s.t.Piece(p).State().Complete {
			break
		}
		pieceEnd := int64(p+1) * pl
		if pieceEnd > end {
			pieceEnd = end
		}
		from := int64(p) * pl
		if from < pos {
			from = pos
		}
		have += pieceEnd - from
	}
	return have
}

// Stop drops the torrent and deletes its files. The app does not seed after
// playback.
func Stop(infoHash string) {
	hash := strings.ToLower(strings.TrimSpace(infoHash))
	eng.mu.Lock()
	s := eng.streams[hash]
	delete(eng.streams, hash)
	eng.mu.Unlock()
	if s != nil {
		drop(hash, s.t)
		return
	}
	// Play can still wait for the information of this torrent.
	eng.mu.Lock()
	cl := eng.client
	eng.mu.Unlock()
	if cl == nil {
		return
	}
	if h, err := hashFromHex(hash); err == nil {
		if t, ok := cl.Torrent(h); ok {
			drop(hash, t)
		}
	}
}

// StopAll drops all torrents and deletes their files. The client and the
// server keep running.
func StopAll() {
	eng.mu.Lock()
	cl := eng.client
	eng.streams = map[string]*stream{}
	eng.mu.Unlock()
	if cl == nil {
		return
	}
	for _, t := range cl.Torrents() {
		drop(t.InfoHash().HexString(), t)
	}
}

// shutdown stops the client and the server. Tests use it to start again.
func shutdown() {
	StopAll()
	eng.mu.Lock()
	defer eng.mu.Unlock()
	if eng.server != nil {
		eng.server.Close()
	}
	if eng.client != nil {
		eng.client.Close()
	}
	eng.client, eng.server, eng.listener = nil, nil, nil
	eng.streams = map[string]*stream{}
}

func drop(hash string, t *torrent.Torrent) {
	t.Drop()
	eng.mu.Lock()
	dir := eng.dataDir
	eng.mu.Unlock()
	if dir != "" && isInfoHash(hash) {
		os.RemoveAll(filepath.Join(dir, strings.ToLower(hash)))
	}
}

func hashFromHex(hash string) (metainfo.Hash, error) {
	var h metainfo.Hash
	err := h.FromHexString(hash)
	return h, err
}
