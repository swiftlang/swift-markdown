#!/usr/bin/env python3
"""
DocC Reference Resolver

Transforms doc://Markdown/... references in JSON files to absolute local file paths.

Example transformation:
  doc://Markdown/documentation/Markdown/DoxygenReturns
  ->
  /Users/home/GitHub/AdlerView/swift-markdown/DOCUMENTATION/data/documentation/markdown/doxygenreturns.json

Usage:
    python resolve_refs.py [options]

Options:
    --base-path PATH    Base path for resolved references (default: auto-detect)
    --in-place          Modify JSON files in place (adds 'resolvedPath' fields)
    --output FILE       Write reference mapping to JSON file
    --dry-run           Show transformations without writing
    --verbose           Print detailed progress
"""

import argparse
import json
import os
import re
import sys
from pathlib import Path
from typing import Dict, List, Optional, Tuple, Any


# Configuration
SCRIPT_DIR = Path(__file__).parent.resolve()
DATA_DIR = SCRIPT_DIR / "data"
DOC_PREFIX = "doc://Markdown/"
DEFAULT_BASE_PATH = "/Users/home/GitHub/AdlerView/swift-markdown/DOCUMENTATION/data"


def doc_url_to_path(doc_url: str, base_path: str) -> str:
    """
    Convert a doc:// URL to a local file path.

    Args:
        doc_url: DocC URL (e.g., 'doc://Markdown/documentation/Markdown/Table')
        base_path: Base path for the documentation data

    Returns:
        Absolute file path (e.g., '/path/to/data/documentation/markdown/table.json')
    """
    if not doc_url.startswith(DOC_PREFIX):
        return doc_url

    # Remove the doc://Markdown/ prefix
    relative_path = doc_url[len(DOC_PREFIX):]

    # Convert to lowercase (DocC uses lowercase paths)
    relative_path = relative_path.lower()

    # Build the full path with .json extension
    full_path = os.path.join(base_path, relative_path + ".json")

    return full_path


def find_doc_references(obj: Any, refs: Optional[List[str]] = None) -> List[str]:
    """
    Recursively find all doc:// references in a JSON object.

    Args:
        obj: JSON object (dict, list, or primitive)
        refs: List to accumulate references

    Returns:
        List of unique doc:// URLs found
    """
    if refs is None:
        refs = []

    if isinstance(obj, dict):
        for key, value in obj.items():
            # Check for common reference keys
            if key in ('identifier', 'url') and isinstance(value, str):
                if value.startswith(DOC_PREFIX):
                    refs.append(value)
            # Also check values that might be doc:// strings
            elif isinstance(value, str) and value.startswith(DOC_PREFIX):
                refs.append(value)
            else:
                find_doc_references(value, refs)
    elif isinstance(obj, list):
        for item in obj:
            find_doc_references(item, refs)
    elif isinstance(obj, str) and obj.startswith(DOC_PREFIX):
        refs.append(obj)

    return refs


def add_resolved_paths(obj: Any, base_path: str) -> Any:
    """
    Add 'resolvedPath' fields next to doc:// references.

    Args:
        obj: JSON object to modify
        base_path: Base path for resolved references

    Returns:
        Modified JSON object with resolvedPath fields added
    """
    if isinstance(obj, dict):
        new_obj = {}
        for key, value in obj.items():
            new_obj[key] = add_resolved_paths(value, base_path)
            # Add resolvedPath for identifier fields
            if key == 'identifier' and isinstance(value, str) and value.startswith(DOC_PREFIX):
                new_obj['resolvedPath'] = doc_url_to_path(value, base_path)
            # Add resolvedPath for url fields in references
            elif key == 'url' and isinstance(value, str) and value.startswith('/documentation/'):
                # Convert relative URL to doc:// format first
                doc_url = DOC_PREFIX + value.lstrip('/')
                new_obj['resolvedPath'] = doc_url_to_path(doc_url, base_path)
        return new_obj
    elif isinstance(obj, list):
        return [add_resolved_paths(item, base_path) for item in obj]
    else:
        return obj


def process_json_file(
    file_path: Path,
    base_path: str,
    in_place: bool = False,
    verbose: bool = False
) -> Dict[str, str]:
    """
    Process a single JSON file and extract/transform references.

    Args:
        file_path: Path to JSON file
        base_path: Base path for resolved references
        in_place: Whether to modify the file in place
        verbose: Print verbose output

    Returns:
        Dictionary mapping doc:// URLs to local paths
    """
    mapping = {}

    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            data = json.load(f)
    except (json.JSONDecodeError, IOError) as e:
        if verbose:
            print(f"  Error reading {file_path}: {e}")
        return mapping

    # Find all references
    refs = find_doc_references(data)
    unique_refs = list(dict.fromkeys(refs))  # Preserve order, remove duplicates

    # Create mapping
    for ref in unique_refs:
        resolved = doc_url_to_path(ref, base_path)
        mapping[ref] = resolved

    # Optionally modify file in place
    if in_place and unique_refs:
        modified_data = add_resolved_paths(data, base_path)
        with open(file_path, 'w', encoding='utf-8') as f:
            json.dump(modified_data, f, indent=2, ensure_ascii=False)
        if verbose:
            print(f"  Modified: {file_path.name} ({len(unique_refs)} references)")

    return mapping


def find_json_files(data_dir: Path) -> List[Path]:
    """Find all JSON files in the data directory."""
    return list(data_dir.rglob("*.json"))


def main():
    parser = argparse.ArgumentParser(
        description="Transform doc://Markdown/ references to local file paths",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__
    )

    parser.add_argument(
        '--base-path',
        type=str,
        default=DEFAULT_BASE_PATH,
        help=f'Base path for resolved references (default: {DEFAULT_BASE_PATH})'
    )

    parser.add_argument(
        '--data-dir',
        type=Path,
        default=DATA_DIR,
        help=f'Directory containing JSON files (default: {DATA_DIR})'
    )

    parser.add_argument(
        '--in-place',
        action='store_true',
        help='Modify JSON files in place (adds resolvedPath fields)'
    )

    parser.add_argument(
        '--output', '-o',
        type=Path,
        help='Write complete reference mapping to JSON file'
    )

    parser.add_argument(
        '--dry-run',
        action='store_true',
        help='Show transformations without writing'
    )

    parser.add_argument(
        '--verbose', '-v',
        action='store_true',
        help='Print detailed progress'
    )

    parser.add_argument(
        '--example',
        action='store_true',
        help='Show example transformations and exit'
    )

    args = parser.parse_args()

    # Show example transformations
    if args.example:
        print("Example transformations:")
        print("-" * 70)
        examples = [
            "doc://Markdown/documentation/Markdown",
            "doc://Markdown/documentation/Markdown/DoxygenReturns",
            "doc://Markdown/documentation/Markdown/DoxygenReturns/init(children:)-20o7i",
            "doc://Markdown/documentation/Markdown/Table",
            "doc://Markdown/documentation/Markdown/BlockMarkup",
        ]
        for ex in examples:
            resolved = doc_url_to_path(ex, args.base_path)
            print(f"\n  {ex}")
            print(f"  -> {resolved}")
        return

    # Check data directory exists
    if not args.data_dir.exists():
        print(f"Error: Data directory not found: {args.data_dir}", file=sys.stderr)
        print("Run scrape.py first to download documentation.", file=sys.stderr)
        sys.exit(1)

    # Find all JSON files
    json_files = find_json_files(args.data_dir)

    if not json_files:
        print(f"No JSON files found in {args.data_dir}", file=sys.stderr)
        sys.exit(1)

    print(f"Found {len(json_files)} JSON files in {args.data_dir}")
    print(f"Base path: {args.base_path}")

    if args.dry_run:
        print("\n--- DRY RUN MODE ---")

    if args.in_place and not args.dry_run:
        print("\nModifying files in place...")

    # Process all files
    all_mappings: Dict[str, str] = {}
    files_with_refs = 0
    total_refs = 0

    for i, json_file in enumerate(json_files, 1):
        if args.verbose:
            print(f"[{i}/{len(json_files)}] Processing: {json_file.relative_to(args.data_dir)}")

        mapping = process_json_file(
            json_file,
            args.base_path,
            in_place=args.in_place and not args.dry_run,
            verbose=args.verbose
        )

        if mapping:
            files_with_refs += 1
            total_refs += len(mapping)
            all_mappings.update(mapping)

    # Print summary
    print("\n" + "=" * 60)
    print("SUMMARY")
    print("=" * 60)
    print(f"  Files processed:     {len(json_files)}")
    print(f"  Files with refs:     {files_with_refs}")
    print(f"  Total references:    {total_refs}")
    print(f"  Unique references:   {len(all_mappings)}")
    print("=" * 60)

    # Show sample mappings
    if args.verbose or args.dry_run:
        print("\nSample mappings (first 5):")
        for i, (doc_url, local_path) in enumerate(list(all_mappings.items())[:5]):
            print(f"\n  {doc_url}")
            print(f"  -> {local_path}")

    # Write output file
    if args.output and not args.dry_run:
        output_data = {
            "basePath": args.base_path,
            "totalReferences": len(all_mappings),
            "mappings": all_mappings
        }
        with open(args.output, 'w', encoding='utf-8') as f:
            json.dump(output_data, f, indent=2, ensure_ascii=False)
        print(f"\nMapping written to: {args.output}")


if __name__ == '__main__':
    main()
