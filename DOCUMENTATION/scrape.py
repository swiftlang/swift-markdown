#!/usr/bin/env python3
"""
Swift-Markdown Documentation Scraper

Mirrors the DocC documentation from https://swiftlang.github.io/swift-markdown/
to the local DOCUMENTATION folder by fetching JSON data files.

Usage:
    python scrape.py [options]

Options:
    --resume        Skip files that already exist locally
    --verbose       Print detailed progress information
    --delay FLOAT   Delay between requests in seconds (default: 1.0)
    --max-retries N Maximum retry attempts for failed requests (default: 3)
    --dry-run       Print URLs that would be fetched without downloading
"""

import argparse
import json
import os
import sys
import time
import urllib.parse
import urllib.request
import urllib.error
from pathlib import Path
from typing import Generator


# Configuration
BASE_URL = "https://swiftlang.github.io/swift-markdown"
DATA_URL_TEMPLATE = BASE_URL + "/data{path}.json"
SCRIPT_DIR = Path(__file__).parent.resolve()
INDEX_FILE = SCRIPT_DIR / "index.json"
OUTPUT_DIR = SCRIPT_DIR / "data"

# HTTP settings
USER_AGENT = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
DEFAULT_DELAY = 1.0
DEFAULT_MAX_RETRIES = 3
BACKOFF_FACTOR = 2.0


def extract_paths_from_index(index_path: Path) -> Generator[str, None, None]:
    """
    Parse the index.json file and extract all documentation paths.

    Args:
        index_path: Path to the index.json file

    Yields:
        Documentation paths (e.g., '/documentation/markdown/table')
    """
    with open(index_path, 'r', encoding='utf-8') as f:
        data = json.load(f)

    def extract_recursive(items: list) -> Generator[str, None, None]:
        for item in items:
            if 'path' in item:
                yield item['path']
            if 'children' in item:
                yield from extract_recursive(item['children'])

    interface_languages = data.get('interfaceLanguages', {})
    swift_items = interface_languages.get('swift', [])
    yield from extract_recursive(swift_items)


def path_to_url(doc_path: str) -> str:
    """
    Convert a documentation path to its corresponding data URL.

    Args:
        doc_path: Documentation path (e.g., '/documentation/markdown/table')

    Returns:
        Full URL to the JSON data file
    """
    # URL encode the path components but preserve slashes
    parts = doc_path.split('/')
    encoded_parts = [urllib.parse.quote(part, safe='') for part in parts]
    encoded_path = '/'.join(encoded_parts)
    return DATA_URL_TEMPLATE.format(path=encoded_path)


def path_to_local_file(doc_path: str, output_dir: Path) -> Path:
    """
    Convert a documentation path to its local file path.

    Args:
        doc_path: Documentation path (e.g., '/documentation/markdown/table')
        output_dir: Base output directory

    Returns:
        Local file path for the JSON data
    """
    # Remove leading slash and add .json extension
    relative_path = doc_path.lstrip('/') + '.json'
    return output_dir / relative_path


def download_file(
    url: str,
    dest_path: Path,
    max_retries: int = DEFAULT_MAX_RETRIES,
    delay: float = DEFAULT_DELAY,
    verbose: bool = False
) -> bool:
    """
    Download a file from URL with retry logic and exponential backoff.

    Args:
        url: URL to download
        dest_path: Local destination path
        max_retries: Maximum number of retry attempts
        delay: Base delay between retries
        verbose: Print detailed progress

    Returns:
        True if download succeeded, False otherwise
    """
    headers = {
        'User-Agent': USER_AGENT,
        'Accept': 'application/json',
    }

    for attempt in range(max_retries + 1):
        try:
            request = urllib.request.Request(url, headers=headers)
            with urllib.request.urlopen(request, timeout=30) as response:
                content = response.read()

                # Create parent directories if needed
                dest_path.parent.mkdir(parents=True, exist_ok=True)

                # Write content to file
                with open(dest_path, 'wb') as f:
                    f.write(content)

                if verbose:
                    print(f"  Downloaded: {dest_path.name} ({len(content)} bytes)")

                return True

        except urllib.error.HTTPError as e:
            if e.code == 404:
                if verbose:
                    print(f"  Not found (404): {url}")
                return False
            elif e.code == 403:
                if verbose:
                    print(f"  Forbidden (403): {url} - may need rate limiting")
            else:
                if verbose:
                    print(f"  HTTP error {e.code}: {url}")

        except urllib.error.URLError as e:
            if verbose:
                print(f"  Network error: {e.reason}")

        except TimeoutError:
            if verbose:
                print(f"  Timeout: {url}")

        # Retry with exponential backoff
        if attempt < max_retries:
            wait_time = delay * (BACKOFF_FACTOR ** attempt)
            if verbose:
                print(f"  Retrying in {wait_time:.1f}s (attempt {attempt + 1}/{max_retries})...")
            time.sleep(wait_time)

    return False


def mirror_documentation(
    index_path: Path = INDEX_FILE,
    output_dir: Path = OUTPUT_DIR,
    resume: bool = False,
    verbose: bool = False,
    delay: float = DEFAULT_DELAY,
    max_retries: int = DEFAULT_MAX_RETRIES,
    dry_run: bool = False
) -> dict:
    """
    Mirror all documentation from the remote site to local storage.

    Args:
        index_path: Path to index.json
        output_dir: Output directory for downloaded files
        resume: Skip existing files
        verbose: Print detailed progress
        delay: Delay between requests
        max_retries: Maximum retry attempts
        dry_run: Only print URLs without downloading

    Returns:
        Statistics dictionary with counts of success, skipped, failed
    """
    stats = {
        'total': 0,
        'downloaded': 0,
        'skipped': 0,
        'failed': 0,
        'not_found': 0,
    }

    # Extract all paths from index
    paths = list(extract_paths_from_index(index_path))
    unique_paths = list(dict.fromkeys(paths))  # Preserve order, remove duplicates
    stats['total'] = len(unique_paths)

    print(f"Found {stats['total']} unique documentation paths")
    print(f"Output directory: {output_dir}")

    if dry_run:
        print("\n--- DRY RUN MODE ---")
        for path in unique_paths[:10]:
            url = path_to_url(path)
            local_file = path_to_local_file(path, output_dir)
            print(f"  {url}")
            print(f"    -> {local_file}")
        if len(unique_paths) > 10:
            print(f"  ... and {len(unique_paths) - 10} more")
        return stats

    print(f"\nStarting download (delay: {delay}s, max_retries: {max_retries})...")
    print("-" * 60)

    for i, path in enumerate(unique_paths, 1):
        url = path_to_url(path)
        local_file = path_to_local_file(path, output_dir)

        # Progress indicator
        progress = f"[{i}/{stats['total']}]"

        # Check if file exists (resume mode)
        if resume and local_file.exists():
            stats['skipped'] += 1
            if verbose:
                print(f"{progress} Skipped (exists): {path}")
            continue

        print(f"{progress} {path}")

        # Download the file
        success = download_file(
            url=url,
            dest_path=local_file,
            max_retries=max_retries,
            delay=delay,
            verbose=verbose
        )

        if success:
            stats['downloaded'] += 1
        else:
            stats['failed'] += 1

        # Delay between requests (except for last one)
        if i < stats['total'] and success:
            time.sleep(delay)

    return stats


def print_stats(stats: dict):
    """Print summary statistics."""
    print("\n" + "=" * 60)
    print("SUMMARY")
    print("=" * 60)
    print(f"  Total paths:    {stats['total']}")
    print(f"  Downloaded:     {stats['downloaded']}")
    print(f"  Skipped:        {stats['skipped']}")
    print(f"  Failed:         {stats['failed']}")
    print("=" * 60)


def main():
    parser = argparse.ArgumentParser(
        description="Mirror swift-markdown DocC documentation to local storage",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__
    )

    parser.add_argument(
        '--resume',
        action='store_true',
        help='Skip files that already exist locally'
    )

    parser.add_argument(
        '--verbose', '-v',
        action='store_true',
        help='Print detailed progress information'
    )

    parser.add_argument(
        '--delay',
        type=float,
        default=DEFAULT_DELAY,
        help=f'Delay between requests in seconds (default: {DEFAULT_DELAY})'
    )

    parser.add_argument(
        '--max-retries',
        type=int,
        default=DEFAULT_MAX_RETRIES,
        help=f'Maximum retry attempts for failed requests (default: {DEFAULT_MAX_RETRIES})'
    )

    parser.add_argument(
        '--dry-run',
        action='store_true',
        help='Print URLs that would be fetched without downloading'
    )

    parser.add_argument(
        '--output-dir',
        type=Path,
        default=OUTPUT_DIR,
        help=f'Output directory for downloaded files (default: {OUTPUT_DIR})'
    )

    parser.add_argument(
        '--index-file',
        type=Path,
        default=INDEX_FILE,
        help=f'Path to index.json file (default: {INDEX_FILE})'
    )

    args = parser.parse_args()

    # Validate index file exists
    if not args.index_file.exists():
        print(f"Error: Index file not found: {args.index_file}", file=sys.stderr)
        print("Please ensure index.json exists in the DOCUMENTATION directory.", file=sys.stderr)
        sys.exit(1)

    try:
        stats = mirror_documentation(
            index_path=args.index_file,
            output_dir=args.output_dir,
            resume=args.resume,
            verbose=args.verbose,
            delay=args.delay,
            max_retries=args.max_retries,
            dry_run=args.dry_run
        )

        print_stats(stats)

        # Exit with error code if any failures
        if stats['failed'] > 0:
            sys.exit(1)

    except KeyboardInterrupt:
        print("\n\nInterrupted by user. Use --resume to continue later.")
        sys.exit(130)
    except Exception as e:
        print(f"\nError: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == '__main__':
    main()
