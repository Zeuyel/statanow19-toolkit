# StataNow 19 License Builder

入口：`statanow19-license-builder.py`

示例：

```bash
python3 statanow19-license-builder.py --preset mp64
python3 statanow19-license-builder.py --preset be --field6 03272026 --output ~/.config/statanow19-runtime/stata.lic
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
