package main

import (
	"fmt"
	"log"
	"net/http"

	logic "github.com/arran4/gorillamuxlogic"
	"github.com/gorilla/mux"
)

// simple matcher checking request header value
func HeaderEquals(name, value string) mux.MatcherFunc {
	return func(r *http.Request, rm *mux.RouteMatch) bool {
		return r.Header.Get(name) == value
	}
}

func main() {
	r := mux.NewRouter()

	// Route requires two headers using And
	r.HandleFunc("/and", func(w http.ResponseWriter, r *http.Request) {
		fmt.Fprintln(w, "matched AND route")
	}).MatcherFunc(logic.And(
		HeaderEquals("X-One", "1"),
		HeaderEquals("X-Two", "2"),
	))

	// Route matches if either header is present using Or
	r.HandleFunc("/or", func(w http.ResponseWriter, r *http.Request) {
		fmt.Fprintln(w, "matched OR route")
	}).MatcherFunc(logic.Or(
		HeaderEquals("X-Alpha", "A"),
		HeaderEquals("X-Beta", "B"),
	))

	// Route matches when the header is NOT present using Not
	r.HandleFunc("/not", func(w http.ResponseWriter, r *http.Request) {
		fmt.Fprintln(w, "matched NOT route")
	}).MatcherFunc(logic.Not(
		HeaderEquals("X-Block", "true"),
	))

	fmt.Println("Server listening on :8080")
	fmt.Println("Try these curl commands:")
	fmt.Println("  curl -H 'X-One: 1' -H 'X-Two: 2' http://localhost:8080/and")
	fmt.Println("  curl -H 'X-Alpha: A' http://localhost:8080/or")
	fmt.Println("  curl http://localhost:8080/not")
	fmt.Println("  curl -H 'X-Block: true' http://localhost:8080/not  # This will 404")

	if err := http.ListenAndServe(":8080", r); err != nil {
		log.Fatalf("Server failed: %v", err)
	}
}
