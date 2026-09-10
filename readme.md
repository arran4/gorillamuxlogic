# Gorilla Mux Logic

Simple primitive enabling logic like this:

```go
package main

import (
	. "github.com/arran4/gorillamuxlogic"
	"github.com/gorilla/mux"
	"net/http"
)

// HeaderEquals is a request-dependent predicate that checks if a header matches a value.
func HeaderEquals(name, value string) mux.MatcherFunc {
	return func(r *http.Request, m *mux.RouteMatch) bool {
		return r.Header.Get(name) == value
	}
}

func actionPage(w http.ResponseWriter, r *http.Request) {
	w.WriteHeader(http.StatusOK)
	w.Write([]byte("Action allowed"))
}

func main() {
	r := mux.NewRouter()

	// An example demonstrating `Or` and `And` combining conditions.
	r.HandleFunc("/action", actionPage).
		MatcherFunc(Or(
			HeaderEquals("X-Role", "administrator"),
			And(
				HeaderEquals("X-Role", "user"),
				func(r *http.Request, m *mux.RouteMatch) bool { return r.Method == "GET" },
			),
		))
}
```

Examples of runnable programs can be found under the `examples/` directory.

You can observe the deterministic output by running them directly:

```bash
go run ./examples/basic
# Outputs matched/unmatched requests showing Or() and And() combinations

go run ./examples/advanced
# Outputs matched/unmatched requests demonstrating nested And(), Or(), and Not()

go run ./examples
# Starts a long-running server demonstrating real HTTP requests
# e.g., run: curl -H 'X-One: 1' -H 'X-Two: 2' http://localhost:8080/and
```

Provides functions:
```go
func And(matchers ...mux.MatcherFunc) mux.MatcherFunc

func Or(matchers ...mux.MatcherFunc) mux.MatcherFunc

func Not(matcher mux.MatcherFunc) mux.MatcherFunc

```

Nested logic example:

```go
// HasQueryParam checks for the presence of a query parameter.
func HasQueryParam(param string) mux.MatcherFunc {
	return func(r *http.Request, m *mux.RouteMatch) bool {
		return r.URL.Query().Has(param)
	}
}

// ... HeaderEquals from above ...

mux.NewRouter().
	HandleFunc("/report", reportPage).
	MatcherFunc(
		And(
			func(r *http.Request, m *mux.RouteMatch) bool { return r.Method == "GET" },
			Or(
				HasQueryParam("admin"),
				And(
					HeaderEquals("X-Role", "manager"),
					Not(HasQueryParam("draft")),
				),
			),
		),
	)
```

## License

This project is licensed under the [MIT License](LICENSE).

## Edge Cases and Nil Policies

The combinators have specific behavior regarding empty and `nil` inputs to ensure predictable operation:

- `And()` with zero matchers returns a matcher that always returns `true`.
  - **Warning**: If you are dynamically constructing an authorization or filtering slice, be careful. An accidentally empty slice passed to `And()` acts as a "match-all" and will allow all requests to proceed.
- `Or()` with zero matchers returns a matcher that always returns `false`.
- `nil` matchers provided to `And`, `Or`, or `Not` are considered programmer errors. Passing a `nil` `mux.MatcherFunc` will cause an immediate panic during route construction time, pinpointing the invalid matcher, rather than failing intermittently later during request processing.

## Go Version Compatibility

- **Minimum Supported Version:** Go 1.21.
- **Currently Tested Versions:** Go 1.21, Go 1.26 (oldstable), and Go 1.27 (stable).
- **Static Analysis (vet):** Only runs on the latest stable version (Go 1.27).
- **Release Verification:** The release gate in CI explicitly requires the success of tests across the entire version matrix before publishing.

## Installation

To add this package to your project, run:

```
go get github.com/arran4/gorillamuxlogic
```
