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

// dummy handler for testing
type dummyHandler struct {
	id string
}

func (h dummyHandler) ServeHTTP(w http.ResponseWriter, r *http.Request) {}

// test matcher that mutates Handler
func mutatingMatcherHandler(result bool, id string) mux.MatcherFunc {
	return func(r *http.Request, m *mux.RouteMatch) bool {
		m.Handler = dummyHandler{id: id}
		return result
	}
}

// test matcher that mutates Route
func mutatingMatcherRoute(result bool, route *mux.Route) mux.MatcherFunc {
	return func(r *http.Request, m *mux.RouteMatch) bool {
		m.Route = route
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

// test matcher that mutates MatchErr
func mutatingMatcherErr(result bool, err error) mux.MatcherFunc {
	return func(r *http.Request, m *mux.RouteMatch) bool {
		m.MatchErr = err
		return result
	}
}

// test matcher that mutates Vars
func mutatingMatcherVars(result bool, key, value string) mux.MatcherFunc {
	return func(r *http.Request, m *mux.RouteMatch) bool {
		if m.Vars == nil {
			m.Vars = make(map[string]string)
		}
		m.Vars[key] = value
		return result
	}
}

func TestOr_RejectedBranchMutatesVars(t *testing.T) {
	req := newRequest()
	m1 := mutatingMatcherVars(false, "key1", "val1")
	m2 := mutatingMatcherVars(true, "key2", "val2")

	match := &mux.RouteMatch{Vars: map[string]string{"initial": "value"}}
	combinator := Or(m1, m2)

	if !combinator(req, match) {
		t.Error("expected Or to return true")
	}

	if match.Vars["key1"] != "" {
		t.Error("rejected branch leaked its Vars mutations")
	}
	if match.Vars["key2"] != "val2" {
		t.Error("successful branch did not commit its Vars mutations")
	}
	if match.Vars["initial"] != "value" {
		t.Error("initial Vars state was lost")
	}
}

func TestNot_NeverLeaksHandlerOrRouteMutations(t *testing.T) {
	req := newRequest()
	dummyRoute := &mux.Route{}
	m1 := And(mutatingMatcherHandler(true, "leaked"), mutatingMatcherRoute(true, dummyRoute))

	match := &mux.RouteMatch{Handler: dummyHandler{id: "initial_handler"}, Route: nil}
	combinator := Not(m1) // m1 returns true, Not returns false

	if combinator(req, match) {
		t.Error("expected Not to invert true to false")
	}

	if match.Handler == nil || match.Handler.(dummyHandler).id != "initial_handler" {
		t.Error("Not leaked child Handler mutation")
	}
	if match.Route != nil {
		t.Error("Not leaked child Route mutation")
	}

	m2 := And(mutatingMatcherHandler(false, "leaked_false"), mutatingMatcherRoute(false, dummyRoute))
	combinator2 := Not(m2) // m2 returns false, Not returns true
	match2 := &mux.RouteMatch{Handler: dummyHandler{id: "initial_handler"}, Route: nil}

	if !combinator2(req, match2) {
		t.Error("expected Not to invert false to true")
	}

	if match2.Handler == nil || match2.Handler.(dummyHandler).id != "initial_handler" {
		t.Error("Not leaked child Handler mutation on true result")
	}
	if match2.Route != nil {
		t.Error("Not leaked child Route mutation on true result")
	}
}

func TestAnd_HandlerAndRouteState(t *testing.T) {
	req := newRequest()
	dummyRouteIn := &mux.Route{}
	dummyRouteNew := &mux.Route{}

	m1 := mutatingMatcherHandler(true, "new_handler")
	m2 := mutatingMatcherRoute(true, dummyRouteNew)
	m3 := makeMatcher(false, nil) // fails

	match := &mux.RouteMatch{
		Handler: dummyHandler{id: "initial_handler"},
		Route:   dummyRouteIn,
	}
	combinator := And(m1, m2, m3)

	if combinator(req, match) {
		t.Error("expected And to return false")
	}

	if match.Handler == nil || match.Handler.(dummyHandler).id != "initial_handler" {
		t.Error("failed And leaked Handler mutations")
	}
	if match.Route != dummyRouteIn {
		t.Error("failed And leaked Route mutations")
	}

	// successful path
	combinatorSuccess := And(m1, m2)
	matchSuccess := &mux.RouteMatch{
		Handler: dummyHandler{id: "initial_handler"},
		Route:   dummyRouteIn,
	}

	if !combinatorSuccess(req, matchSuccess) {
		t.Error("expected And to return true")
	}

	if matchSuccess.Handler == nil || matchSuccess.Handler.(dummyHandler).id != "new_handler" {
		t.Error("successful And did not commit Handler mutations")
	}
	if matchSuccess.Route != dummyRouteNew {
		t.Error("successful And did not commit Route mutations")
	}
}

func TestOr_RejectedBranchMutatesMatchErr(t *testing.T) {
	req := newRequest()
	m1 := mutatingMatcherErr(false, mux.ErrMethodMismatch)
	m2 := makeMatcher(true, nil)

	match := &mux.RouteMatch{}
	combinator := Or(m1, m2)

	if !combinator(req, match) {
		t.Error("expected Or to return true")
	}

	if match.MatchErr != nil {
		t.Error("rejected branch leaked its MatchErr mutation")
	}
}

func TestOr_RejectedBranchMutatesHandlerAndRoute(t *testing.T) {
	req := newRequest()
	dummyRoute1 := &mux.Route{}
	dummyRoute2 := &mux.Route{}

	m1 := And(mutatingMatcherHandler(false, "rejected_handler"), mutatingMatcherRoute(false, dummyRoute1))
	m2 := And(mutatingMatcherHandler(true, "winning_handler"), mutatingMatcherRoute(true, dummyRoute2))

	match := &mux.RouteMatch{}
	combinator := Or(m1, m2)

	if !combinator(req, match) {
		t.Error("expected Or to return true")
	}

	if match.Handler == nil {
		t.Fatal("expected Handler to be set")
	}
	if match.Handler.(dummyHandler).id != "winning_handler" {
		t.Error("successful branch did not commit its Handler mutation")
	}
	if match.Route != dummyRoute2 {
		t.Error("successful branch did not commit its Route mutation")
	}
}

func TestAnd_FailedMatcherRestoresState(t *testing.T) {
	req := newRequest()
	m1 := mutatingMatcherVars(true, "key1", "val1")
	m2 := mutatingMatcherErr(false, mux.ErrMethodMismatch)

	match := &mux.RouteMatch{Vars: map[string]string{"initial": "value"}}
	combinator := And(m1, m2)

	if combinator(req, match) {
		t.Error("expected And to return false")
	}

	if match.Vars["key1"] != "" {
		t.Error("failed And leaked child mutations (Vars)")
	}
	if match.MatchErr != nil {
		t.Error("failed And leaked child mutations (MatchErr)")
	}
	if match.Vars["initial"] != "value" {
		t.Error("initial Vars state was lost")
	}
}

func TestAnd_SuccessfulMatcherPreservesState(t *testing.T) {
	req := newRequest()
	m1 := mutatingMatcherVars(true, "key1", "val1")
	m2 := mutatingMatcherVars(true, "key2", "val2")

	match := &mux.RouteMatch{Vars: map[string]string{"initial": "value"}}
	combinator := And(m1, m2)

	if !combinator(req, match) {
		t.Error("expected And to return true")
	}

	if match.Vars["key1"] != "val1" || match.Vars["key2"] != "val2" {
		t.Error("successful And did not preserve intentional accumulated state")
	}
	if match.Vars["initial"] != "value" {
		t.Error("initial Vars state was lost")
	}
}

func TestNot_NeverLeaksMutations(t *testing.T) {
	req := newRequest()
	m := mutatingMatcherVars(false, "key1", "val1")

	match := &mux.RouteMatch{Vars: map[string]string{"initial": "value"}}
	combinator := Not(m)

	if !combinator(req, match) {
		t.Error("expected Not to invert false to true")
	}

	if match.Vars["key1"] != "" {
		t.Error("Not leaked child mutations")
	}
	if match.Vars["initial"] != "value" {
		t.Error("initial Vars state was lost")
	}
}

func TestNestedCombinations(t *testing.T) {
	req := newRequest()
	// Or( And(false), And(true, true) )
	m1 := And(mutatingMatcherVars(true, "k1", "v1"), mutatingMatcherVars(false, "k2", "v2"))
	m2 := And(mutatingMatcherVars(true, "k3", "v3"), mutatingMatcherVars(true, "k4", "v4"))

	match := &mux.RouteMatch{Vars: map[string]string{"initial": "value"}}
	combinator := Or(m1, m2)

	if !combinator(req, match) {
		t.Error("expected nested combinator to return true")
	}

	if match.Vars["k1"] != "" || match.Vars["k2"] != "" {
		t.Error("rejected nested branch leaked mutations")
	}
	if match.Vars["k3"] != "v3" || match.Vars["k4"] != "v4" {
		t.Error("successful nested branch did not accumulate mutations")
	}
	if match.Vars["initial"] != "value" {
		t.Error("initial Vars state was lost")
	}
}
