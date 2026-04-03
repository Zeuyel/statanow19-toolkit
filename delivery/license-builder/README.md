# StataNow 19 License Builder

主入口：`statanow19-license-builder.sh`

特性：
- 无参数运行时进入交互式 shell 提示流程
- 保留 `--preset` / `--field6` / `--output` / `--format` 等非交互参数，方便 CI 或脚本调用
- 运行时不依赖 Python

示例：

```bash
./statanow19-license-builder.sh
./statanow19-license-builder.sh --non-interactive --preset mp64 --output ~/.config/statanow19-runtime/stata.lic
./statanow19-license-builder.sh --non-interactive --preset be --field6 01012050 --format license-only
```

已验证工作族默认值：
- `field1=999`
- `field2=24`
- `field3=5`
- `field4=9999`
- `field5=h`
- `field6=01012050`
- `field7=64`

注意：`field6` 不能为空，年份上界当前验证为 `2050`。
