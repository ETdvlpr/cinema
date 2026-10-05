from __future__ import annotations

import io
import logging
from datetime import datetime, timedelta

import httpx
from PIL import Image, ImageOps

from . import config
from .config import Cinema, Settings
from .extract import ModelsUnavailable, all_models_exhausted, extract_schedule
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
    stores: dict[str, dict] = {}
    queue: list[tuple[Cinema, ChannelImage]] = []

    with httpx.Client(headers={"User-Agent": USER_AGENT}, timeout=30) as client:
        for cinema in cinemas:
            store = stores[cinema.id] = load_store(cinema.id)
            try:
                images = fetch_channel_images(client, cinema.channel)
            except (httpx.HTTPError, ChannelUnavailable) as e:
                log.error("%s: fetching channel failed: %s", cinema.id, e)
                problems.append(f"{cinema.id}: {e}")
                store["last_error"] = str(e)
                continue
            store["last_checked"] = now.isoformat(timespec="seconds")
            store["last_error"] = None
            pending = [img for img in images if _needs_processing(img, store, now)]
            log.info("%s: %d images on page, %d to process", cinema.id, len(images), len(pending))
            queue += [(cinema, img) for img in pending]

        # Newest first across all cinemas, so a limited quota goes to the most current schedules.
        queue.sort(key=lambda item: (item[1].posted_at, -item[1].index), reverse=True)

        if dry_run:
            for cinema, image in queue:
                log.info("would process %s (%s)", image.post_url, image.posted_at)
            return problems

        for n, (cinema, image) in enumerate(queue):
            if n >= settings.max_images_per_run:
                log.warning("Image budget reached; %d images wait for the next run", len(queue) - n)
                break
            if all_models_exhausted(settings):
                log.warning("All models over quota; %d images wait for the next run", len(queue) - n)
                break
            store = stores[cinema.id]
            record = _process_image(client, cinema, image, store["posters"].get(image.key), settings)
            store["posters"][image.key] = record
            if record["status"] == "failed":
                problems.append(f"{cinema.id}: {image.post_url}: {record['error']}")

    for cinema_id, store in stores.items():
        problems += _expire_or_flag_stuck(cinema_id, store, now)
        prune_store(store, now)
        save_store(store)
    build_schedules(cinemas, now)
    return problems


def _needs_processing(image: ChannelImage, store: dict, now: datetime) -> bool:
    if image.posted_at < now - timedelta(days=config.PROCESS_MAX_AGE_DAYS):
        return False
    record = store["posters"].get(image.key)
    return record is None or record["status"] == "error"


def _expire_or_flag_stuck(cinema_id: str, store: dict, now: datetime) -> list[str]:
    """Images still erroring: give up quietly once too old to matter, alert if stuck for long."""
    problems = []
    for record in store["posters"].values():
        if record["status"] != "error":
            continue
        if datetime.fromisoformat(record["posted_at"]) < now - timedelta(days=config.PROCESS_MAX_AGE_DAYS):
            record["status"] = "expired"
            continue
        first_attempt = datetime.fromisoformat(record.get("first_attempt_at") or record["processed_at"])
        if now - first_attempt > timedelta(hours=config.ALERT_AFTER_HOURS):
            problems.append(
                f"{cinema_id}: {record['post_url']} not extracted after {config.ALERT_AFTER_HOURS}h: {record['error']}"
            )
    return problems


def _process_image(
    client: httpx.Client, cinema: Cinema, image: ChannelImage, record: dict | None, settings: Settings
) -> dict:
    now = datetime.now(config.TZ).isoformat(timespec="seconds")
    record = record or {
        "post_id": image.post_id,
        "index": image.index,
        "post_url": image.post_url,
        "posted_at": image.posted_at.isoformat(),
        "image": None,
        "attempts": 0,
    }
    record.setdefault("first_attempt_at", now)
    record["processed_at"] = now
    posted_on = image.posted_at.astimezone(config.TZ).date()

    try:
        resp = client.get(image.image_url, follow_redirects=True)
        resp.raise_for_status()
        record["image"] = _save_poster(resp.content, cinema.id, image.key)
        mime_type = resp.headers.get("content-type", "image/jpeg").split(";")[0]
        extraction, model = extract_schedule(
            resp.content,
            mime_type,
            cinema_name=cinema.name,
            posted_on=posted_on,
            caption=image.caption,
            settings=settings,
        )
    except ModelsUnavailable as e:
        # Quota/overload: not this image's fault, so it doesn't use up an attempt.
        record["status"] = "error"
        record["error"] = str(e)[:500]
        log.warning("%s: %s: %s", cinema.id, image.post_url, e)
        return record
    except Exception as e:  # any other failure should only affect this one image
        record["attempts"] += 1
        record["status"] = "failed" if record["attempts"] >= config.MAX_ATTEMPTS else "error"
        record["error"] = f"{type(e).__name__}: {e}"[:500]
        log.error("%s: %s: %s", cinema.id, image.post_url, record["error"])
        return record

    showtimes, rejected = validate_extraction(extraction, posted_on)
    record.update(
        attempts=record["attempts"] + 1,
        model=model,
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
        "%s: %s -> %s via %s (%d showtimes, %d rejected)",
        cinema.id, image.post_url, record["status"], model, len(showtimes), len(rejected),
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
