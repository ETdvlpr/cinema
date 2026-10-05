from __future__ import annotations

import io
import logging
from datetime import datetime, timedelta

import httpx
from PIL import Image, ImageOps

from . import config
from .config import Cinema, Settings
from .extract import extract_schedule
from .publish import build_schedules
from .scrape import USER_AGENT, ChannelImage, ChannelUnavailable, fetch_channel_images
from .store import delete_poster_image, load_store, prune_store, save_store
from .validate import validate_extraction

log = logging.getLogger(__name__)


def run(settings: Settings, cinemas: list[Cinema], *, dry_run: bool = False) -> list[str]:
    """Runs one update cycle. Returns problems worth alerting on (the run itself still publishes)."""
    if not dry_run and not settings.gemini_api_key:
        raise RuntimeError("GEMINI_API_KEY is not set")

    now = datetime.now(config.TZ)
    problems: list[str] = []
    budget = settings.max_images_per_run

    with httpx.Client(headers={"User-Agent": USER_AGENT}, timeout=30) as client:
        for cinema in cinemas:
            store = load_store(cinema.id)
            try:
                images = fetch_channel_images(client, cinema.channel)
            except (httpx.HTTPError, ChannelUnavailable) as e:
                log.error("%s: fetching channel failed: %s", cinema.id, e)
                problems.append(f"{cinema.id}: {e}")
                store["last_error"] = str(e)
                if not dry_run:
                    save_store(store)
                continue

            store["last_checked"] = now.isoformat(timespec="seconds")
            store["last_error"] = None
            pending = [img for img in images if _needs_processing(img, store, now)]
            log.info("%s: %d images on page, %d to process", cinema.id, len(images), len(pending))

            for image in sorted(pending, key=lambda i: (i.posted_at, i.index), reverse=True):
                if dry_run:
                    log.info("  would process %s (%s)", image.post_url, image.posted_at)
                    continue
                if budget <= 0:
                    log.warning("Image budget exhausted; remaining images wait for the next run")
                    break
                budget -= 1
                record = _process_image(client, cinema, image, store["posters"].get(image.key), settings)
                store["posters"][image.key] = record
                if record["status"] in ("error", "failed"):
                    problems.append(f"{cinema.id}: {image.post_url}: {record['error']}")

            if not dry_run:
                prune_store(store, now)
                save_store(store)

    if not dry_run:
        build_schedules(cinemas, now)
    return problems


def _needs_processing(image: ChannelImage, store: dict, now: datetime) -> bool:
    if image.posted_at < now - timedelta(days=config.RETENTION_DAYS):
        return False
    record = store["posters"].get(image.key)
    return record is None or record["status"] == "error"


def _process_image(
    client: httpx.Client, cinema: Cinema, image: ChannelImage, record: dict | None, settings: Settings
) -> dict:
    record = record or {
        "post_id": image.post_id,
        "index": image.index,
        "post_url": image.post_url,
        "posted_at": image.posted_at.isoformat(),
        "image": None,
        "attempts": 0,
    }
    record["attempts"] += 1
    record["processed_at"] = datetime.now(config.TZ).isoformat(timespec="seconds")
    posted_on = image.posted_at.astimezone(config.TZ).date()

    try:
        resp = client.get(image.image_url, follow_redirects=True)
        resp.raise_for_status()
        record["image"] = _save_poster(resp.content, cinema.id, image.key)
        mime_type = resp.headers.get("content-type", "image/jpeg").split(";")[0]
        extraction = extract_schedule(
            resp.content,
            mime_type,
            cinema_name=cinema.name,
            posted_on=posted_on,
            caption=image.caption,
            settings=settings,
        )
    except Exception as e:  # any failure here should only affect this one image
        record["status"] = "failed" if record["attempts"] >= config.MAX_ATTEMPTS else "error"
        record["error"] = f"{type(e).__name__}: {e}"[:500]
        log.error("%s: %s: %s", cinema.id, image.post_url, record["error"])
        return record

    showtimes, rejected = validate_extraction(extraction, posted_on)
    record.update(
        model=settings.gemini_model,
        error=None,
        notes=extraction.notes,
        showtimes=[s.to_dict() for s in showtimes],
        rejected=rejected,
    )
    if not extraction.is_schedule:
        record["status"] = "not_schedule"
        delete_poster_image(record)
    else:
        record["status"] = "ok" if showtimes else "unreadable"
    log.info(
        "%s: %s -> %s (%d showtimes, %d rejected)",
        cinema.id, image.post_url, record["status"], len(showtimes), len(rejected),
    )
    return record


def _save_poster(data: bytes, cinema_id: str, key: str) -> str:
    dest = config.POSTERS_DIR / cinema_id / f"{key}.jpg"
    dest.parent.mkdir(parents=True, exist_ok=True)
    with Image.open(io.BytesIO(data)) as img:
        img = ImageOps.exif_transpose(img).convert("RGB")
        img.thumbnail((1280, 1280))
        img.save(dest, "JPEG", quality=80, optimize=True)
    return dest.relative_to(config.PUBLIC_DIR).as_posix()
