#!/usr/bin/env python3
"""
下载 THUOCL 词库并转换为 Rime dict.yaml 格式
需要安装: pip install pypinyin requests
"""

import os
import sys
import time
import requests
import shutil
from pathlib import Path
from pypinyin import lazy_pinyin, Style

# THUOCL 词库下载链接（GitHub raw 链接）
THUOCL_BASE_URL = "https://raw.githubusercontent.com/thunlp/THUOCL/master/data"
DICTIONARIES = [
    ("IT", "THUOCL_it.txt"),
    ("财经", "THUOCL_caijing.txt"),
    ("成语", "THUOCL_chengyu.txt"),
    ("地名", "THUOCL_diming.txt"),
    ("历史名人", "THUOCL_lishimingren.txt"),
    ("诗词", "THUOCL_shici.txt"),
    ("医学", "THUOCL_yixue.txt"),
    ("饮食", "THUOCL_yinshi.txt"),
    ("法律", "THUOCL_falv.txt"),
    ("汽车", "THUOCL_qiche.txt"),
    ("动物", "THUOCL_dongwu.txt"),
]

def get_desktop_path():
    """获取桌面路径"""
    home = Path.home()
    desktop = home / "Desktop"
    if not desktop.exists():
        # 如果 Desktop 不存在，尝试中文名称
        desktop = home / "桌面"
    if not desktop.exists():
        # 如果都不存在，使用当前目录
        desktop = Path.cwd()
    return desktop

def download_file_with_retry(url, output_path, retry_delay=3):
    """下载文件，失败时无限重试"""
    attempt = 0
    while True:
        attempt += 1
        if attempt > 1:
            print(f"  重试第 {attempt - 1} 次...")
            time.sleep(retry_delay)
        
        try:
            print(f"正在下载: {os.path.basename(output_path)}")
            response = requests.get(url, timeout=60, stream=True)
            response.raise_for_status()
            
            # 获取文件大小
            total_size = int(response.headers.get('content-length', 0))
            downloaded = 0
            
            with open(output_path, 'wb') as f:
                for chunk in response.iter_content(chunk_size=8192):
                    if chunk:
                        f.write(chunk)
                        downloaded += len(chunk)
                        if total_size > 0:
                            percent = (downloaded / total_size) * 100
                            print(f"\r  进度: {percent:.1f}% ({downloaded}/{total_size} bytes)", end='', flush=True)
            
            print(f"\n✓ 下载成功: {os.path.basename(output_path)}")
            return True
        except requests.exceptions.RequestException as e:
            print(f"\n✗ 下载失败: {e}")
        except Exception as e:
            print(f"\n✗ 发生错误: {e}")

def word_to_pinyin(word):
    """将中文词转换为拼音（不带声调，小写）"""
    try:
        pinyin_list = lazy_pinyin(word, style=Style.NORMAL)
        return ''.join(pinyin_list).lower()
    except Exception:
        # 如果转换失败，返回空字符串
        return ""

def main():
    print("=" * 60)
    print("THUOCL 词库下载与转换工具")
    print("=" * 60)
    
    # 获取桌面路径
    desktop = get_desktop_path()
    output_yaml = desktop / "rime_lexicon.yaml"
    
    print(f"\n输出文件将保存到: {output_yaml}")
    print(f"开始下载 {len(DICTIONARIES)} 个词库...\n")
    
    # 创建临时目录
    temp_dir = Path("/tmp/thuocl_download")
    temp_dir.mkdir(exist_ok=True)
    
    # 下载所有词库
    all_words = {}
    downloaded_count = 0
    
    for name, filename in DICTIONARIES:
        url = f"{THUOCL_BASE_URL}/{filename}"
        local_file = temp_dir / filename
        
        print(f"\n[{downloaded_count + 1}/{len(DICTIONARIES)}] 处理词库: {name}")
        print("-" * 60)
        
        # 无限重试下载
        download_file_with_retry(url, str(local_file))
        
        # 读取并合并词条
        if local_file.exists():
            print(f"正在解析 {name}...")
            word_count = 0
            with open(local_file, 'r', encoding='utf-8') as f:
                for line in f:
                    line = line.strip()
                    if not line:
                        continue
                    
                    parts = line.split('\t')
                    if len(parts) < 2:
                        continue
                    
                    word = parts[0].strip()
                    try:
                        df_value = int(parts[1].strip())
                    except ValueError:
                        continue
                    
                    if not word:
                        continue
                    
                    # 合并相同词条，取最大DF值
                    if word in all_words:
                        all_words[word] = max(all_words[word], df_value)
                    else:
                        all_words[word] = df_value
                    
                    word_count += 1
            
            print(f"✓ {name}: {word_count} 条词条")
            downloaded_count += 1
        else:
            print(f"✗ {name}: 文件不存在，跳过")
    
    print(f"\n" + "=" * 60)
    print(f"总共收集到 {len(all_words)} 个唯一词条")
    print("=" * 60)
    
    # 转换为 Rime 格式
    print("\n正在生成拼音并转换为 Rime 格式...")
    print("-" * 60)
    entries = []
    total = 0
    failed_pinyin = 0
    
    for word, df_value in all_words.items():
        pinyin = word_to_pinyin(word)
        if not pinyin:
            failed_pinyin += 1
            continue
        
        entries.append((word, pinyin, df_value))
        total += 1
        
        if total % 5000 == 0:
            print(f"  已处理 {total}/{len(all_words)} 条... (失败: {failed_pinyin})")
    
    if failed_pinyin > 0:
        print(f"  警告: {failed_pinyin} 个词条无法生成拼音，已跳过")
    
    # 按权重降序排序
    print("\n正在按权重排序...")
    entries.sort(key=lambda x: x[2], reverse=True)
    
    # 写入 Rime dict.yaml 格式
    print(f"\n正在写入 {output_yaml}...")
    print("-" * 60)
    
    with open(output_yaml, 'w', encoding='utf-8') as f:
        f.write("---\n")
        f.write("name: thuocl_combined\n")
        f.write("version: \"1.0\"\n")
        f.write("sort: by_weight\n")
        f.write("...\n\n")
        
        for word, pinyin, weight in entries:
            f.write(f"{word}\t{pinyin}\t{weight}\n")
    
    print("=" * 60)
    print(f"✓ 完成！共生成 {len(entries)} 条词条")
    print(f"✓ 输出文件: {output_yaml}")
    print(f"✓ 文件大小: {output_yaml.stat().st_size / 1024 / 1024:.2f} MB")
    print("=" * 60)
    
    # 清理临时文件
    print("\n正在清理临时文件...")
    try:
        shutil.rmtree(temp_dir, ignore_errors=True)
        print("✓ 临时文件已清理")
    except Exception as e:
        print(f"⚠ 清理临时文件时出错: {e}")
    
    print("\n下一步：")
    print(f"  swift Tools/convert_rime_dict.swift \"{output_yaml}\" WTRimeKeyboard/Resources/rime_lexicon.sqlite")

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
