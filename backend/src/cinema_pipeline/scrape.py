"""Reads the public web preview of a Telegram channel (https://t.me/s/<channel>).

No Telegram account or API credentials are involved. Only public channels work,
and only the most recent ~20 posts are visible, which is plenty when we run every
few hours.
"""

from __future__ import annotations

import re
from dataclasses import dataclass
from datetime import datetime

import httpx
from bs4 import BeautifulSoup

USER_AGENT = "Mozilla/5.0 (compatible; cinema-schedules-bot/0.1)"
_BACKGROUND_URL = re.compile(r"background-image:\s*url\(['\"]?(.+?)['\"]?\)")


class ChannelUnavailable(Exception):
    """The channel doesn't exist, was renamed, or isn't public."""


@dataclass(frozen=True)
class ChannelImage:
    channel: str
    post_id: int
    index: int  # position within an album; 0 for single-photo posts
    image_url: str
    posted_at: datetime
    caption: str

    @property
    def key(self) -> str:
        return f"{self.post_id}-{self.index}"

    @property
    def post_url(self) -> str:
        return f"https://t.me/{self.channel}/{self.post_id}"


def fetch_channel_images(client: httpx.Client, channel: str) -> list[ChannelImage]:
    # Telegram redirects /s/<channel> to /<channel> when there is no public preview.
    resp = client.get(f"https://t.me/s/{channel}", follow_redirects=False)
    if resp.is_redirect:
        raise ChannelUnavailable(f"t.me/s/{channel} has no public preview (renamed, private or deleted?)")
    resp.raise_for_status()
    if "tgme_widget_message" not in resp.text:
        raise ChannelUnavailable(f"t.me/s/{channel} returned no posts; the page layout may have changed")
    return parse_channel_page(resp.text, channel)


def parse_channel_page(html: str, channel: str) -> list[ChannelImage]:
    soup = BeautifulSoup(html, "html.parser")
    images: list[ChannelImage] = []
    for msg in soup.select("div.tgme_widget_message[data-post]"):
        try:
            post_id = int(msg["data-post"].rsplit("/", 1)[1])
        except (IndexError, ValueError):
            continue
        time_el = msg.select_one(".tgme_widget_message_date time[datetime]")
        if time_el is None:
            continue
        posted_at = datetime.fromisoformat(time_el["datetime"])
        text_el = msg.select_one(".tgme_widget_message_text")
        caption = text_el.get_text("\n", strip=True) if text_el else ""

        for index, wrap in enumerate(msg.select("a.tgme_widget_message_photo_wrap")):
            match = _BACKGROUND_URL.search(wrap.get("style", ""))
            if match:
                images.append(
                    ChannelImage(
                        channel=channel,
                        post_id=post_id,
                        index=index,
                        image_url=match.group(1),
                        posted_at=posted_at,
                        caption=caption,
                    )
                )
    return images
