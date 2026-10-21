package zettatorrent

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"math/rand"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"github.com/anacrolix/torrent"
	"github.com/anacrolix/torrent/bencode"
	"github.com/anacrolix/torrent/metainfo"
	"github.com/anacrolix/torrent/storage"
	"golang.org/x/time/rate"
)

// offline keeps a client off the network: no DHT, no tracker, no port
// forwarding, and only the loopback address.
func offline(cfg *torrent.ClientConfig) {
	cfg.NoDHT = true
	cfg.DisableTrackers = true
	cfg.NoDefaultPortForwarding = true
	cfg.DisableIPv6 = true
	cfg.DisableWebseeds = true
	cfg.ListenHost = func(string) string { return "127.0.0.1" }
	cfg.ListenPort = 0
}

// seed makes a torrent from local files and seeds it from a second client
// on 127.0.0.1. It gives the info hash, the data of the video, and the
// address of the seeder.
func seed(t *testing.T) (hash string, video []byte, addr string) {
	t.Helper()
	base := t.TempDir()
	root := filepath.Join(base, "Show")
	if err := os.MkdirAll(root, 0o755); err != nil {
		t.Fatal(err)
	}
	video = make([]byte, 3*1024*1024+12345)
	rand.New(rand.NewSource(1)).Read(video)
	if err := os.WriteFile(filepath.Join(root, "episode.mkv"), video, 0o644); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(root, "notes.txt"), bytes.Repeat([]byte("x"), 5*1024*1024), 0o644); err != nil {
		t.Fatal(err)
	}
	info := metainfo.Info{PieceLength: 256 * 1024}
	if err := info.BuildFromFilePath(root); err != nil {
		t.Fatal(err)
	}
	var mi metainfo.MetaInfo
	var err error
	if mi.InfoBytes, err = bencode.Marshal(info); err != nil {
		t.Fatal(err)
	}
	cfg := torrent.NewDefaultClientConfig()
	offline(cfg)
	cfg.Seed = true
	cfg.DataDir = base
	cfg.DefaultStorage = storage.NewFile(base)
	cl, err := torrent.NewClient(cfg)
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { cl.Close() })
	tt, err := cl.AddTorrent(&mi)
	if err != nil {
		t.Fatal(err)
	}
	if err := tt.VerifyData(); err != nil {
		t.Fatal(err)
	}
	if got := tt.BytesCompleted(); got != tt.Length() {
		t.Fatalf("the seeder has %d of %d bytes", got, tt.Length())
	}
	return mi.HashInfoBytes().HexString(), video, cl.ListenAddrs()[0].String()
}

// startEngine starts the engine offline. It gives each new torrent the
// address of the seeder.
func startEngine(t *testing.T, seeder string) string {
	t.Helper()
	configure = offline
	onAdded = func(tt *torrent.Torrent) {
		if seeder != "" {
			tt.AddPeers([]torrent.PeerInfo{{Addr: stringAddr(seeder), Trusted: true}})
		}
	}
	dir := t.TempDir()
	if err := Start(dir, -1); err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() {
		shutdown()
		configure = func(*torrent.ClientConfig) {}
		onAdded = func(*torrent.Torrent) {}
	})
	return dir
}

type stringAddr string

func (s stringAddr) String() string { return string(s) }

func get(t *testing.T, url, rangeHeader string) (*http.Response, []byte) {
	t.Helper()
	req, err := http.NewRequest(http.MethodGet, url, nil)
	if err != nil {
		t.Fatal(err)
	}
	if rangeHeader != "" {
		req.Header.Set("Range", rangeHeader)
	}
	c := http.Client{Timeout: 30 * time.Second}
	resp, err := c.Do(req)
	if err != nil {
		t.Fatal(err)
	}
	defer resp.Body.Close()
	body, err := io.ReadAll(resp.Body)
	if err != nil {
		t.Fatal(err)
	}
	return resp, body
}

func TestPlayStreamsAFileFromALocalSeeder(t *testing.T) {
	hash, video, addr := seed(t)
	dir := startEngine(t, addr)
	if Port() == 0 {
		t.Fatal("the server has no port")
	}

	u, err := Play(strings.ToUpper(hash), -1, "tracker:udp://tracker.invalid:1/announce\ndht:node", "Show")
	if err != nil {
		t.Fatal(err)
	}
	// The largest file is the text file. Play takes the video.
	want := fmt.Sprintf("http://127.0.0.1:%d/stream/%s/0", Port(), hash)
	if u != want {
		t.Fatalf("URL = %q, want %q", u, want)
	}

	// A range in the middle, as after a seek.
	resp, body := get(t, u, "bytes=1000000-1099999")
	if resp.StatusCode != http.StatusPartialContent {
		t.Fatalf("status = %d", resp.StatusCode)
	}
	if got := resp.Header.Get("Content-Range"); got != fmt.Sprintf("bytes 1000000-1099999/%d", len(video)) {
		t.Errorf("Content-Range = %q", got)
	}
	if got := resp.Header.Get("Content-Type"); got != "video/x-matroska" {
		t.Errorf("Content-Type = %q", got)
	}
	if !bytes.Equal(body, video[1000000:1100000]) {
		t.Error("the range does not agree with the file")
	}

	// The last bytes, which a player reads for the index.
	resp, body = get(t, u, "bytes=-5000")
	if resp.StatusCode != http.StatusPartialContent || !bytes.Equal(body, video[len(video)-5000:]) {
		t.Errorf("the suffix range does not agree with the file (status %d)", resp.StatusCode)
	}

	// The full file.
	resp, body = get(t, u, "")
	if resp.StatusCode != http.StatusOK || resp.Header.Get("Accept-Ranges") != "bytes" {
		t.Errorf("status = %d, Accept-Ranges = %q", resp.StatusCode, resp.Header.Get("Accept-Ranges"))
	}
	if !bytes.Equal(body, video) {
		t.Error("the full file does not agree with the file")
	}

	// A second Play of the same torrent gives the same URL at once.
	again, err := Play(hash, -1, "", "")
	if err != nil || again != u {
		t.Errorf("second Play = %q, %v", again, err)
	}

	var st statsJSON
	if err := json.Unmarshal([]byte(Stats(hash)), &st); err != nil {
		t.Fatal(err)
	}
	if st.FileSize != int64(len(video)) || st.FileDone != int64(len(video)) {
		t.Errorf("stats: file %d of %d, want %d of %d", st.FileDone, st.FileSize, len(video), len(video))
	}
	if st.Window != 24*mb {
		t.Errorf("stats: window = %d", st.Window)
	}

	// The engine does not download the files that do not play.
	tt, _ := eng.client.Torrent(mustHash(t, hash))
	if notes := tt.Files()[1]; notes.BytesCompleted() == notes.Length() {
		t.Error("the engine downloaded the text file")
	}

	Stop(hash)
	if Stats(hash) != "" {
		t.Error("Stats gives data after Stop")
	}
	if _, err := os.Stat(filepath.Join(dir, "torrents", hash)); !os.IsNotExist(err) {
		t.Errorf("the files of the torrent are still there: %v", err)
	}
	if resp, _ := get(t, u, ""); resp.StatusCode != http.StatusNotFound {
		t.Errorf("status after Stop = %d, want 404", resp.StatusCode)
	}
}

func TestPlayTakesThePreferredFile(t *testing.T) {
	hash, _, addr := seed(t)
	startEngine(t, addr)
	// Index 1 is the text file, so Play takes the video.
	u, err := Play(hash, 1, "", "")
	if err != nil {
		t.Fatal(err)
	}
	if !strings.HasSuffix(u, "/0") {
		t.Errorf("URL = %q, want the video at index 0", u)
	}
	StopAll()
	if Stats(hash) != "" {
		t.Error("Stats gives data after StopAll")
	}
}

func TestPlayStopsWhenNoPeerSendsTheInformation(t *testing.T) {
	startEngine(t, "")
	old := metadataTimeout
	metadataTimeout = 300 * time.Millisecond
	t.Cleanup(func() { metadataTimeout = old })
	if _, err := Play(testHash, -1, "", ""); err == nil {
		t.Fatal("Play did not fail")
	}
	if n := len(eng.client.Torrents()); n != 0 {
		t.Errorf("%d torrents are still open", n)
	}
}

func TestStopEndsAPlayThatWaitsForTheInformation(t *testing.T) {
	startEngine(t, "")
	done := make(chan error, 1)
	go func() {
		_, err := Play(testHash, -1, "", "")
		done <- err
	}()
	// Wait until Play added the torrent.
	deadline := time.Now().Add(5 * time.Second)
	for len(eng.client.Torrents()) == 0 && time.Now().Before(deadline) {
		time.Sleep(10 * time.Millisecond)
	}
	Stop(testHash)
	select {
	case err := <-done:
		if err == nil {
			t.Error("Play did not fail")
		}
	case <-time.After(5 * time.Second):
		t.Fatal("Play still waits after Stop")
	}
}

func TestPlayRefusesATextThatIsNotAnInfoHash(t *testing.T) {
	startEngine(t, "")
	if _, err := Play("abc", -1, "", ""); err == nil {
		t.Error("Play did not fail")
	}
}

func TestPlayBeforeStartFails(t *testing.T) {
	if _, err := Play(testHash, -1, "", ""); err == nil {
		t.Error("Play did not fail")
	}
}

func TestStartRemovesTheDataOfAnEarlierRun(t *testing.T) {
	dir := t.TempDir()
	old := filepath.Join(dir, "torrents", "old", "file")
	if err := os.MkdirAll(filepath.Dir(old), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(old, []byte("x"), 0o644); err != nil {
		t.Fatal(err)
	}
	configure = offline
	t.Cleanup(func() { shutdown(); configure = func(*torrent.ClientConfig) {} })
	if err := Start(dir, 0); err != nil {
		t.Fatal(err)
	}
	if _, err := os.Stat(old); !os.IsNotExist(err) {
		t.Errorf("the old file is still there: %v", err)
	}
}

func mustHash(t *testing.T, hex string) metainfo.Hash {
	t.Helper()
	h, err := hashFromHex(hex)
	if err != nil {
		t.Fatal(err)
	}
	return h
}

func TestNewConfigLimitsTheUploadAndDoesNotSeed(t *testing.T) {
	cfg := newConfig(t.TempDir(), 4096)
	if cfg.Seed {
		t.Error("the client seeds")
	}
	if cfg.NoDHT {
		t.Error("the DHT is off")
	}
	l := cfg.UploadRateLimiter
	if l.Limit() != 4096 {
		t.Errorf("upload limit = %v, want 4096", l.Limit())
	}
	if l.Burst() < 16*1024 {
		t.Errorf("burst = %d, want at least one request of 16 KiB", l.Burst())
	}
}

func TestNewConfigWithZeroHasNoUploadLimit(t *testing.T) {
	cfg := newConfig(t.TempDir(), 0)
	if cfg.UploadRateLimiter.Limit() != rate.Inf {
		t.Errorf("upload limit = %v, want no limit", cfg.UploadRateLimiter.Limit())
	}
}
