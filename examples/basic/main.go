package main

import (
	. "github.com/arran4/gorillamuxlogic"
	"github.com/gorilla/mux"
	"net/http"
)

func UserMiddleware(next http.Handler) http.Handler { return next }

func RequiredScopes(scope string) mux.MatcherFunc {
	return func(r *http.Request, m *mux.RouteMatch) bool { return true }
}

func CommentAuthor() mux.MatcherFunc {
	return func(r *http.Request, m *mux.RouteMatch) bool { return true }
}

func blogsCommentEditPage(w http.ResponseWriter, r *http.Request) {}

func main() {
	mux.NewRouter().
		Use(UserMiddleware).
		HandleFunc("/blog/{blog}/comment/{comment}/edit", blogsCommentEditPage).
		MatcherFunc(Or(RequiredScopes("administrator"), CommentAuthor())).
		Methods("POST")
}
