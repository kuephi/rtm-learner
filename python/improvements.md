# Deferred Architectural Improvements

These were identified during a DDD review of the pipeline. Each is a real improvement, but the cost isn't justified at the current scale.

---

## C — Episode Repository

**What:** Extract all file I/O into a single `EpisodeRepository` class that owns reading, writing, and state tracking. `main.py` and `fetcher.py` would stop knowing about file paths directly.

```python
class EpisodeRepository:
    def save(self, episode: Episode) -> None: ...
    def load(self, episode_num: int) -> Episode: ...
    def load_state(self) -> ProcessingState: ...
    def mark_processed(self, url: str) -> None: ...
```

**Why not now:** State management is already centralized in `config.py` (paths) and `fetcher.py` (state file logic). The persistence code in `main.py` is five lines. Adding a repository class adds indirection without solving a concrete problem.

**When to revisit:** If a second storage backend is needed (e.g. SQLite, a remote store), or if you want to mock persistence cleanly in integration tests without touching the file system.

---

## D — Application Service (slim down `main.py`)

**What:** Extract `process_entry()` into an `EpisodePipelineService` that receives its dependencies (fetcher, parser, translator, exporters) rather than calling them as globals. `main.py` becomes a thin CLI wrapper that builds the service and calls it.

```python
class EpisodePipelineService:
    def __init__(self, fetcher, parser, translator, exporters, repository): ...
    def process(self, entry: dict) -> Episode: ...
```

**Why not now:** There is exactly one caller (`main.py`), so extracting a service just moves the same code to a different file. The benefit of dependency injection only appears when you have multiple entry points or want to swap implementations in tests.

**When to revisit:** If the macOS Swift app ever calls the Python pipeline directly (e.g. via subprocess or an embedded interpreter), or if a second entry point like a web hook or a Shortcuts action is added.

---

## E — Processing Stage Tracking (resumable runs)

**What:** Track which pipeline stage each episode reached (`fetched`, `parsed`, `translated`, `exported`) so that a failed run can resume from where it left off rather than starting over.

**Why not now:** The real cost of a failed run is one LLM call (~$0.01 and ~10 seconds). The complexity of storing intermediate stage state, writing resume logic, and testing the various partial-completion paths would be many times larger than the problem it solves. The `--force` flag already handles intentional reruns.

**When to revisit:** If the pipeline ever processes large batches (dozens of episodes at once), if LLM costs increase significantly, or if the parse and translate steps become slow enough that restarting from scratch is noticeably painful.
