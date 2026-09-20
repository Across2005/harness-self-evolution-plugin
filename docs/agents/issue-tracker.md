# Issue tracker：GitHub

本仓库的 issue 与 spec 以 **GitHub issue** 形式存在（`origin` =
`github.com/Across2005/harness-self-evolution-plugin`）。所有操作走 `gh` CLI。
（另有 `gitlink` 远端镜像，仅用于分发，不作为 issue 载体。）

## 约定

- **建 issue**：`gh issue create --title "..." --body "..."`。多行正文用 heredoc。
- **读 issue**：`gh issue view <number> --comments`，需要时用 `jq` 过滤评论并一并取标签。
- **列 issue**：`gh issue list --state open --json number,title,body,labels,comments --jq '[.[] | {number, title, body, labels: [.labels[].name], comments: [.comments[].body]}]'`，配合 `--label` / `--state` 过滤。
- **评论**：`gh issue comment <number> --body "..."`
- **加/去标签**：`gh issue edit <number> --add-label "..."` / `--remove-label "..."`
- **关闭**：`gh issue close <number> --comment "..."`

仓库由 `git remote -v` 推断；在 clone 内运行时 `gh` 自动识别。

## PR 作为 triage 入口

**PR as a request surface：否。**（若本仓库把外部 PR 当作功能请求，改成 `yes`；`/triage` 会读这个开关。）

置为 `yes` 时，PR 与 issue 走同一套标签与状态，命令换成 `gh pr` 等价物：

- **读 PR**：`gh pr view <number> --comments`，diff 用 `gh pr diff <number>`。
- **列外部 PR 供 triage**：`gh pr list --state open --json number,title,body,labels,author,authorAssociation,comments`，只保留 `authorAssociation` 为 `CONTRIBUTOR` / `FIRST_TIME_CONTRIBUTOR` / `NONE` 的项（丢掉 `OWNER` / `MEMBER` / `COLLABORATOR`）。
- **评论 / 打标 / 关闭**：`gh pr comment`、`gh pr edit --add-label`/`--remove-label`、`gh pr close`。

GitHub 的 issue 与 PR 共用一套编号，故裸 `#42` 可能是任一种：先 `gh pr view 42`，失败再 `gh issue view 42`。

## skill 说「publish to the issue tracker」时

建一个 GitHub issue。

## skill 说「fetch the relevant ticket」时

跑 `gh issue view <number> --comments`。

## Wayfinding 操作

供 `/wayfinder` 使用。**map** 是一个 issue，**ticket** 是它的子 issue。

- **Map**：一个带 `wayfinder:map` 标签的 issue，正文承载 Notes / Decisions-so-far / Fog。`gh issue create --label wayfinder:map`。
- **子 ticket**：经 GitHub sub-issue 关联到 map（`gh api` 调 sub-issues 端点）。未启用 sub-issue 时，把子项加进 map 正文的 task list，并在子 issue 正文顶部写 `Part of #<map>`。标签 `wayfinder:<type>`（`research`/`prototype`/`grilling`/`task`）。认领后指派给驱动的开发者。
- **阻塞**：用 GitHub **原生 issue 依赖**（UI 可见的规范表示）。加边：`gh api --method POST repos/<owner>/<repo>/issues/<child>/dependencies/blocked_by -F issue_id=<blocker-db-id>`，其中 `<blocker-db-id>` 是阻塞者的**数字 database id**（`gh api repos/<owner>/<repo>/issues/<n> --jq .id`，**不是** `#number` 也不是 `node_id`）。GitHub 用 `issue_dependencies_summary.blocked_by` 报告未关闭的阻塞者（真正的闸门）。依赖功能不可用时，退化为子 issue 正文顶部的 `Blocked by: #<n>, #<n>` 行。所有阻塞者关闭后该 ticket 才算解锁。
- **前沿查询**：列出 map 的未关闭子项（`gh issue list --state open`，限定在 map 的 sub-issue / task list 内），剔除有未关闭阻塞者（`issue_dependencies_summary.blocked_by > 0`，或 `Blocked by` 行里有未关闭 issue）或有指派人的项；按 map 顺序取第一个。
- **认领**：`gh issue edit <n> --add-assignee @me`（本会话的第一次写操作）。
- **解决**：`gh issue comment <n> --body "<答案>"` → `gh issue close <n>` → 把上下文指针（gist + 链接）追加到 map 的 Decisions-so-far。
