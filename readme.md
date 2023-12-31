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

Provides functions:
```go
func And(matchers ...mux.MatcherFunc) mux.MatcherFunc

func Or(matchers ...mux.MatcherFunc) mux.MatcherFunc

func Not(matcher mux.MatcherFunc) mux.MatcherFunc

```