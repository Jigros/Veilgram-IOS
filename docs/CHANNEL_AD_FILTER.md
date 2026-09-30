# Veilgram ordinary channel-post ad detection — experiment

Status: **OFFLINE PROTOTYPE / NOT INTEGRATED INTO CLIENT.** No Telegram messages, user accounts, or advertisements are read or altered by the prototype.

## The exact content being considered

A normal `Message` authored by a channel administrator: paid integrations, discount/promo content, partner links, affiliate posts. This is separate from Telegram platform `SponsoredMessage` entities and other official sponsored search/channel/bot results.

**Non-negotiable exclusion:** Official Telegram sponsored ads MUST be shown as defined in the Telegram API docs and ToS: https://core.telegram.org/api/terms and https://core.telegram.org/api/sponsored-messages . Never reclassify them from text or run any hiding flow on official ad items. The classifier receives `is_official_sponsored` as a hard veto for testing; production must enforce the boundary by concrete type and origin.

## Open-source prior art

- [VChet/telegram-ad-filter](https://github.com/VChet/telegram-ad-filter): simple markers, `blacklist.json` includes `#ad`, `#sponsor`, `#реклам`, `#интеграция`, `#партнерский`; collapses/mimimizes matching Telegram WebK posts. Adapt the approach, **not** its JavaScript or third-party artwork.
- [Kreminskaya/ai-content-bot](https://github.com/Kreminskaya/ai-content-bot): project advertises a separate advertising heuristic in its channel content aggregation pipeline. Code behavior not yet independently audited.
- [AlxVoropaev/informer_bot](https://github.com/AlxVoropaev/informer_bot): separate per-channel controls, debug mode with rejected posts annotated.
- [MitPitt/rss-to-telegram-engine](https://github.com/MitPitt/rss-to-telegram-engine): transparent regex filters and invert/any matches.
- [shatyuka/Killergram](https://github.com/shatyuka/Killergram) and official sponsored-message suppressors are **not relevant** to the target and may violate Telegram ToS; do not port this functionality.

## MVP classification design

1. **Strict eligibility**: ordinary broadcast-channel `Message` only, never direct/group chats, service items, ephemeral/protected content, official `SponsoredMessage` / `adMessage` / `dynamicAdMessages`.
2. **Local transparent signals**: sponsorship disclosures, `erid:` ad-registration marker, promo codes, affiliate parameters, external links, explicit sales CTA. Normalize Unicode and discount common discussions about advertising.
3. **Explainable score**: sum of matched features, cap text length to 16K, one match per signal, never phone home. Prototype default `enabled = false`; when enabled, default is **label only** and optional collapse threshold is higher.
4. **User controls**: global off/on, `mark only` vs `collapse with tap-to-reveal`, channel allowlist and per-channel override, add/remove custom expressions, report wrong classification, local rule import/export.
5. **Do not mutate Telegram storage**. Never remove entries from Postbox or rewrite deleted/read states, never alter sponsored impression handling, counts, search results, notifications, or forwarding. Use local presentation **overlay** or collapsed-message replacement preserving message identity/scroll anchor, with one tap to reveal.
6. **Predictable caching**: key per-account + channel peer ID + message stable ID + edit revision + algorithm version. Cache verdicts, not text; invalidate on edits, channel switches, settings or rule updates. Avoid classifying all history in one synchronous UI pass.
7. **Albums/media**: score message captions and explicit content only; do not OCR private images or access protected media. Albums must remain grouped (do not hide just one attachment and leave broken layout).
8. **ML later, not now**: optional offline Core ML model for ambiguous posts only, after a curated licensed dataset with meaningful false-positive metrics for RU and EN. Quantization, size, battery, async responsiveness and on-device privacy must be tested. No private messages sent to cloud inference without separate explicit consent.

### Real iOS integration point (not implemented)

`submodules/TelegramUI/Sources/ChatHistoryEntriesForView.swift` converts `MessageHistoryView` to `[ChatHistoryEntry]`; it also receives `adMessage` and `dynamicAdMessages` which means blindly removing items here could suppress **official ads**. DO NOT `filter` message entries directly.

`submodules/TelegramUI/Sources/ChatHistoryListNode.swift` maps `.MessageEntry` and `.MessageGroupEntry` to display items. A UI-only disclosure/collapse component belongs near this presentation layer (or in `ChatMessageItemImpl`) and must preserve stable message ID/selection/scroll behavior. To integrate:
- separate `VeilgramAdClassifier` Swift module, mapped only from typed ordinary channel messages;
- add user settings (disabled by default) and visibility state + reveal override;
- test stable list transitions, grouped media, scroll, unread markers, search, quick switching and native ad rendering;
- build simulator then use actual screenshots and fixture channels, never personal chat data in CI.

## Prototype evidence and limits

- `tools/adfilter_prototype.py`: pure Python heuristic for exploring weights and false positives; only standard library.
- `tools/test_adfilter_prototype.py`: 11 unit cases covering disabled state, official-ad veto, non-channel exclusion, disclosures, `erid`, CTA/discount/link combinations, channel allowlist, accidental ordinary-news hits, label-only and deliberate Unicode ambiguity.
- NixOS local run: `python3 -m unittest -v test_adfilter_prototype` — **11 PASS**.
- Not a trained model; real ad-detection precision and recall **not measured**. Unicode mixed-script confusables, images without captions, native paid posts masquerading as editorial and link shorteners remain unresolved.
- No iOS compilation or runtime verification; **feature not available in Veilgram**.

## Success criteria before enabling collapse

- Collect a license/consent-safe synthetic and publicly usable benchmark stratified by language, topic and channel type, and keep sample provenance clear.
- Manually label ad/not-ad with multi-annotator review; track precision and false-positive rate separately on news, discount announcements, own-channel posts, editorial affiliate disclosures and political/news-sensitive content.
- Default to non-destructive labelling. Require user opt-in for collapse and always provide reveal/undo and explainable reasons.
- Run compile, iPhone performance, offline energy use, logout and per-account isolation checks. Absolutely no interference with Telegram Sponsored Messages.
