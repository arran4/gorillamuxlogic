# Gorilla Mux Logic

Simple primitive enabling logic like this:

```go
package main

import (
	. "github.com/arran4/gorillamuxlogic"
	"github.com/gorilla/mux"
)

func main() {
	mux.NewRouter().
		Use(UserMiddleware).
		HandleFunc("/blog/{blog}/comment/{comment}/edit", blogsCommentEditPage).
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

<<<<<<< codex/add-example-for-nested-and/or-usage
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
=======
## License

This project is licensed under the [MIT License](LICENSE).

## Installation

To add this package to your project, run:

```
go get github.com/arran4/gorillamuxlogic
```


>>>>>>> main
