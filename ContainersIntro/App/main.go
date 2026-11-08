package main

import (
    "fmt"
    "log"
    "net/http"
    "os"
    "time"
)

func main() {
    http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
        host, _ := os.Hostname()
        fmt.Fprintf(w, "Hello from container!\nHostname: %s\nPID: %d\nTime: %s\n",
            host, os.Getpid(), time.Now().Format(time.RFC3339))
    })
    http.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
        fmt.Fprintln(w, "OK")
    })
    log.Println("Server listening on :8080")
    log.Fatal(http.ListenAndServe(":8080", nil))
}
