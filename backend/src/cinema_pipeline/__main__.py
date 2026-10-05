from __future__ import annotations

import argparse
import json
import logging
import mimetypes
import sys
from datetime import date, datetime
from pathlib import Path

from . import config, pipeline
from .config import Settings, load_cinemas
from .extract import extract_schedule
from .publish import build_schedules
from .validate import validate_extraction


def main() -> int:
    parser = argparse.ArgumentParser(prog="cinema_pipeline")
    sub = parser.add_subparsers(dest="command", required=True)

    run_p = sub.add_parser("run", help="scrape channels, extract new posters, publish schedules.json")
    run_p.add_argument("--cinema", action="append", help="only process this cinema id (repeatable)")
    run_p.add_argument("--dry-run", action="store_true", help="scrape only; don't call the model or write files")
    run_p.add_argument("--problems-file", type=Path, help="write problems here, one per line")

    sub.add_parser("build", help="rebuild schedules.json from stored extractions")

    ext_p = sub.add_parser("extract", help="run extraction + validation on a local image (for tuning)")
    ext_p.add_argument("image", type=Path)
    ext_p.add_argument("--cinema-name", default="a cinema")
    ext_p.add_argument("--posted-on", type=date.fromisoformat, default=date.today())

    args = parser.parse_args()
    logging.basicConfig(level=logging.INFO, format="%(levelname)s %(message)s")

    if args.command == "run":
        cinemas = load_cinemas()
        if args.cinema:
            cinemas = [c for c in cinemas if c.id in args.cinema]
        problems = pipeline.run(Settings.from_env(), cinemas, dry_run=args.dry_run)
        if args.problems_file:
            args.problems_file.write_text("".join(p.replace("\n", " ") + "\n" for p in problems), encoding="utf-8")
        for p in problems:
            logging.warning("PROBLEM %s", p)
        return 0

    if args.command == "build":
        build_schedules(load_cinemas(), datetime.now(config.TZ))
        return 0

    if args.command == "extract":
        mime_type = mimetypes.guess_type(args.image.name)[0] or "image/jpeg"
        extraction, model = extract_schedule(
            args.image.read_bytes(),
            mime_type,
            cinema_name=args.cinema_name,
            posted_on=args.posted_on,
            caption="",
            settings=Settings.from_env(),
        )
        showtimes, rejected = validate_extraction(extraction, args.posted_on)
        print(json.dumps(
            {
                "model": model,
                "raw": extraction.model_dump(),
                "accepted": [s.to_dict() for s in showtimes],
                "rejected": [{"reason": r["reason"], "film": r["raw"]["film_title_latin"]} for r in rejected],
            },
            ensure_ascii=False,
            indent=2,
        ))
        return 0

    return 1


if __name__ == "__main__":
    sys.exit(main())
