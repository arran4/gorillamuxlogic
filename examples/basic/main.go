package main

import (
	"fmt"
	"net/http"
	"net/http/httptest"
	"strings"

	. "github.com/arran4/gorillamuxlogic"
	"github.com/gorilla/mux"
)

// HeaderEquals is a request-dependent predicate that checks if a header matches a value.
func HeaderEquals(name, value string) mux.MatcherFunc {
	return func(r *http.Request, m *mux.RouteMatch) bool {
		return r.Header.Get(name) == value
	}
}

// MethodEquals is a request-dependent predicate that checks the HTTP method.
func MethodEquals(method string) mux.MatcherFunc {
	return func(r *http.Request, m *mux.RouteMatch) bool {
		return strings.EqualFold(r.Method, method)
	}
}

func actionPage(w http.ResponseWriter, r *http.Request) {
	w.WriteHeader(http.StatusOK)
	w.Write([]byte("Action allowed"))
}

func main() {
	r := mux.NewRouter()

	// An example demonstrating `Or` and `And` combining conditions.
	// We want to allow the action if:
	//   The request has Header "X-Role" set to "administrator"
	//   OR
	//   (The request has Header "X-Role" set to "user" AND Method is "GET")
	r.HandleFunc("/action", actionPage).
		MatcherFunc(Or(
			HeaderEquals("X-Role", "administrator"),
			And(
				HeaderEquals("X-Role", "user"),
				MethodEquals("GET"),
			),
		))

	// Demonstration using httptest to show actual behavior without starting a server.
	requests := []*http.Request{
		// 1. Administrator doing POST -> Matches
		createRequest("POST", "/action", "X-Role", "administrator"),
		// 2. User doing GET -> Matches
		createRequest("GET", "/action", "X-Role", "user"),
		// 3. User doing POST -> Does NOT match (user only allowed GET)
		createRequest("POST", "/action", "X-Role", "user"),
		// 4. No role -> Does NOT match
		createRequest("GET", "/action", "", ""),
	}

	for i, req := range requests {
		w := httptest.NewRecorder()
		r.ServeHTTP(w, req)
		fmt.Printf("Request %d: %s %s [X-Role: %s] -> Status: %d\n",
			i+1, req.Method, req.URL.Path, req.Header.Get("X-Role"), w.Result().StatusCode)
	}
}

func createRequest(method, path, headerKey, headerVal string) *http.Request {
	req := httptest.NewRequest(method, path, nil)
	if headerKey != "" {
		req.Header.Set(headerKey, headerVal)
	}
	return req
}
