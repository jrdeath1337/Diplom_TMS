import sys
sys.path.append('app')
import worker_core

def test_import_worker():
    assert hasattr(worker_core, 'fetch_pending_task')
    assert hasattr(worker_core, 'process_task')
