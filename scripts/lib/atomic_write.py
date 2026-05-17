#!/usr/bin/env python3
"""
atomic-write.py — Atomic file write helper for state/checkpoint files
Usage: from atomic_write import atomic_write

Pattern: write to temp file in same directory → fsync → atomic rename.
Guarantees: either complete file exists or old file remains. No partial writes.
"""

import os
import json
import tempfile
import shutil
from typing import Any, Union


def atomic_write(filepath: str, content: Union[dict, list, str], json_mode: bool = True) -> bool:
    """
    Atomically write content to filepath.
    
    Args:
        filepath: Target file path (absolute)
        content: Content to write (dict/list for JSON, str for text)
        json_mode: If True, serialize content as JSON. If False, write as text.
    
    Returns:
        bool: True on success, False on failure
    
    Guarantees:
        - If function returns True: file is complete and valid
        - If function returns False: old file (if exists) is untouched
        - No partial/corrupted file ever exists at filepath
    """
    # Get directory for temp file (must be same filesystem for atomic rename)
    target_dir = os.path.dirname(os.path.abspath(filepath))
    
    # Ensure directory exists
    os.makedirs(target_dir, exist_ok=True)
    
    temp_path = None
    
    try:
        # Step 1: Create temp file in same directory
        fd, temp_path = tempfile.mkstemp(
            dir=target_dir,
            prefix='.atomic_write_',
            suffix='.tmp'
        )
        
        with os.fdopen(fd, 'w') as f:
            if json_mode:
                json.dump(content, f, indent=2)
            else:
                f.write(content)
            
            # Step 2: Flush Python buffers
            f.flush()
            
            # Step 3: fsync to disk (guarantees data is on physical media)
            os.fsync(f.fileno())
        
        # Step 4: Atomic rename (POSIX guarantee: atomic on same filesystem)
        os.replace(temp_path, filepath)
        
        # Step 5: Sync directory to ensure rename is persisted
        dir_fd = os.open(target_dir, os.O_RDONLY | os.O_DIRECTORY)
        try:
            os.fsync(dir_fd)
        finally:
            os.close(dir_fd)
        
        return True
        
    except Exception:
        # Cleanup temp file on any failure
        if temp_path and os.path.exists(temp_path):
            try:
                os.unlink(temp_path)
            except OSError:
                pass
        return False


def atomic_write_json(filepath: str, data: Union[dict, list]) -> bool:
    """Convenience wrapper for atomic JSON write."""
    return atomic_write(filepath, data, json_mode=True)


def atomic_read_json(filepath: str) -> Union[dict, list, None]:
    """Atomic-safe read (JSON). Returns None if file doesn't exist or is corrupt."""
    try:
        with open(filepath, 'r') as f:
            return json.load(f)
    except (FileNotFoundError, json.JSONDecodeError, OSError):
        return None


if __name__ == '__main__':
    # Self-test
    import tempfile as tmp_dir
    
    with tmp_dir.TemporaryDirectory() as td:
        test_file = os.path.join(td, 'test.json')
        
        # Test 1: Basic JSON write
        data = {"test": True, "value": 42}
        assert atomic_write_json(test_file, data) == True
        read_back = atomic_read_json(test_file)
        assert read_back == data
        print("✅ Test 1: Basic JSON write")
        
        # Test 2: Overwrite existing file
        data2 = {"test": True, "value": 99}
        assert atomic_write_json(test_file, data2) == True
        read_back2 = atomic_read_json(test_file)
        assert read_back2 == data2
        print("✅ Test 2: Overwrite existing file")
        
        # Test 3: Text mode
        text_file = os.path.join(td, 'test.txt')
        assert atomic_write(text_file, "hello world", json_mode=False) == True
        with open(text_file) as f:
            assert f.read() == "hello world"
        print("✅ Test 3: Text mode")
        
        # Test 4: Verify no temp files left behind
        temp_files = [f for f in os.listdir(td) if f.startswith('.atomic_write_')]
        assert len(temp_files) == 0
        print("✅ Test 4: No orphaned temp files")
        
        print()
        print("All tests passed. atomic-write.py is ready.")
