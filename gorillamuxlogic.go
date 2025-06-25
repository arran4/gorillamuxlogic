// Package gorillamuxlogic supplies simple logical combinators for
// Gorilla Mux matcher functions. It enables existing matchers to be
// combined using AND, OR and NOT semantics when building routes.
package gorillamuxlogic

import (
	"github.com/gorilla/mux"
	"net/http"
)

// And returns a matcher that succeeds only when every provided matcher
// evaluates to true for the current request and route match.
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

// Or returns a matcher that succeeds when any of the provided matchers
// evaluate to true for the current request and route match.
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

// Not returns a matcher that inverts the result of the provided matcher.
func Not(matcher mux.MatcherFunc) mux.MatcherFunc {
	return func(request *http.Request, match *mux.RouteMatch) bool {
		return !matcher(request, match)
	}
}
