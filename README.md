# github-utils

## Rediscover Commits after Force Push

In order to calculate the DORA "lead time" metric, you need to find the oldest new commit included in a release. If someone force-pushes to a long-lived feature branch, history is rewritten and may make it look like the feature branch was much more recently begun than it was.

[rediscover-commits.sh](./rediscover-commits.sh) is the beginning of a script that can be used to find the oldest new commit included in a release, even if the history has been rewritten. At present, it only looks for and displays the commits that were overwritten by a force push.
