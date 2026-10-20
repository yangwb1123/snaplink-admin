"""Deterministic functional decisions, with every claim scoped to its provenance."""

from copy import deepcopy
import json
import unittest

from app_sso_support import app_sso, assert_unverified, declarations, diagnose, labels


class AppSsoDiagnosticTest(unittest.TestCase):
    def test_compatible_declarations_are_not_login_or_registration_evidence(self):
        report = diagnose(declarations())
        self.assertEqual(report['input_status'], 'accepted')
        self.assertEqual(report['assessment'], 'compatible_static_declarations')
        self.assertEqual(report['reasons'][:2], [
            {'label': 'same_op_declared', 'provenance': 'operator_pair'},
            {'label': 'same_browser_jar_declared', 'provenance': 'operator_pair'},
        ])
        for side in ('a', 'b'):
            self.assertEqual(labels(report, 'operator_app_' + side), [
                'canonical_code_s256_declared', 'no_explicit_prompt_declared',
                'no_explicit_max_age_declared', 'plain_request_context_declared',
                'no_step_up_declared', 'consent_is_not_password_authentication',
            ])
        assert_unverified(self, report)

    def test_app_inputs_missing_or_null_are_distinct(self):
        for missing in (('app_a',), ('app_b',), ('app_a', 'app_b')):
            for omit in (True, False):
                value = declarations()
                for key in missing:
                    if omit:
                        del value[key]
                    else:
                        value[key] = None
                with self.subTest(missing=missing, omit=omit):
                    report = diagnose(value)
                    self.assertEqual(report['assessment'], 'missing_inputs')
                    self.assertEqual(labels(report, 'input_structure'),
                                     [key + '_input_missing' for key in missing])
                    assert_unverified(self, report)

    def test_relationship_declarations_missing_differ_from_explicit_unknown(self):
        for field, label in (('op_relation', 'op_declaration_missing'),
                             ('browser_jar_relation', 'browser_jar_declaration_missing')):
            for omit in (True, False):
                value = declarations()
                if omit:
                    del value[field]
                else:
                    value[field] = None
                report = diagnose(value)
                self.assertEqual(report['assessment'], 'missing_inputs')
                self.assertIn(label, labels(report, 'input_structure'))

    def test_only_version_is_valid_but_incomplete_not_a_pass(self):
        report = diagnose({'version': 1})
        self.assertEqual(report['input_status'], 'accepted')
        self.assertEqual(report['assessment'], 'missing_inputs')
        self.assertEqual(labels(report)[:-1], [
            'op_declaration_missing', 'browser_jar_declaration_missing',
            'app_a_input_missing', 'app_b_input_missing',
        ])
        assert_unverified(self, report)

    def test_declared_op_relationship_is_not_inferred_or_verified(self):
        for relation, assessment, label in (
            ('same', 'compatible_static_declarations', 'same_op_declared'),
            ('different', 'declared_barriers_or_interaction', 'different_ops_declared'),
            ('unknown', 'offline_undetermined', 'op_unconfirmed'),
        ):
            value = declarations()
            value['op_relation'] = relation
            with self.subTest(relation=relation):
                report = diagnose(value)
                self.assertEqual(report['assessment'], assessment)
                self.assertIn(label, labels(report, 'operator_pair'))
                assert_unverified(self, report)

    def test_declared_cookie_context_is_not_a_confirmed_cookie_jar(self):
        for relation, assessment, label in (
            ('same', 'compatible_static_declarations', 'same_browser_jar_declared'),
            ('different', 'declared_barriers_or_interaction', 'separate_browser_jars_declared'),
            ('unknown', 'offline_undetermined', 'browser_jar_unconfirmed'),
        ):
            value = declarations()
            value['browser_jar_relation'] = relation
            with self.subTest(relation=relation):
                report = diagnose(value)
                self.assertEqual(report['assessment'], assessment)
                self.assertIn(label, labels(report, 'operator_pair'))
                assert_unverified(self, report)

    def test_direct_login_is_not_proof_of_either_presence_or_absence_of_op_cookie(self):
        for side in ('app_a', 'app_b'):
            value = declarations()
            value[side]['flow'] = 'app_local_direct'
            report = diagnose(value)
            self.assertEqual(report['assessment'], 'declared_barriers_or_interaction')
            self.assertIn('app_local_direct_is_not_code_navigation', labels(report, 'operator_' + side))
            self.assertIn('direct_login_does_not_prove_op_browser_session',
                          labels(report, 'operator_' + side))
            assert_unverified(self, report)

    def test_unknown_navigation_is_undetermined(self):
        for side in ('app_a', 'app_b'):
            value = declarations()
            value[side]['flow'] = 'unknown'
            report = diagnose(value)
            self.assertEqual(report['assessment'], 'offline_undetermined')
            self.assertIn('navigation_unconfirmed', labels(report, 'operator_' + side))

    def test_b_explicit_prompt_policy_is_preserved_and_not_conflated(self):
        for prompt, assessment, label in (
            ('login', 'declared_barriers_or_interaction', 'prompt_login_declared'),
            ('select_account', 'declared_barriers_or_interaction', 'prompt_select_account_declared'),
            ('consent', 'compatible_static_declarations', 'prompt_consent_is_not_password_authentication'),
            ('none', 'compatible_static_declarations', 'prompt_none_does_not_prove_session'),
        ):
            value = declarations()
            value['app_b']['prompt'] = [prompt]
            before = deepcopy(value)
            with self.subTest(prompt=prompt):
                report = diagnose(value)
                self.assertEqual(report['assessment'], assessment)
                self.assertIn(label, labels(report, 'operator_app_b'))
                self.assertEqual(value, before)
                assert_unverified(self, report)

    def test_b_prompt_unknown_does_not_mean_absent_policy(self):
        value = declarations()
        value['app_b']['prompt'] = None
        report = diagnose(value)
        self.assertEqual(report['assessment'], 'offline_undetermined')
        self.assertIn('prompt_unconfirmed', labels(report, 'operator_app_b'))

    def test_b_max_age_zero_positive_unknown_and_absent(self):
        for age, assessment, label in (
            (0, 'declared_barriers_or_interaction', 'max_age_zero_declared'),
            (1, 'offline_undetermined', 'session_age_cannot_be_checked_offline'),
            (2147483647, 'offline_undetermined', 'session_age_cannot_be_checked_offline'),
            ('unknown', 'offline_undetermined', 'max_age_unconfirmed'),
            ('absent', 'compatible_static_declarations', 'no_explicit_max_age_declared'),
        ):
            value = declarations()
            value['app_b']['max_age'] = age
            with self.subTest(age=age):
                report = diagnose(value)
                self.assertEqual(report['assessment'], assessment)
                self.assertIn(label, labels(report, 'operator_app_b'))

    def test_a_authentication_policy_never_becomes_b_policy(self):
        value = declarations()
        value['app_a'].update(prompt=['login', 'select_account'], max_age=0, step_up='required')
        report = diagnose(value)
        self.assertEqual(report['assessment'], 'compatible_static_declarations')
        for label in ('prompt_login_declared', 'prompt_select_account_declared',
                      'max_age_zero_declared', 'step_up_requires_runtime_decision'):
            self.assertIn(label, labels(report, 'operator_app_a'))
            self.assertNotIn(label, labels(report, 'operator_app_b'))
        assert_unverified(self, report)

    def test_b_step_up_cannot_be_decided_offline_or_removed(self):
        for policy, label in (('required', 'step_up_requires_runtime_decision'),
                              ('unknown', 'step_up_unconfirmed')):
            value = declarations()
            value['app_b']['step_up'] = policy
            report = diagnose(value)
            self.assertEqual(report['assessment'], 'offline_undetermined')
            self.assertIn(label, labels(report, 'operator_app_b'))
            assert_unverified(self, report)

    def test_opaque_and_unknown_request_contexts_remain_undetermined(self):
        for side in ('app_a', 'app_b'):
            for context, label in (('par', 'opaque_par_cannot_be_resolved_offline'),
                                   ('jar', 'opaque_jar_cannot_be_resolved_offline'),
                                   ('unknown', 'request_context_unconfirmed')):
                value = declarations()
                value[side]['request_context'] = context
                with self.subTest(side=side, context=context):
                    report = diagnose(value)
                    self.assertEqual(report['assessment'], 'offline_undetermined')
                    self.assertIn(label, labels(report, 'operator_' + side))
                    assert_unverified(self, report)

    def test_consent_not_a_second_password_and_unknown_not_disabled(self):
        for consent, label in (('required', 'consent_is_not_password_authentication'),
                               ('not_required', 'consent_not_required_declared'),
                               ('unknown', 'consent_policy_unconfirmed')):
            value = declarations()
            value['app_b']['consent'] = consent
            report = diagnose(value)
            self.assertEqual(report['assessment'], 'compatible_static_declarations')
            self.assertIn(label, labels(report, 'operator_app_b'))
            assert_unverified(self, report)

    def test_assessment_precedence_does_not_hide_uncertain_or_missing_evidence(self):
        value = declarations()
        value['op_relation'] = 'different'
        value['browser_jar_relation'] = 'unknown'
        value['app_b'].update(prompt=['login'], request_context='par', step_up='required')
        report = diagnose(value)
        self.assertEqual(report['assessment'], 'declared_barriers_or_interaction')
        self.assertIn('browser_jar_unconfirmed', labels(report))
        self.assertIn('opaque_par_cannot_be_resolved_offline', labels(report))
        value['app_a'] = None
        self.assertEqual(diagnose(value)['assessment'], 'missing_inputs')

    def test_reports_are_order_independent_and_do_not_reuse_mutable_state(self):
        first = declarations()
        first['app_b']['prompt'] = ['consent', 'select_account', 'login']
        second = dict(reversed(list(deepcopy(first).items())))
        second['app_b'] = dict(reversed(list(second['app_b'].items())))
        second['app_b']['prompt'].reverse()
        self.assertEqual(diagnose(first), diagnose(second))
        model = app_sso.decode_declarations(json.dumps(first).encode())
        report = app_sso.diagnose(model)
        report['verification']['op_session'] = 'modified_by_caller'
        report['reasons'].clear()
        self.assertEqual(app_sso.diagnose(model), diagnose(second))


if __name__ == '__main__':
    unittest.main()
