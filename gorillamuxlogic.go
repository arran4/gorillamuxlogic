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
// It evaluates matchers in order against a working state. Successful child
// mutations may accumulate. If any child returns false, the caller-visible
// mux.RouteMatch is restored to its exact incoming state.
func And(matchers ...mux.MatcherFunc) mux.MatcherFunc {
	return func(request *http.Request, match *mux.RouteMatch) bool {
		workingMatch := cloneRouteMatch(match)
		for _, m := range matchers {
			if !m(request, workingMatch) {
				return false
			}
		}
		commitRouteMatch(match, workingMatch)
		return true
	}
}

// Or returns a matcher that succeeds when any of the provided matchers
// evaluate to true for the current request and route match.
// It evaluates each branch against an isolated mux.RouteMatch state,
// discarding state from false branches. When a branch succeeds, only the
// winning branch's resulting state is committed. Short-circuit ordering
// is preserved.
func Or(matchers ...mux.MatcherFunc) mux.MatcherFunc {
	return func(request *http.Request, match *mux.RouteMatch) bool {
		for _, m := range matchers {
			branchMatch := cloneRouteMatch(match)
			if m(request, branchMatch) {
				commitRouteMatch(match, branchMatch)
				return true
			}
		}
		return false
	}
}

// Not returns a matcher that inverts the result of the provided matcher.
// It evaluates the child matcher against an isolated state and never commits
// the child's mux.RouteMatch mutations, only returning its inverted boolean result.
func Not(matcher mux.MatcherFunc) mux.MatcherFunc {
	return func(request *http.Request, match *mux.RouteMatch) bool {
		isolatedMatch := cloneRouteMatch(match)
		return !matcher(request, isolatedMatch)
	}
}

// cloneRouteMatch performs a shallow copy of the mux.RouteMatch struct
// and a deep copy of the Vars map to ensure isolated state.
func cloneRouteMatch(match *mux.RouteMatch) *mux.RouteMatch {
	if match == nil {
		return nil
	}
	clone := *match
	if match.Vars != nil {
		clone.Vars = make(map[string]string, len(match.Vars))
		for k, v := range match.Vars {
			clone.Vars[k] = v
		}
	}
	return &clone
}

// commitRouteMatch overwrites the destination mux.RouteMatch with the
// contents of the isolated clone.
func commitRouteMatch(dst *mux.RouteMatch, src *mux.RouteMatch) {
	if dst == nil || src == nil {
		return
	}
	*dst = *src
}
