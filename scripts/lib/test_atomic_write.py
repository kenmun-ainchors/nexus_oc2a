#!/usr/bin/env python3
"""
Unit test for atomic_write.py
"""

import os
import sys
import json
import tempfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from atomic_write import atomic_write_json, atomic_read_json


def test_basic_write():
    with tempfile.TemporaryDirectory() as td:
        test_file = os.path.join(td, 'test.json')
        data = {"test": True, "value": 42}
        assert atomic_write_json(test_file, data) == True
        read_back = atomic_read_json(test_file)
        assert read_back == data
        print("✅ Test 1: Basic JSON write")


def test_overwrite():
    with tempfile.TemporaryDirectory() as td:
        test_file = os.path.join(td, 'test.json')
        atomic_write_json(test_file, {"version": 1})
        atomic_write_json(test_file, {"version": 2})
        assert atomic_read_json(test_file) == {"version": 2}
        print("✅ Test 2: Overwrite existing file")


def test_no_orphaned_temp_files():
    with tempfile.TemporaryDirectory() as td:
        test_file = os.path.join(td, 'test.json')
        atomic_write_json(test_file, {"test": True})
        temp_files = [f for f in os.listdir(td) if f.startswith('.atomic_write_')]
        assert len(temp_files) == 0
        print("✅ Test 3: No orphaned temp files")


def test_large_file():
    with tempfile.TemporaryDirectory() as td:
        test_file = os.path.join(td, 'large.json')
        data = {"atoms": [{"id": i, "desc": "x" * 100} for i in range(500)]}
        assert atomic_write_json(test_file, data) == True
        assert atomic_read_json(test_file) == data
        print("✅ Test 4: Large file write (500 atoms)")


def test_concurrent_writes():
    with tempfile.TemporaryDirectory() as td:
        test_file = os.path.join(td, 'concurrent.json')
        for i in range(50):
            atomic_write_json(test_file, {"version": i})
        assert atomic_read_json(test_file) == {"version": 49}
        print("✅ Test 5: Rapid consecutive writes (50x)")


def test_creates_parent_dirs():
    """Test 6: atomic_write creates parent directories"""
    with tempfile.TemporaryDirectory() as td:
        nested = os.path.join(td, 'a', 'b', 'c', 'test.json')
        assert atomic_write_json(nested, {"test": True}) == True
        assert atomic_read_json(nested) == {"test": True}
        print("✅ Test 6: Creates parent directories")


def test_read_nonexistent():
    """Test 7: Read non-existent file returns None"""
    with tempfile.TemporaryDirectory() as td:
        result = atomic_read_json(os.path.join(td, 'nonexistent.json'))
        assert result is None
        print("✅ Test 7: Read non-existent file returns None")


if __name__ == '__main__':
    tests = [test_basic_write, test_overwrite, test_no_orphaned_temp_files,
             test_large_file, test_concurrent_writes, test_creates_parent_dirs,
             test_read_nonexistent]
    
    passed = 0
    print("=== ATOMIC WRITE UNIT TESTS ===\n")
    
    for test in tests:
        try:
            test()
            passed += 1
        except Exception as e:
            print(f"❌ {test.__name__}: {e}")
    
    print(f"\n=== RESULTS ===")
    print(f"Passed: {passed}/{len(tests)}")
    print("✅ ALL TESTS PASSED" if passed == len(tests) else "❌ SOME TESTS FAILED")
    sys.exit(0 if passed == len(tests) else 1)
