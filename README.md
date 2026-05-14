# github-utils

## Rediscover Commits after Force Push

In order to calculate the DORA "lead time" metric, you need to find the oldest new commit included in a release. If someone force-pushes to a long-lived feature branch, history is rewritten and may make it look like the feature branch was much more recently begun than it was.

[rediscover-commits.sh](./rediscover-commits.sh) is the beginning of a script that can be used to find the oldest new commit included in a release, even if the history has been rewritten. At present, it only looks for and displays the commits that were overwritten by a force push.

Example usage:

```
dane@DaneWeber0F00E70:~/repos/daneweber/github-utils$ ./rediscover-commits.sh DaneWeber github-utils 1
Fetching PR timeline for DaneWeber/github-utils#1...

Found 2 force push event(s)

Force push at: 2026-05-14T15:31:12Z
Before: f3fa8b17d9e3652bf10a03f0401cf3de5ee5a8e7
After:  c987e5190b6c398ac0bfdcfcda4880dc681a0ab8

Original commits (before force push to f3fa8b17d9e3652bf10a03f0401cf3de5ee5a8e7):
====================================================

Date: 2026-05-14T15:29:03Z
Commit: 95b2872
Author: Dane Weber
Message: Point to new repo

Date: 2026-05-14T15:29:56Z
Commit: f3fa8b1
Author: Dane Weber
Message: Rename script file

---

Force push at: 2026-05-14T15:35:13Z
Before: 2e1ee71467f3cdede423dc4f696b27dbe469c03e
After:  5241f90a625c272b9ad09634cabcf520f1036cfb

Original commits (before force push to 2e1ee71467f3cdede423dc4f696b27dbe469c03e):
====================================================

Date: 2026-05-14T15:29:03Z
Commit: c987e51
Author: Dane Weber
Message: Point to new repo and rename script file

Date: 2026-05-14T15:34:21Z
Commit: 2e1ee71
Author: Dane Weber
Message: Explain the purpose of the script

---

Done!
```
