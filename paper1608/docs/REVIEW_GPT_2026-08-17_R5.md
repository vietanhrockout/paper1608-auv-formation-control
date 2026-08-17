# Independent Review — Phase C.0 Gate Round 5

**Reviewer:** GPT/Codex  
**Claude baseline reviewed:** `a2abd47` (implementation begins at `5a1cbb9`)  
**Scope:** Git/source binding, checkpoint integrity, and readiness for the 100 s Phase C production run.  
**Verdict:** **HOLD**. Round 5 correctly fixes CWD anchoring and immutable launch-SHA propagation, but two production fail-open paths remain.

## What is now confirmed

1. `git_fingerprint.m` is anchored to the Paper 1608 repository via `git -C`, not MATLAB's CWD.
2. `exp4_rl_pts_mc_projected.m` captures a launch fingerprint once and passes it to the integrator.
3. Checkpoints and chained resumes preserve the original launch SHA.
4. The production checkpoint path is absolute/repo-anchored and the checkpoint artifact is ignored by Git.
5. Resume rejects a checkpoint whose saved SHA was mutated, and rejects a saved `git_available=false` checkpoint.

These are real improvements. C0d and the resume-chain portion of C0e support them.

## Findings

### [P0] Mid-run Git unavailability still fails open

In `projected_rk4_integrate.m`, drift is defined as:

```matlab
drifted = current_fp.available && git_fp_to_record.available && ...
    (~strcmp(current_fp.sha, git_fp_to_record.sha) || ...
     current_fp.dirty ~= git_fp_to_record.dirty);
```

If the launch fingerprint is valid but the fresh checkpoint-time fingerprint becomes unavailable, the first conjunct is false. The integrator therefore does **not** abort and writes a new checkpoint carrying the old launch fingerprint. This contradicts the documented fail-closed contract and can conceal loss of source verification during a production run.

Required behavior for a production-bound run: when `opts.launch_git_fp` exists, any of the following must abort before checkpoint replacement:

- launch fingerprint unavailable;
- current fingerprint unavailable;
- SHA mismatch;
- dirty-state mismatch.

The diagnostic override, if retained, must be explicit and must not silently apply to the normal production entry point.

### [P0] Resume checks HEAD SHA but not working-tree dirty-state equality

`resume_projected_rk4_run.m` accepts the source binding when the saved SHA equals current HEAD, then constructs `launch_git_fp` without checking:

```matlab
current_fp.dirty ~= checkpoint.git_dirty
```

Therefore this sequence is currently accepted:

1. launch and checkpoint from a clean tree;
2. edit a tracked MATLAB dependency without committing (HEAD SHA unchanged, tree now dirty);
3. resume the clean checkpoint.

The wrapper begins integrating with changed source. It may abort only at the next checkpoint, after already computing a hybrid segment; if the run completes before another checkpoint boundary, it may complete without that drift being caught at all.

The resume gate must compare both SHA **and dirty state before the first resumed RK4 step**. For normal production, a clean checkpoint must resume only from the same clean SHA.

### [P1] C0e does not exercise the advertised live-drift paths

C0e mutates fields in the checkpoint file. That proves saved-metadata rejection, but it does not test either live failure mode above:

- current Git becomes unavailable at checkpoint time;
- current working tree changes while HEAD remains identical before resume or during integration.

The phrase “git-binding integrity CONFIRMED” is therefore broader than the evidence.

Add an injectable fingerprint provider or a narrow test seam rather than modifying the real repository mid-test. At minimum, independently assert:

1. clean launch FP + mocked current unavailable → abort before checkpoint overwrite;
2. clean saved checkpoint + mocked current same SHA/dirty=true → reject before `projected_rk4_integrate` is called;
3. clean launch FP + mocked current same SHA/dirty=true at checkpoint → abort before overwrite;
4. unchanged clean fingerprint → checkpoint/resume still pass bit-exact.

### [P1] Clean-tree evidence is obtainable without weakening production

The tracked diary file explains why the committed C0e log says `dirty=1`, but it is not a reason to use `allow_dirty_launch=true` for Phase C. The production checkpoint is already ignored by `.gitignore`. Diagnostic evidence can also write its diary to an ignored/temp path, or print to an external capture location, so the source tree remains clean when `git_fingerprint()` is sampled.

For the final gate, record a real `dirty=0` production-style launch. Do **not** treat `allow_dirty_launch=true` as the resolution for the 100 s run.

## Acceptance gate for Round 6

Phase C 100 s may be greenlit when all of the following are evidenced from a clean committed tree:

- launch: unavailable or dirty fingerprint fails closed;
- checkpoint time: unavailable, SHA drift, or dirty-state drift fails closed before overwrite;
- resume time: unavailable, SHA drift, or dirty-state drift fails closed before integration;
- unchanged source still passes the existing multi-resume bit-exact regression;
- saved clean-tree evidence reports `git_available=1`, the expected final commit SHA, and `git_dirty=0`.

Until then, keep the 100 s run on hold. This review does not change Claude's MATLAB implementation.
