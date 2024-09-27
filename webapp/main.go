package main

import (
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"
)

type config struct {
	Username string
	Password string
}

func readJson() config {
	plan, _ := os.ReadFile("/vault/secrets/config")
	var data config
	err := json.Unmarshal(plan, &data)
	if err != nil {
		log.Fatal(err)
	}
	return data
}

// Handler functions.
func Home(w http.ResponseWriter, r *http.Request) {
	data := readJson()
	fmt.Fprintf(w, "Username: %s\nPassword: %s\n", data.Username, data.Password)
}

func main() {

	// Port we listen on.
	const portNum string = ":8080"

	log.Println("Starting our simple http server.")

	// Registering our handler functions, and creating paths.
	http.HandleFunc("/", Home)

	log.Println("Started on port", portNum)
	fmt.Println("To close connection CTRL+C :-)")

	// Spinning up the server.
	err := http.ListenAndServe(portNum, nil)
	if err != nil {
		log.Fatal(err)
	}
}
