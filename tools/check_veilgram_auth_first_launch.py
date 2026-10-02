#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

countries = (ROOT / "submodules/CountrySelectionUI/Sources/AuthorizationSequenceCountrySelectionController.swift").read_text(encoding="utf-8")
auth = (ROOT / "submodules/AuthorizationUI/Sources/AuthorizationSequenceController.swift").read_text(encoding="utf-8")
node = (ROOT / "submodules/CountrySelectionUI/Sources/AuthorizationSequenceCountrySelectionControllerNode.swift").read_text(encoding="utf-8")
bundle = (ROOT / "submodules/TelegramUI/Resources/PhoneCountries.txt").read_text(encoding="utf-8", errors="replace")

checks = []

def require(name, condition, detail):
    checks.append((name, condition, detail))

prefix_decl = countries.find("private var countryCodesByPrefix")
country_decl = countries.find("private var countryCodes: [Country] = loadCountryCodes()")
require(
    "bundle-prefix-bootstrap-order",
    prefix_decl >= 0 and country_decl >= 0 and prefix_decl < country_decl
    and len([line for line in bundle.splitlines() if line.strip()]) > 100,
    "Prefix map must exist before a substantial bundled country fallback is loaded.",
)
require(
    "empty-server-response-guard",
    countries.count("guard !countries.isEmpty else") >= 3
    and "Ignored empty unauthorized server countries response" in countries
    and "Ignored empty authorized server countries response" in countries,
    "Empty server/injected country data must not overwrite the bundled fallback.",
)
require(
    "live-open-picker-refresh",
    "countryCodesDidChangeNotification" in countries
    and "self.controllerNode.reloadCountries()" in countries
    and "func reloadCountries()" in node,
    "An already-open first-launch country picker must rebuild when server data arrives.",
)
require(
    "live-search-refresh",
    "currentSearchQuery" in node
    and "self.searchResults = searchCountries" in node
    and "self.searchTableView.reloadData()" in node,
    "Country search must remain coherent when a late server list replaces the fallback.",
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
    and "Code submission result -> loggedIn requestSeconds=" in auth
    and "Auth state advanced after code result seconds=" in auth
    and "Auth state did not advance within 2s after code result" in auth
    and "Code submission failed" in auth,
    "Code submission diagnostics must separate request latency from delayed auth-state propagation.",
)

failed = [x for x in checks if not x[1]]
for name, ok, detail in checks:
    print(f"{'PASS' if ok else 'FAIL'}: {name} — {detail}")

if failed:
    raise SystemExit(1)

print(f"PASS: {len(checks)} first-launch authorization checks")
