# Common Errors

## AI settings cards appear navy/blue unexpectedly

- **Symptom**: In the Settings page AI tab, cards and inputs show navy/blue backgrounds even after changing normal color classes.
- **Root cause**: Dark-mode utility classes (for example `dark:bg-slate-900`, `dark:bg-slate-800`, `dark:border-slate-700`) override base styles when dark theme is active.
- **Fix**:
  - Remove or override `dark:*` background/border classes for AI tab cards and inputs.
  - Keep explicit neutral classes like `bg-white`, `border-slate-200`, `text-slate-900` where needed.
  - Verify range/input controls do not inherit browser default accent color by setting explicit accent/thumb styling if required.
