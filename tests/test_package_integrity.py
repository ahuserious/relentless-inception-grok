from __future__ import annotations

import json
import os
import unittest
from pathlib import Path
from typing import Any, Dict
from unittest.mock import patch

from tests.support import MCP_SERVER_PATH, PLUGIN_ROOT

from relentless_inception import __version__
from relentless_inception.cli import doctor
from relentless_inception.config import (
    CONFIG_SCHEMA_PATH,
    DEFAULT_CONFIG_PATH,
    deep_merge,
    load_config,
    runtime_data_dir,
    validate_config,
)
from relentless_inception.providers import ProviderRegistry


def _load_json(path: Path) -> Dict[str, Any]:
    with path.open(encoding="utf-8") as file_handle:
        value = json.load(file_handle)
    if not isinstance(value, dict):
        raise AssertionError(f"Expected a JSON object in {path}")
    return value


class RuntimePackageIntegrityTests(unittest.TestCase):
    def test_release_identity_and_runtime_layout_are_consistent(self) -> None:
        default_config = load_config(include_user=False)

        self.assertEqual(__version__, "0.4.1")
        self.assertEqual(doctor(default_config)["version"], __version__)
        self.assertEqual(DEFAULT_CONFIG_PATH, PLUGIN_ROOT / "config" / "default.json")
        self.assertEqual(CONFIG_SCHEMA_PATH, PLUGIN_ROOT / "schemas" / "config.schema.json")
        self.assertTrue(DEFAULT_CONFIG_PATH.is_file())
        self.assertTrue(CONFIG_SCHEMA_PATH.is_file())
        self.assertTrue(MCP_SERVER_PATH.is_file())
        self.assertTrue(os.access(MCP_SERVER_PATH, os.X_OK))

        with patch.dict(os.environ, {"XAI_API_KEY": "test-only-placeholder"}):
            headers = ProviderRegistry(default_config)._headers(
                default_config["providers"]["xai_direct"]
            )
        self.assertEqual(headers["User-Agent"], f"relentless-inception-grok/{__version__}")

    def test_default_data_directory_is_grok_scoped_and_env_override_survives(self) -> None:
        with patch.dict(
            os.environ,
            {"RELENTLESS_INCEPTION_DATA_DIR": "", "PLUGIN_DATA": ""},
            clear=False,
        ):
            self.assertEqual(runtime_data_dir(), Path.home() / ".grok" / "relentless-inception")

        with patch.dict(
            os.environ,
            {"RELENTLESS_INCEPTION_DATA_DIR": "/tmp/explicit-ri-data"},
            clear=False,
        ):
            self.assertEqual(runtime_data_dir(), Path("/tmp/explicit-ri-data").resolve())

    def test_json_examples_merge_into_valid_complete_configuration(self) -> None:
        default_config = load_config(include_user=False)
        example_paths = sorted((PLUGIN_ROOT / "examples").glob("*.json"))
        self.assertTrue(example_paths)

        for example_path in example_paths:
            with self.subTest(example=example_path.name):
                merged_config = deep_merge(default_config, _load_json(example_path))
                self.assertEqual(validate_config(merged_config), [])

    def test_direct_xai_pricing_matches_grok_45_rates(self) -> None:
        default_config = load_config(include_user=False)
        expected_pricing = {
            "input_per_million_usd": 2.0,
            "cached_input_per_million_usd": 0.5,
            "output_per_million_usd": 6.0,
            "long_context_input_per_million_usd": 4.0,
            "long_context_cached_input_per_million_usd": 1.0,
            "long_context_output_per_million_usd": 12.0,
            "base_rate_input_limit_tokens": 200_000,
            "above_base_rate_behavior": "unknown_cost_fail_closed",
        }
        direct_xai_seats = {
            seat_name: seat
            for seat_name, seat in default_config["seats"].items()
            if seat.get("provider") == "xai_direct"
        }

        self.assertTrue(direct_xai_seats)
        for seat_name, seat in direct_xai_seats.items():
            with self.subTest(seat=seat_name):
                self.assertEqual(seat["model"], "grok-4.5")
                self.assertEqual(seat["pricing"], expected_pricing)

    def test_shipped_maximum_intelligence_defaults_are_frontier_only(self) -> None:
        default_config = load_config(include_user=False)
        profile = default_config["profiles"]["maximum_intelligence"]
        fusion = profile["fusion"]
        gates = profile["gates"]

        active_seat_names = [
            *fusion["panel"],
            fusion["judge"],
            fusion["synthesizer"],
            *gates["reviewers"],
        ]
        for seat_name in active_seat_names:
            with self.subTest(active_seat=seat_name):
                seat = default_config["seats"][seat_name]
                self.assertTrue(seat["enabled"])
                self.assertEqual(seat["provider"], "xai_direct")
                self.assertEqual(seat["model"], "grok-4.5")
                self.assertEqual(seat["reasoning_effort"], "high")
                self.assertEqual(seat["fallback_models"], [])

        self.assertEqual(fusion["optional_panel"], ["openrouter_sol_pro_panel"])
        optional_gpt = default_config["seats"]["openrouter_sol_pro_panel"]
        self.assertFalse(optional_gpt["enabled"])
        self.assertEqual(optional_gpt["provider"], "openrouter")
        self.assertEqual(optional_gpt["model"], "openai/gpt-5.6-sol")
        self.assertEqual(optional_gpt["fallback_models"], [])
        self.assertFalse(default_config["providers"]["openrouter"]["enabled"])

        native_grok = default_config["native_grok"]
        self.assertEqual(native_grok["executor_model"], "grok-4.5")
        self.assertEqual(native_grok["executor_reasoning_effort"], "high")
        self.assertEqual(native_grok["reviewer_models"], ["grok-4.5"])
        self.assertEqual(
            native_grok["reviewer_roles"],
            ["relentless-inception-grok:adversarial-review"],
        )
        self.assertEqual(native_grok["reviewer_reasoning_effort"], "high")
        self.assertEqual(profile["execution"]["model"], "grok-4.5")
        self.assertEqual(profile["execution"]["reasoning_effort"], "high")
        self.assertEqual(profile["execution"]["mode"], "grok_handoff")
        self.assertFalse(profile["execution"]["allow_recursive_grok_cli"])

        for seat_name, seat in default_config["seats"].items():
            with self.subTest(no_model_fallback=seat_name):
                self.assertEqual(seat["fallback_models"], [])
            if "gpt" in seat["model"].lower():
                self.assertEqual(seat["model"], "openai/gpt-5.6-sol")

    def test_native_agent_metadata_matches_grok_build_02106(self) -> None:
        agent_paths = sorted((PLUGIN_ROOT / "agents").glob("*.md"))
        self.assertTrue(agent_paths)

        for agent_path in agent_paths:
            with self.subTest(agent=agent_path.name):
                frontmatter = agent_path.read_text(encoding="utf-8").split("---", 2)[1]
                self.assertIn("model: grok-4.5\n", frontmatter)
                self.assertIn("effort: high\n", frontmatter)
                self.assertNotIn("grok-4.5-latest", frontmatter)
                self.assertNotIn("effort: max", frontmatter)


if __name__ == "__main__":
    unittest.main()
