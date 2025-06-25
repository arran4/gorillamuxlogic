package gorillamuxlogic

import (
	"net/http"
	"testing"

	"github.com/gorilla/mux"
)

// helper matcher to track calls and return predefined result
func makeMatcher(result bool, counter *int) mux.MatcherFunc {
	return func(r *http.Request, m *mux.RouteMatch) bool {
		if counter != nil {
			*counter++
		}
		return result
	}
}

func newRequest() *http.Request {
	req, _ := http.NewRequest("GET", "/", nil)
	return req
}

func TestAnd_AllTrue(t *testing.T) {
	req := newRequest()
	m := And(makeMatcher(true, nil), makeMatcher(true, nil), makeMatcher(true, nil))
	if !m(req, &mux.RouteMatch{}) {
		t.Error("expected And to return true when all matchers are true")
	}
}

func TestAnd_ShortCircuitOnFalse(t *testing.T) {
	req := newRequest()
	var count int
	m := And(makeMatcher(true, &count), makeMatcher(false, &count), makeMatcher(true, &count))
	if m(req, &mux.RouteMatch{}) {
		t.Error("expected And to return false when any matcher is false")
	}
	if count != 2 {
		t.Errorf("expected And to stop after first false matcher, got %d", count)
	}
}

func TestOr_AnyTrue(t *testing.T) {
	req := newRequest()
	var count int
	m := Or(makeMatcher(false, &count), makeMatcher(false, &count), makeMatcher(true, &count))
	if !m(req, &mux.RouteMatch{}) {
		t.Error("expected Or to return true when any matcher is true")
	}
	if count != 3 {
		t.Errorf("expected Or to evaluate until first true matcher, got %d", count)
	}
}

func TestOr_AllFalse(t *testing.T) {
	req := newRequest()
	m := Or(makeMatcher(false, nil), makeMatcher(false, nil), makeMatcher(false, nil))
	if m(req, &mux.RouteMatch{}) {
		t.Error("expected Or to return false when all matchers are false")
	}
}

func TestNot_InvertsResult(t *testing.T) {
	req := newRequest()
	t1 := Not(makeMatcher(true, nil))
	if t1(req, &mux.RouteMatch{}) {
		t.Error("expected Not to invert true to false")
	}
	t2 := Not(makeMatcher(false, nil))
	if !t2(req, &mux.RouteMatch{}) {
		t.Error("expected Not to invert false to true")
	}
}
