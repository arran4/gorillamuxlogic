# Gorilla Mux Logic

Simple primitive enabling logic like this:

```go
package main

import (
	. "github.com/arran4/gorillamuxlogic"
	"github.com/gorilla/mux"
)

func main() {
        r := mux.NewRouter()
        r.Use(UserMiddleware)
        r.HandleFunc("/blog/{blog}/comment/{comment}/edit", blogsCommentEditPage).
                MatcherFunc(Or(RequiredScopes("administrator"), CommentAuthor())).
                Methods("POST")
}
```

Examples of runnable programs can be found under the `examples/` directory.

Provides functions:
```go
func And(matchers ...mux.MatcherFunc) mux.MatcherFunc

func Or(matchers ...mux.MatcherFunc) mux.MatcherFunc

func Not(matcher mux.MatcherFunc) mux.MatcherFunc

```

Nested logic example:

```go
mux.NewRouter().
        HandleFunc("/articles/{id}/edit", articleEditPage).
        MatcherFunc(
                Or(
                        And(RequiredScopes("administrator"), CommentAuthor()),
                        And(RequiredScopes("editor"), Not(CommentAuthor())),
                ),
        ).
        Methods("POST")
```

## License

This project is licensed under the [MIT License](LICENSE).

## Edge Cases and Nil Policies

The combinators have specific behavior regarding empty and `nil` inputs to ensure predictable operation:

- `And()` with zero matchers returns a matcher that always returns `true`.
  - **Warning**: If you are dynamically constructing an authorization or filtering slice, be careful. An accidentally empty slice passed to `And()` acts as a "match-all" and will allow all requests to proceed.
- `Or()` with zero matchers returns a matcher that always returns `false`.
- `nil` matchers provided to `And`, `Or`, or `Not` are considered programmer errors. Passing a `nil` `mux.MatcherFunc` will cause an immediate panic during route construction time, pinpointing the invalid matcher, rather than failing intermittently later during request processing.

## Installation

To add this package to your project, run:

```
go get github.com/arran4/gorillamuxlogic
```
