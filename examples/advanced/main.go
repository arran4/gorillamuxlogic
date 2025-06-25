package main

import (
	. "github.com/arran4/gorillamuxlogic"
	"github.com/gorilla/mux"
	"net/http"
)

func RequiredScopes(scope string) mux.MatcherFunc {
	return func(r *http.Request, m *mux.RouteMatch) bool { return true }
}

func CommentAuthor() mux.MatcherFunc {
	return func(r *http.Request, m *mux.RouteMatch) bool { return true }
}

func articleEditPage(w http.ResponseWriter, r *http.Request) {}

func main() {
	mux.NewRouter().
		HandleFunc("/articles/{id}/edit", articleEditPage).
		MatcherFunc(
			Or(
				And(RequiredScopes("administrator"), CommentAuthor()),
				And(RequiredScopes("editor"), Not(CommentAuthor())),
			),
		).
		Methods("POST")
}
