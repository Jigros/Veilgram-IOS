#!/usr/bin/env python3
"""Offline Veilgram ordinary-channel-post ad classifier PROTOTYPE.

Research only. This module is NOT wired into Telegram message rendering.
Official Telegram SponsoredMessage objects must never be filtered here.
No network access, message retention, telemetry, paid APIs or personal data.
"""
from __future__ import annotations
from dataclasses import dataclass, field
import re
import unicodedata

# Require context; a single mention of "реклама" in a news story is not enough.
PATTERNS = (
    ("disclosure", 8, re.compile(r"(?iu)(?:#(?:реклам[а-яё]*|интеграци[а-яё]*|спонсор[а-яё]*|партн[её]рск[а-яё]*|ad|sponsored|advertisement|paidpartnership)\b|\b(?:на правах рекламы|рекламная интеграция|партн[её]рский материал|paid partnership|sponsored post)\b)")),
    ("erid", 9, re.compile(r"(?iu)\berid\s*[:=\-]\s*[a-z0-9][a-z0-9_\-]{5,}\b")),
    ("promo", 3, re.compile(r"(?iu)\b(?:промокод(?:ом|а|ы)?|по промокоду|скидка по коду|используй код|use (?:promo|discount) code)\b")),
    ("offer", 2, re.compile(r"(?iu)\b(?:скидка\s+\d{1,2}%|специальное предложение|limited time offer|получи бонус|забирай бонус)\b")),
    ("call_to_action", 2, re.compile(r"(?iu)\b(?:подписывайтесь|подпишитесь|успейте купить|переходите по ссылке|заказывайте|купите сейчас|жми(?:те)? по ссылке|shop now|sign up now|use my link)\b")),
    ("affiliate", 5, re.compile(r"(?iu)(?:\b(?:партн[её]рская ссылка|реферальная ссылка|мой реф(?:еральный)?(?: код)?)\b|\b(?:ref|aff|affiliate|utm_medium)\s*=)")),
    ("link", 2, re.compile(r"(?iu)(?:https?://|(?:^|\s)t\.me/|(?:^|\s)@[a-z][a-z0-9_]{4,})")),
)
# Do not score words about advertising discussed in news absent promotion.
DISCUSSION = re.compile(r"(?iu)\b(?:закон(?:опроект)? о рекламе|регулировани[ея] рекламы|рекламн(?:ый|ого) рынок|ad regulation|advertising industry)\b")


@dataclass(frozen=True)
class Post:
    text: str
    is_channel_post: bool
    is_official_sponsored: bool = False
    is_service: bool = False
    channel_id: int | None = None


@dataclass(frozen=True)
class Configuration:
    enabled: bool = False
    mode: str = "label"  # "label", "collapse"; never delete server messages
    allowed_channels: frozenset[int] = field(default_factory=frozenset)
    suspected_threshold: int = 6
    collapse_threshold: int = 9


@dataclass(frozen=True)
class Decision:
    action: str  # "keep", "label", "collapse"
    score: int
    signals: tuple[str, ...]


def classify(post: Post, cfg: Configuration) -> Decision:
    # Hard guarantees: NOT the official ads, NOT DMs/groups/service posts.
    if (not cfg.enabled or not post.is_channel_post or post.is_official_sponsored
            or post.is_service or post.channel_id in cfg.allowed_channels):
        return Decision("keep", 0, ())
    if cfg.mode not in ("label", "collapse"):
        raise ValueError("Unknown filter mode")
    text = unicodedata.normalize("NFKC", post.text).casefold()
    text = re.sub(r"[\u200b-\u200d\ufeff]", "", text)
    if len(text) > 16000:
        text = text[:16000]  # hard upper bound, never block scrolling
    found = [(name, weight) for name, weight, pattern in PATTERNS if pattern.search(text)]
    score = sum(weight for _, weight in found)
    if DISCUSSION.search(text) and not any(name in ("disclosure", "erid") for name, _ in found):
        score = max(0, score - 3)
    # One weak cue alone must never conceal a message.
    signals = tuple(name for name, _ in found)
    if score < cfg.suspected_threshold:
        action = "keep"
    elif cfg.mode == "collapse" and score >= cfg.collapse_threshold:
        action = "collapse"
    else:
        action = "label"
    return Decision(action, score, signals)
