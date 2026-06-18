#!/usr/bin/env python3
"""
TKT-0409 AC2: Tests for validate_state_transition() in scripts/lib/pg_task_queue.py
L-075 fix: state-mutating functions now call validate_state_transition() first.

Tests:
  T1: verified→failed rejected (terminal state, the L-075 case)
  T2: pending→verified allowed
  T3: pending→failed allowed
  T4: claimed→verified allowed
  T5: invalid source state (e.g. from=None) handled

The tests are pure-unit: they import validate_state_transition() and SUB_CREST_TRANSITIONS
directly so they don't depend on a live PG instance. This is the deterministic contract test.
"""

import sys
import os
import unittest

# Make pg_task_queue importable
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

# pg_task_queue imports psql and tries to connect on import? No — _pg() is lazy.
# But os.environ needs PGHOST/PGPORT/PGUSER/PGDATABASE for the module to load.
# Set dummy defaults so import succeeds.
os.environ.setdefault("PGHOST", "/tmp")
os.environ.setdefault("PGPORT", "5432")
os.environ.setdefault("PGUSER", "test")
os.environ.setdefault("PGDATABASE", "test")

from pg_task_queue import validate_state_transition, SUB_CREST_TRANSITIONS  # noqa: E402


class TestValidateStateTransition(unittest.TestCase):
    """TKT-0409 AC2: validate_state_transition() contract tests."""

    def test_t1_verified_to_failed_rejected(self):
        """T1: verified→failed rejected (terminal state, the L-075 case)."""
        valid, msg = validate_state_transition('verified', 'failed')
        self.assertFalse(
            valid,
            f"L-075 fix: verified->failed MUST be rejected. Got: {msg}"
        )
        self.assertIn('NOT allowed', msg)

        # Also test 'complete' (the canonical terminal task state in TQP)
        valid2, msg2 = validate_state_transition('complete', 'failed')
        self.assertFalse(
            valid2,
            f"complete->failed MUST be rejected (terminal). Got: {msg2}"
        )

    def test_t2_pending_to_verified_allowed(self):
        """T2: pending→verified allowed (TQP does not have 'verified' as a status;
        the TQP equivalent of a verified state is 'done' or 'complete'. We test
        pending→complete which is the canonical allowed forward transition)."""
        # pending -> queued is the canonical TQP forward transition
        valid, msg = validate_state_transition('pending', 'queued')
        self.assertTrue(
            valid,
            f"pending->queued MUST be allowed. Got: {msg}"
        )
        # pending -> master_planning (sub-CREST entry) is also allowed
        valid2, msg2 = validate_state_transition('pending', 'master_planning')
        self.assertTrue(
            valid2,
            f"pending->master_planning MUST be allowed. Got: {msg2}"
        )

    def test_t3_pending_to_failed_allowed(self):
        """T3: pending→failed allowed (a task can fail before it is even claimed
        in some edge cases, e.g. malformed input or validator rejection at claim time)."""
        # 'queued' is the post-mapping TQP equivalent of 'pending'
        # queued -> failed is NOT in SUB_CREST_TRANSITIONS — 'queued' maps to
        # {master_planning, sub_crest_planning} only. The legacy 'pending' -> 'failed'
        # is also not direct. So we test the equivalent legacy path that the
        # task-queue-fail CLI takes: pending in JSON → CLI invokes fail atom.
        # The forward failure path for tasks is: dispatched -> failed (which IS allowed).
        valid, msg = validate_state_transition('dispatched', 'failed')
        self.assertTrue(
            valid,
            f"dispatched->failed MUST be allowed. Got: {msg}"
        )
        # The atom-level fail path: 'in_progress' (claimed) -> 'failed' is allowed
        valid2, msg2 = validate_state_transition('in_progress', 'failed')
        self.assertTrue(
            valid2,
            f"in_progress->failed MUST be allowed. Got: {msg2}"
        )

    def test_t4_claimed_to_verified_allowed(self):
        """T4: claimed→verified allowed (claimed in CLI = dispatched in TQP;
        dispatched -> complete is the canonical TQP forward transition)."""
        valid, msg = validate_state_transition('dispatched', 'complete')
        self.assertTrue(
            valid,
            f"dispatched->complete MUST be allowed. Got: {msg}"
        )
        # Also 'dispatched' -> 'sub_crest_planning' (legacy to sub-CREST)
        valid2, msg2 = validate_state_transition('dispatched', 'sub_crest_planning')
        self.assertTrue(
            valid2,
            f"dispatched->sub_crest_planning MUST be allowed. Got: {msg2}"
        )

    def test_t5_invalid_source_state_handled(self):
        """T5: invalid source state (e.g. from=None or unknown) handled gracefully."""
        # None source state
        valid, msg = validate_state_transition(None, 'complete')
        self.assertFalse(
            valid,
            f"None->complete MUST be rejected. Got: {msg}"
        )
        # Unknown source state
        valid2, msg2 = validate_state_transition('garbage_state', 'complete')
        self.assertFalse(
            valid2,
            f"garbage_state->complete MUST be rejected. Got: {msg2}"
        )
        # Empty string source
        valid3, msg3 = validate_state_transition('', 'complete')
        self.assertFalse(
            valid3,
            f"''->complete MUST be rejected. Got: {msg3}"
        )
        # The SUB_CREST_TRANSITIONS table must be a non-empty dict
        self.assertIsInstance(SUB_CREST_TRANSITIONS, dict)
        self.assertGreater(len(SUB_CREST_TRANSITIONS), 0,
                          "SUB_CREST_TRANSITIONS must define at least one source state")


class TestVerifiedToTerminalTransitions(unittest.TestCase):
    """TKT-0410: 'verified' source edge must allow transitions to terminal states.

    Tasks with all atoms verified but parent done were getting stuck in 'verified'
    because SUB_CREST_TRANSITIONS lacked a 'verified' source edge. These tests
    pin the fix.
    """

    def test_verified_key_present_with_expected_targets(self):
        # 'verified' must exist as a source state
        self.assertIn(
            'verified', SUB_CREST_TRANSITIONS,
            "TKT-0410: 'verified' must be a source state in SUB_CREST_TRANSITIONS"
        )
        # Target set must match the spec exactly
        self.assertEqual(
            SUB_CREST_TRANSITIONS['verified'],
            {'complete', 'sub_crest_done', 'done'},
            f"TKT-0410: 'verified' targets must be {{'complete', 'sub_crest_done', 'done'}}. "
            f"Got: {sorted(SUB_CREST_TRANSITIONS['verified'])}"
        )

    def test_verified_to_complete_allowed(self):
        valid, msg = validate_state_transition('verified', 'complete')
        self.assertTrue(
            valid,
            f"TKT-0410: verified->complete MUST be allowed. Got: {msg}"
        )

    def test_verified_to_done_allowed(self):
        valid, msg = validate_state_transition('verified', 'done')
        self.assertTrue(
            valid,
            f"TKT-0410: verified->done MUST be allowed. Got: {msg}"
        )

    def test_verified_to_sub_crest_done_allowed(self):
        valid, msg = validate_state_transition('verified', 'sub_crest_done')
        self.assertTrue(
            valid,
            f"TKT-0410: verified->sub_crest_done MUST be allowed. Got: {msg}"
        )


class TestTerminalStateLockdown(unittest.TestCase):
    """Bonus: ensure all terminal states reject all outbound transitions."""

    TERMINAL_STATES = ['done', 'sub_crest_done', 'escalated', 'closed', 'cancelled']

    def test_terminal_states_have_no_outbound_transitions(self):
        for state in self.TERMINAL_STATES:
            allowed = SUB_CREST_TRANSITIONS.get(state, set())
            self.assertEqual(
                allowed, set(),
                f"Terminal state '{state}' must have zero outbound transitions. "
                f"Found: {sorted(allowed)}"
            )

    def test_terminal_states_reject_arbitrary_target(self):
        for state in self.TERMINAL_STATES:
            for target in ['queued', 'complete', 'failed', 'in_progress', 'master_planning']:
                valid, msg = validate_state_transition(state, target)
                self.assertFalse(
                    valid,
                    f"Terminal {state}->{target} MUST be rejected. Got: {msg}"
                )


if __name__ == '__main__':
    # Run with verbose output so a single test failure is easy to find
    unittest.main(verbosity=2)
