#!/usr/bin/env python3
"""
整合本地词库文件并转换为 Rime dict.yaml 和 SQLite
需要安装: pip install pypinyin
"""

import os
import sys
import subprocess
from pathlib import Path
from pypinyin import lazy_pinyin, Style

def get_desktop_path():
    """获取桌面路径"""
    home = Path.home()
    desktop = home / "Desktop"
    if not desktop.exists():
        desktop = home / "桌面"
    return desktop

def word_to_pinyin(word):
    """将中文词转换为拼音（不带声调，小写）"""
    try:
        pinyin_list = lazy_pinyin(word, style=Style.NORMAL)
        return ''.join(pinyin_list).lower()
    except Exception:
        return ""

def parse_dict_file(file_path):
    """解析词库文件（支持多种格式）"""
    words = {}
    print(f"  正在解析: {file_path.name}")
    
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            line_count = 0
            for line in f:
                line = line.strip()
                if not line or line.startswith('#'):
                    continue
                
                # 尝试多种分隔符：Tab、空格、逗号
                parts = None
                if '\t' in line:
                    parts = line.split('\t')
                elif ' ' in line and len(line.split()) >= 2:
                    parts = line.split()
                elif ',' in line:
                    parts = line.split(',')
                
                if not parts or len(parts) < 2:
                    continue
                
                word = parts[0].strip()
                if not word:
                    continue
                
                # 尝试解析权重/DF值
                try:
                    weight = int(parts[1].strip())
                except (ValueError, IndexError):
                    weight = 0
                
                # 合并相同词条，取最大权重
                if word in words:
                    words[word] = max(words[word], weight)
                else:
                    words[word] = weight
                
                line_count += 1
                if line_count % 10000 == 0:
                    print(f"    已读取 {line_count} 行...", end='\r')
        
        print(f"    ✓ 解析完成: {len(words)} 个词条")
        return words
    except Exception as e:
        print(f"    ✗ 解析失败: {e}")
        return {}

def main():
    print("=" * 60)
    print("本地词库整合工具")
    print("=" * 60)
    
    # 获取桌面路径和词库文件夹
    desktop = get_desktop_path()
    cihui_dir = desktop / "cihui"
    
    if not cihui_dir.exists():
        print(f"\n✗ 错误: 找不到词库文件夹: {cihui_dir}")
        print("请确保桌面上有 'cihui' 文件夹")
        sys.exit(1)
    
    print(f"\n词库文件夹: {cihui_dir}")
    
    # 查找所有词库文件
    dict_files = []
    for ext in ['*.txt', '*.dict', '*.yaml', '*.yml']:
        dict_files.extend(list(cihui_dir.glob(ext)))
        dict_files.extend(list(cihui_dir.rglob(ext)))  # 递归查找子文件夹
    
    if not dict_files:
        print("\n✗ 错误: 在词库文件夹中未找到任何词库文件")
        print("支持的文件格式: .txt, .dict, .yaml, .yml")
        sys.exit(1)
    
    print(f"\n找到 {len(dict_files)} 个词库文件:")
    for f in dict_files:
        print(f"  - {f.name}")
    
    # 整合所有词库
    print("\n" + "=" * 60)
    print("开始整合词库...")
    print("=" * 60)
    
    all_words = {}
    total_files = len(dict_files)
    
    for idx, dict_file in enumerate(dict_files, 1):
        print(f"\n[{idx}/{total_files}] {dict_file.name}")
        print("-" * 60)
        
        words = parse_dict_file(dict_file)
        for word, weight in words.items():
            if word in all_words:
                all_words[word] = max(all_words[word], weight)
            else:
                all_words[word] = weight
    
    print("\n" + "=" * 60)
    print(f"总共收集到 {len(all_words)} 个唯一词条")
    print("=" * 60)
    
    # 生成拼音并转换为 Rime 格式
    print("\n正在生成拼音并转换为 Rime 格式...")
    print("-" * 60)
    
    entries = []
    total = 0
    failed_pinyin = 0
    
    for word, weight in all_words.items():
        pinyin = word_to_pinyin(word)
        if not pinyin:
            failed_pinyin += 1
            continue
        
        entries.append((word, pinyin, weight))
        total += 1
        
        if total % 5000 == 0:
            print(f"  已处理 {total}/{len(all_words)} 条... (失败: {failed_pinyin})", end='\r')
    
    print(f"\n  处理完成: {total} 条有效词条 (跳过 {failed_pinyin} 条)")
    
    # 按权重降序排序
    print("\n正在按权重排序...")
    entries.sort(key=lambda x: x[2], reverse=True)
    
    # 生成 yaml 文件
    output_yaml = desktop / "rime_lexicon.yaml"
    print(f"\n正在写入 YAML 文件: {output_yaml}")
    print("-" * 60)
    
    with open(output_yaml, 'w', encoding='utf-8') as f:
        f.write("---\n")
        f.write("name: merged_lexicon\n")
        f.write("version: \"1.0\"\n")
        f.write("sort: by_weight\n")
        f.write("...\n\n")
        
        for word, pinyin, weight in entries:
            f.write(f"{word}\t{pinyin}\t{weight}\n")
    
    yaml_size = output_yaml.stat().st_size / 1024 / 1024
    print(f"✓ YAML 文件生成完成: {len(entries)} 条词条, {yaml_size:.2f} MB")
    
    # 转换为 SQLite
    print("\n" + "=" * 60)
    print("开始转换为 SQLite...")
    print("=" * 60)
    
    project_root = Path(__file__).parent.parent
    convert_script = project_root / "Tools" / "convert_rime_dict.swift"
    output_sqlite = project_root / "WTRimeKeyboard" / "Resources" / "rime_lexicon.sqlite"
    
    # 确保输出目录存在
    output_sqlite.parent.mkdir(parents=True, exist_ok=True)
    
    print(f"\n转换脚本: {convert_script}")
    print(f"输入文件: {output_yaml}")
    print(f"输出文件: {output_sqlite}")
    print("-" * 60)
    
    try:
        # 调用 Swift 转换脚本
        result = subprocess.run(
            ["swift", str(convert_script), str(output_yaml), str(output_sqlite)],
            capture_output=True,
            text=True,
            check=True
        )
        
        print(result.stdout)
        if result.stderr:
            print("警告:", result.stderr)
        
        if output_sqlite.exists():
            sqlite_size = output_sqlite.stat().st_size / 1024 / 1024
            print(f"\n✓ SQLite 文件生成成功: {sqlite_size:.2f} MB")
            print(f"✓ 文件位置: {output_sqlite}")
        else:
            print("\n✗ SQLite 文件未生成")
            sys.exit(1)
            
    except subprocess.CalledProcessError as e:
        print(f"\n✗ 转换失败:")
        print(e.stdout)
        print(e.stderr)
        sys.exit(1)
    except FileNotFoundError:
        print(f"\n✗ 错误: 找不到 Swift 转换脚本: {convert_script}")
        print("请确保 convert_rime_dict.swift 文件存在")
        sys.exit(1)
    
    print("\n" + "=" * 60)
    print("✓ 全部完成！")
    print("=" * 60)
    print(f"\n生成的文件:")
    print(f"  - YAML: {output_yaml}")
    print(f"  - SQLite: {output_sqlite}")
    print(f"\n现在可以在键盘中使用 SQLite 词库了！")

if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("\n\n用户中断操作")
        sys.exit(1)
    except Exception as e:
        print(f"\n\n发生错误: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)
