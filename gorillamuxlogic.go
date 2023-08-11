package gorillamuxlogic

import (
	"github.com/gorilla/mux"
	"net/http"
)

func And(matchers ...mux.MatcherFunc) mux.MatcherFunc {
	return func(request *http.Request, match *mux.RouteMatch) bool {
		for _, m := range matchers {
			if !m(request, match) {
				return false
			}
		}
		return true
	}
}

func Or(matchers ...mux.MatcherFunc) mux.MatcherFunc {
	return func(request *http.Request, match *mux.RouteMatch) bool {
		for _, m := range matchers {
			if m(request, match) {
				return true
			}
		}
		return false
	}
}

func Not(matcher mux.MatcherFunc) mux.MatcherFunc {
	return func(request *http.Request, match *mux.RouteMatch) bool {
		return !matcher(request, match)
	}
}
