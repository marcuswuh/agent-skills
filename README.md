# agent-skills

个人 Cursor Agent Skills 集合，用于统一研发工作流与项目熟悉流程。

## 包含的 Skills

| Skill | 用途 |
|-------|------|
| `dev-workflow` | 四步研发工作流：需求确认 → 方案设计 → 方案评审 → 代码落地 |
| `project-onboarding` | C++/Python 项目熟悉 8 步流程，产出带引用链接的《项目熟悉文档》 |

## 目录结构

```
agent-skills/
├── .cursor/skills/
│   ├── dev-workflow/SKILL.md
│   └── project-onboarding/SKILL.md
├── install.sh
└── README.md
```

## 使用方式

### 方式 1：安装到本机全局（`~/.cursor/skills/`）

```bash
./install.sh
```

适用于本机所有项目自动发现 Skill。

### 方式 2：复制到其他项目的 `.cursor/skills/`

```bash
cp -R .cursor/skills/* /path/to/your-project/.cursor/skills/
```

适用于 Remote SSH（全局 `~/.cursor/skills/` 在 SSH 模式下不可靠）。

### 方式 3：Git submodule

```bash
git submodule add <this-repo-url> .cursor/skills-shared
# 再按需 symlink 或 copy 到 .cursor/skills/
```

## User Rules 建议（可选）

在 Cursor Settings → Rules 中添加短触发器，正文以 Skill 为准：

**dev-workflow**
```
当用户要求编写方案、设计文档，或实现新功能/较大改动时：
必须先读取并严格遵循 .cursor/skills/dev-workflow/SKILL.md（或 ~/.cursor/skills/dev-workflow/SKILL.md），按其四步流程执行，每步须等用户回复「确认」或「通过」后再进入下一步。
不触发：简单 bug 修复、代码解释、一般问答。
```

**project-onboarding**
```
当用户要求梳理/熟悉/分析某个 C++/Python 项目时：
必须先读取并严格遵循 .cursor/skills/project-onboarding/SKILL.md（或 ~/.cursor/skills/project-onboarding/SKILL.md），按其 8 步流程依次执行，遇歧义暂停提问。
```
