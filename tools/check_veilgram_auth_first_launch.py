#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

countries = (ROOT / "submodules/CountrySelectionUI/Sources/AuthorizationSequenceCountrySelectionController.swift").read_text(encoding="utf-8")
auth = (ROOT / "submodules/AuthorizationUI/Sources/AuthorizationSequenceController.swift").read_text(encoding="utf-8")

checks = []

def require(name, condition, detail):
    checks.append((name, condition, detail))

prefix_decl = countries.find("private var countryCodesByPrefix")
country_decl = countries.find("private var countryCodes: [Country] = loadCountryCodes()")
require(
    "bundle-prefix-bootstrap-order",
    prefix_decl >= 0 and country_decl >= 0 and prefix_decl < country_decl,
    "Prefix map must exist before loadCountryCodes populates the bundled fallback.",
)
require(
    "empty-server-response-guard",
    countries.count("guard !countries.isEmpty else") >= 3
    and "Ignored empty unauthorized server countries response" in countries
    and "Ignored empty authorized server countries response" in countries,
    "Empty server/injected country data must not overwrite the bundled fallback.",
)
require(
    "country-bootstrap-diagnostics",
    "Loaded bundled countries count=" in countries
    and "Applied unauthorized server countries count=" in countries,
    "Country bootstrap must emit count-only diagnostics without phone-number data.",
)
require(
    "auth-state-diagnostics",
    "Authorization state -> authorized" in auth
    and "Authorization state -> confirmationCodeEntry" not in auth
    and 'stateName = "confirmationCodeEntry"' in auth,
    "Authorization controller must log state names rather than sensitive state payloads.",
)
require(
    "code-submit-diagnostics",
    "Code submission started" in auth
    and "Code submission result -> loggedIn" in auth
    and "Code submission failed" in auth,
    "Code submission timing path must expose privacy-safe lifecycle diagnostics.",
)

failed = [x for x in checks if not x[1]]
for name, ok, detail in checks:
    print(f"{'PASS' if ok else 'FAIL'}: {name} — {detail}")

if failed:
    raise SystemExit(1)

print(f"PASS: {len(checks)} first-launch authorization checks")
