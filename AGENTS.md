# 项目约定

## 网络缓存

- `mpv.conf` 中的网络缓存策略是有意为之：目标环境网络较差、主机性能较高。
- 保持 `demuxer-max-bytes=2048MiB`、`demuxer-max-back-bytes=256MiB` 和 `cache-pause=no`；除非用户明确要求，不建议降低缓存或启用缓冲暂停。

## Git 同步

- 每次修改本项目的配置后，完成验证、提交并推送到 GitHub 的 `origin` 远程仓库。
