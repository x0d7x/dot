package main

import (
	"crypto/sha256"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"log"
	"os"
	"strings"

	"github.com/gorilla/websocket"
)

const (
	obsHost = "127.0.0.1"
	obsPort = "4455"

	// Change this if you enabled authentication in OBS.
	obsPassword = "VPNyL9FuhguTvGjC"
)

type Message struct {
	Op int             `json:"op"`
	D  json.RawMessage `json:"d"`
}

type Hello struct {
	ObsWebSocketVersion string `json:"obsWebSocketVersion"`
	RPCVersion          int    `json:"rpcVersion"`
	Authentication      *struct {
		Challenge string `json:"challenge"`
		Salt      string `json:"salt"`
	} `json:"authentication,omitempty"`
}

func makeAuthentication(password, salt, challenge string) string {
	// secret = Base64(SHA256(password + salt))
	h := sha256.Sum256([]byte(password + salt))
	secret := base64.StdEncoding.EncodeToString(h[:])

	// auth = Base64(SHA256(secret + challenge))
	h = sha256.Sum256([]byte(secret + challenge))

	return base64.StdEncoding.EncodeToString(h[:])
}

func send(ws *websocket.Conn, op int, data any) error {
	msg := Message{
		Op: op,
	}

	payload, err := json.Marshal(data)
	if err != nil {
		return err
	}

	msg.D = payload

	return ws.WriteJSON(msg)
}

func main() {
	if len(os.Args) < 2 {
		fmt.Println("Usage:")
		fmt.Println(`  obs-scene rdown`)
		fmt.Println(`  obs-scene uleft`)
		fmt.Println(`  obs-scene "start soon"`)
		fmt.Println(`  obs-scene brb`)
		fmt.Println(`  obs-scene cam`)
		os.Exit(1)
	}

	scene := strings.Join(os.Args[1:], " ")

	conn, _, err := websocket.DefaultDialer.Dial(
		"ws://"+obsHost+":"+obsPort,
		nil,
	)
	if err != nil {
		log.Fatalf("failed to connect to OBS: %v", err)
	}
	defer conn.Close()

	// 1. Receive OBS Hello

	var helloMsg Message

	if err := conn.ReadJSON(&helloMsg); err != nil {
		log.Fatalf("failed to receive Hello: %v", err)
	}

	if helloMsg.Op != 0 {
		log.Fatalf("expected Hello (op 0), got op %d", helloMsg.Op)
	}

	var hello Hello

	if err := json.Unmarshal(helloMsg.D, &hello); err != nil {
		log.Fatalf("invalid Hello message: %v", err)
	}

	// 2. Identify

	identify := map[string]any{
		"rpcVersion": hello.RPCVersion,
	}

	if hello.Authentication != nil {
		identify["authentication"] = makeAuthentication(
			obsPassword,
			hello.Authentication.Salt,
			hello.Authentication.Challenge,
		)
	}

	if err := send(conn, 1, identify); err != nil {
		log.Fatalf("failed to identify: %v", err)
	}

	var identified Message

	if err := conn.ReadJSON(&identified); err != nil {
		log.Fatalf("failed to receive Identified: %v", err)
	}

	if identified.Op != 2 {
		log.Fatalf("OBS identification failed (op %d)", identified.Op)
	}

	// 3. SetCurrentProgramScene

	request := map[string]any{
		"requestType": "SetCurrentProgramScene",
		"requestId":   "change-scene",
		"requestData": map[string]any{
			"sceneName": scene,
		},
	}

	if err := send(conn, 6, request); err != nil {
		log.Fatalf("failed to switch scene: %v", err)
	}

	var response Message

	for {
		if err := conn.ReadJSON(&response); err != nil {
			log.Fatalf("failed to receive response: %v", err)
		}

		// OBS events are op 5.
		// Ignore them and wait for the actual request response.
		if response.Op == 5 {
			continue
		}

		if response.Op == 7 {
			break
		}

		log.Fatalf("unexpected response op: %d", response.Op)
	}

	var responseData struct {
		RequestStatus struct {
			Result  bool   `json:"result"`
			Code    int    `json:"code"`
			Comment string `json:"comment"`
		} `json:"requestStatus"`
	}

	if err := json.Unmarshal(response.D, &responseData); err != nil {
		log.Fatalf("invalid response: %v", err)
	}

	if !responseData.RequestStatus.Result {
		log.Fatalf(
			"OBS rejected scene change: %s",
			responseData.RequestStatus.Comment,
		)
	}

	fmt.Println("Scene:", scene)
}
