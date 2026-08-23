import importlib.machinery
import importlib.util
import unittest
from pathlib import Path


SCRIPT = Path(__file__).parents[1] / "bin/omarchy-litellm-sync"
LOADER = importlib.machinery.SourceFileLoader("litellm_sync", str(SCRIPT))
SPEC = importlib.util.spec_from_loader(LOADER.name, LOADER)
sync = importlib.util.module_from_spec(SPEC)
LOADER.exec_module(sync)


class KeyInfoTests(unittest.TestCase):
    def test_normalizes_nested_key_info(self):
        result = sync.key_info({"info": {"key_alias": "Personal", "spend": 23, "max_budget": 100, "user_id": "me", "rpm_limit": 12}})
        self.assertEqual(result["alias"], "Personal")
        self.assertEqual(result["remaining"], 77)
        self.assertEqual(result["remainingPercent"], 77)
        self.assertEqual(result["userId"], "me")
        self.assertEqual(result["rpmLimit"], 12)

    def test_handles_missing_budget(self):
        result = sync.key_info({"spend": 12.5})
        self.assertIsNone(result["maxBudget"])
        self.assertIsNone(result["remainingPercent"])

    def test_zero_budget_is_an_exhausted_budget(self):
        result = sync.key_info({"spend": 0, "max_budget": 0})
        self.assertEqual(result["remaining"], 0)
        self.assertEqual(result["remainingPercent"], 0)


class AnalyticsTests(unittest.TestCase):
    def test_aggregates_days_and_models(self):
        raw = {
            "results": [
                {"date": "2026-08-01", "metrics": {"spend": 1.5, "total_tokens": 100, "api_requests": 2}, "breakdown": {"models": {"a": {"metrics": {"spend": 1, "total_tokens": 60}}, "b": {"metrics": {"spend": 0.5, "total_tokens": 40}}}}},
                {"date": "2026-08-02", "metrics": {"spend": 2, "total_tokens": 200, "api_requests": 3}, "breakdown": {"models": {"a": {"metrics": {"spend": 2, "total_tokens": 200}}}}},
            ]
        }
        today, month, days, models = sync.analytics(raw, "2026-08-02")
        self.assertEqual(today["spend"], 2)
        self.assertEqual(month["spend"], 3.5)
        self.assertEqual(month["requests"], 5)
        self.assertEqual(len(days), 2)
        self.assertEqual(models[0]["name"], "a")
        self.assertEqual(models[0]["spend"], 3)

    def test_ignores_malformed_values(self):
        today, month, days, models = sync.analytics({"results": [{"date": "2026-08-02", "metrics": {"spend": "bad"}}]}, "2026-08-02")
        self.assertEqual(today["spend"], 0)
        self.assertEqual(month["totalTokens"], 0)
        self.assertEqual(len(days), 1)
        self.assertEqual(models, [])
