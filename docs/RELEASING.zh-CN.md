# 发布流程

[English](RELEASING.md) | 简体中文

本文把 v0.4.0 实际执行过的 Release 流程固化成可复现的维护者 Checklist。

## 1. Release 源码必须一致

Tag 前确认：

- Working Tree 只包含预期 Release 修改；
- Plugin Version 与公开文档一致；
- `CHANGELOG` 已包含该版本；
- `README` 只描述已经发布的行为；
- `PROGRESS` 不存在该版本的过时 Blocker/WIP 描述；
- `DEVELOPMENT_<version>` 已准备关闭。

## 2. 必须执行验证

根据修改范围运行对应测试。完整 Addon Release 的 v0.4.0 基线包括：

```text
Godot addon load/compile
npm build
npm test
catalogue/schema gate
production plugin smoke
Credential 代码变化时跑 Credential 生命周期
Runtime 生命周期变化时跑 Runtime Autoload 生命周期
Installer/Package 变化时跑 Installer Smoke
文档 Link/BOM/Format
Secret Scan
```

面向公开 Capability Release 时，在条件允许的情况下做真实 ChatGPT Connector 回归。

**没有真实执行的 Gate 不能写 PASS。**

## 3. 仓库卫生

确认：

- 暂存区没有 `.local-test/`、`.mcp-smoke/`、`.mcp-real-test/`、`dist/`、Payload 临时文件或秘密；
- `git diff --check` 通过；
- UTF-8 BOM 规则通过；
- 文档链接有效；
- 生成产物不会误进源码 Commit。

## 4. 先 Commit / Push 源码

Release 产物必须从最终 Tag 对应的精确源码 Commit 构建。

推荐顺序：

```text
验证
→ commit
→ push
→ 确认 local/origin 对齐
→ 从该精确 commit 构建产物
```

## 5. 构建 Release 产物

Windows Installer Release：

```powershell
powershell -ExecutionPolicy Bypass -File tools/installer/build.ps1
```

预期：

```text
godot-mcp-chatgpt-v<version>-windows-x64-installer.exe
godot-mcp-chatgpt-v<version>-addon.zip
SHA256SUMS.txt
```

## 6. 重新测试构建产物

源码测试通过不等于 Installer 一定正确。

至少验证：

- 干净安装；
- 升级；
- 非法项目拒绝；
- 中文/空格路径；
- Godot 真正加载安装后的 Addon；
- 内嵌/发布 Addon 文件集合与源码一致；
- SHA-256 清单与实际产物一致。

## 7. 发布 GitHub Release

Version Tag 必须指向已经完整验证的 Release Commit。

上传：

- Installer EXE；
- Addon ZIP；
- SHA-256 清单。

不要把已经公开的 Release Tag 移到后续纯文档 Commit。

## 8. 验证线上资产

发布后：

1. 重新读取 GitHub Release Metadata；
2. 确认 Tag Target；
3. 把线上资产重新下载；
4. 与本地已验证产物比较 Hash。

只有 Remote Asset 完全一致，Release 才算真正验证完成。

## 9. 收口文档状态

发布成功后：

- 把版本记录标记为 Complete/Released；
- `PROGRESS` 只保留当前状态；
- 历史流水影响可读性时迁入 Archive；
- 后续候选工作写进 `DEVELOPMENT_PLAN`。

Tag 之后允许补一个纯文档 Commit，但 Release Tag 必须继续指向精确验证过的源码 Commit。