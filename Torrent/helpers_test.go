package zettatorrent

import (
	"net/url"
	"strings"
	"testing"
)

const testHash = "0123456789ABCDEF0123456789ABCDEF01234567"

func TestIsInfoHash(t *testing.T) {
	cases := map[string]bool{
		testHash:                  true,
		strings.ToLower(testHash): true,
		testHash[:39]:             false,
		testHash + "0":            false,
		"g123456789abcdef0123456789abcdef01234567": false,
		"": false,
	}
	for in, want := range cases {
		if got := isInfoHash(in); got != want {
			t.Errorf("isInfoHash(%q) = %v, want %v", in, got, want)
		}
	}
}

func TestParseTrackersKeepsTrackersAndRemovesDHTNodes(t *testing.T) {
	got := parseTrackers("tracker:udp://a.example:1/announce\ndht:0123\n\n  http://b.example/announce  \ntracker:udp://a.example:1/announce\nnot a tracker")
	if len(got) != 2+len(defaultTrackers) {
		t.Fatalf("got %d trackers: %v", len(got), got)
	}
	if got[0] != "udp://a.example:1/announce" || got[1] != "http://b.example/announce" {
		t.Errorf("the trackers of the addon are not first: %v", got[:2])
	}
	for _, tr := range got {
		if strings.HasPrefix(tr, "dht:") {
			t.Errorf("a DHT node is in the list: %q", tr)
		}
	}
}

func TestParseTrackersDoesNotRepeatADefaultTracker(t *testing.T) {
	got := parseTrackers("tracker:" + defaultTrackers[0])
	if len(got) != len(defaultTrackers) {
		t.Errorf("got %d trackers, want %d", len(got), len(defaultTrackers))
	}
}

func TestMagnet(t *testing.T) {
	m := magnet(testHash, "tracker:udp://a.example:1/announce", "My Film (2020)")
	u, err := url.Parse(m)
	if err != nil {
		t.Fatal(err)
	}
	if u.Scheme != "magnet" {
		t.Fatalf("scheme = %q", u.Scheme)
	}
	q := u.Query()
	if got := q.Get("xt"); got != "urn:btih:"+strings.ToLower(testHash) {
		t.Errorf("xt = %q", got)
	}
	if got := q.Get("dn"); got != "My Film (2020)" {
		t.Errorf("dn = %q", got)
	}
	tr := q["tr"]
	if len(tr) != 1+len(defaultTrackers) || tr[0] != "udp://a.example:1/announce" {
		t.Errorf("tr = %v", tr)
	}
}

func TestMagnetWithNoNameHasNoDisplayName(t *testing.T) {
	if m := magnet(testHash, "", "  "); strings.Contains(m, "&dn=") {
		t.Errorf("magnet has a display name: %s", m)
	}
}

func TestChooseFile(t *testing.T) {
	names := []string{"Sample/sample.mkv", "readme.txt", "Film.mkv", "Film.srt", "extra.mp4"}
	sizes := []int64{50, 900, 800, 10, 700}
	cases := []struct {
		name      string
		preferred int
		want      int
	}{
		{"the preferred video", 4, 4},
		{"the largest video when there is no index", -1, 2},
		{"the largest video when the index is not a video", 1, 2},
		{"the largest video when the index is out of range", 9, 2},
	}
	for _, c := range cases {
		if got := chooseFile(names, sizes, c.preferred); got != c.want {
			t.Errorf("%s: got %d, want %d", c.name, got, c.want)
		}
	}
}

func TestChooseFileWithNoVideoTakesTheLargestFile(t *testing.T) {
	if got := chooseFile([]string{"a.txt", "b.zip", "c.nfo"}, []int64{1, 30, 2}, -1); got != 1 {
		t.Errorf("got %d, want 1", got)
	}
}

func TestChooseFileWithNoFile(t *testing.T) {
	if got := chooseFile(nil, nil, -1); got != -1 {
		t.Errorf("got %d, want -1", got)
	}
}

func TestWindowBytes(t *testing.T) {
	cases := map[int64]int64{
		100 * mb:   24 * mb,
		1500 * mb:  50 * mb,
		10000 * mb: 96 * mb,
	}
	for size, want := range cases {
		if got := windowBytes(size); got != want {
			t.Errorf("windowBytes(%d MB) = %d MB, want %d MB", size/mb, got/mb, want/mb)
		}
	}
}

func TestEdgePieces(t *testing.T) {
	// Pieces of 1 MB: 8 MB are 8 pieces.
	headEnd, tailBegin := edgePieces(10, 110, mb)
	if headEnd != 18 || tailBegin != 102 {
		t.Errorf("got head end %d and tail begin %d, want 18 and 102", headEnd, tailBegin)
	}
	// A file that is smaller than the head and the tail.
	headEnd, tailBegin = edgePieces(5, 8, mb)
	if headEnd != 8 || tailBegin != 5 {
		t.Errorf("got head end %d and tail begin %d, want 8 and 5", headEnd, tailBegin)
	}
	// Pieces that are larger than 8 MB give one piece at each end.
	headEnd, tailBegin = edgePieces(0, 4, 16*mb)
	if headEnd != 1 || tailBegin != 3 {
		t.Errorf("got head end %d and tail begin %d, want 1 and 3", headEnd, tailBegin)
	}
}

func TestMimeType(t *testing.T) {
	cases := map[string]string{
		"a.MKV":  "video/x-matroska",
		"a.mp4":  "video/mp4",
		"a.webm": "video/webm",
		"a.ts":   "video/mp2t",
		"a.bin":  "application/octet-stream",
		"a":      "application/octet-stream",
	}
	for in, want := range cases {
		if got := mimeType(in); got != want {
			t.Errorf("mimeType(%q) = %q, want %q", in, got, want)
		}
	}
}

func TestUploadLimit(t *testing.T) {
	if got := uploadLimit(-1); got != 4096 {
		t.Errorf("uploadLimit(-1) = %d, want 4096", got)
	}
	if got := uploadLimit(0); got != 0 {
		t.Errorf("uploadLimit(0) = %d, want 0", got)
	}
	if got := uploadLimit(9000); got != 9000 {
		t.Errorf("uploadLimit(9000) = %d, want 9000", got)
	}
}
