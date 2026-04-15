# Common Errors

## Warning: "فهرسة المقاطع غير متاحة" / `regulation_chunk_index_fallback_used`

- **Symptom**: In the Case Linking Studio, the panel shows a yellow warning banner reading "يتم استخدام نص بديل (فهرسة المقاطع غير متاحة)". Line matches in the Regulation tab are sparse or absent. Match evidence lacks article references and line numbers.
- **Root cause**: The AI service (`find_related.py`) could not find pre-indexed chunks for the matched regulation. Without chunks it falls back to treating the entire regulation as a single text blob (title + category + full content). This produces coarser matches with no per-article granularity and no `line_start`/`line_end` data.
- **Impact**: Match quality is lower than normal. The confidence score is still valid but the line-level evidence (highlighted regulation lines, article refs) is missing or unreliable.
- **Fix**:
  1. Run the chunk backfill script to index any regulation that is missing chunks:
     ```bash
     cd Legal-Case-Management-System
     npx tsx src/scripts/backfill-regulation-chunks.ts
     ```
  2. After the backfill completes, go back to the Case Linking Studio for the affected case and click **Generate Suggestions** to re-run the AI analysis against the newly indexed chunks.
  3. The warning will disappear for regulations that now have valid chunk entries.
- **Long-term prevention**: Ensure the regulation ingestion/upload route triggers chunking automatically for newly added regulations so the fallback path is only reached for legacy records. Check `Legal-Case-Management-System/src/routes/regulations/` to verify this is wired up.
- **Relevant files**:
  - `Legal-Case-Management-System-AI-Microservice/ai_service/app/api/routes/find_related.py` — line 142 (where warning is emitted)
  - `Legal-Case-Management-System/src/scripts/backfill-regulation-chunks.ts` — backfill script
  - `Legal-Case-Management-System/src/routes/ai-links/index.ts` — line 382 (where warning is forwarded to frontend)
  - `Legal_Case_Management_Website/src/components/features/cases/linking/LinkDetailPanel.tsx` — warning display in the Warnings section

---

## AI settings cards appear navy/blue unexpectedly

- **Symptom**: In the Settings page AI tab, cards and inputs show navy/blue backgrounds even after changing normal color classes.
- **Root cause**: Dark-mode utility classes (for example `dark:bg-slate-900`, `dark:bg-slate-800`, `dark:border-slate-700`) override base styles when dark theme is active.
- **Fix**:
  - Remove or override `dark:*` background/border classes for AI tab cards and inputs.
  - Keep explicit neutral classes like `bg-white`, `border-slate-200`, `text-slate-900` where needed.
  - Verify range/input controls do not inherit browser default accent color by setting explicit accent/thumb styling if required.
