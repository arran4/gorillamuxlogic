package main

import (
	"fmt"
	"net/http"
	"net/http/httptest"
	"strings"

	. "github.com/arran4/gorillamuxlogic"
	"github.com/gorilla/mux"
)

// HasQueryParam is a request-dependent predicate that checks for the presence of a query parameter.
func HasQueryParam(param string) mux.MatcherFunc {
	return func(r *http.Request, m *mux.RouteMatch) bool {
		return r.URL.Query().Has(param)
	}
}

// MethodEquals is a request-dependent predicate that checks the HTTP method.
func MethodEquals(method string) mux.MatcherFunc {
	return func(r *http.Request, m *mux.RouteMatch) bool {
		return strings.EqualFold(r.Method, method)
	}
}

// HeaderEquals is a request-dependent predicate that checks if a header matches a value.
func HeaderEquals(name, value string) mux.MatcherFunc {
	return func(r *http.Request, m *mux.RouteMatch) bool {
		return r.Header.Get(name) == value
	}
}

func reportPage(w http.ResponseWriter, r *http.Request) {
	w.WriteHeader(http.StatusOK)
	w.Write([]byte("Report generated"))
}

func main() {
	r := mux.NewRouter()

	// An advanced example demonstrating nested `And`, `Or`, and `Not`.
	// Scenario: Generating a report.
	// Rule:
	//   1. Must be a GET request.
	//   2. AND (
	//        (Has "admin" query param)
	//        OR
	//        (Has Header "X-Role=manager" AND NOT (Has "draft" query param))
	//      )
	r.HandleFunc("/report", reportPage).
		MatcherFunc(
			And(
				MethodEquals("GET"),
				Or(
					HasQueryParam("admin"),
					And(
						HeaderEquals("X-Role", "manager"),
						Not(HasQueryParam("draft")),
					),
				),
			),
		)

	// Demonstration using httptest to show actual behavior without starting a server.
	requests := []*http.Request{
		// 1. GET with admin param -> Matches
		createRequest("GET", "/report?admin=1", ""),
		// 2. POST with admin param -> Does NOT match (wrong method)
		createRequest("POST", "/report?admin=1", ""),
		// 3. GET with manager role, not draft -> Matches
		createRequest("GET", "/report", "manager"),
		// 4. GET with manager role, but is draft -> Does NOT match (Not(draft) fails)
		createRequest("GET", "/report?draft=1", "manager"),
		// 5. GET with no role or params -> Does NOT match
		createRequest("GET", "/report", ""),
	}

	for i, req := range requests {
		w := httptest.NewRecorder()
		r.ServeHTTP(w, req)
		fmt.Printf("Request %d: %s %s [X-Role: %s] -> Status: %d\n",
			i+1, req.Method, req.URL.RequestURI(), req.Header.Get("X-Role"), w.Result().StatusCode)
	}
}

func createRequest(method, path, role string) *http.Request {
	req := httptest.NewRequest(method, path, nil)
	if role != "" {
		req.Header.Set("X-Role", role)
	}
	return req
}
