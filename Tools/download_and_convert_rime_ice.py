#!/usr/bin/env python3
"""
下载 rime-ice 词库并转换为项目可用的 SQLite 格式
需要安装: pip install requests
"""

import os
import sys
import subprocess
import shutil
import tempfile
from pathlib import Path
import requests
import zipfile

# rime-ice GitHub 仓库信息
RIME_ICE_REPO = "iDvel/rime-ice"
RIME_ICE_API = f"https://api.github.com/repos/{RIME_ICE_REPO}"

def get_latest_release_url():
    """获取最新 release 的下载 URL"""
    try:
        response = requests.get(f"{RIME_ICE_API}/releases/latest", timeout=10)
        if response.status_code == 200:
            data = response.json()
            # 查找 full.zip 或 source code zip
            for asset in data.get('assets', []):
                if 'full.zip' in asset.get('browser_download_url', ''):
                    return asset['browser_download_url']
            # 如果没有 full.zip，尝试 source code
            if 'zipball_url' in data:
                return data['zipball_url']
    except:
        pass
    return None

# 尝试多个可能的下载 URL
def get_download_urls():
    """获取所有可能的下载 URL（按优先级排序）"""
    urls = []
    
    # 1. 尝试最新 release
    release_url = get_latest_release_url()
    if release_url:
        urls.append(release_url)
    
    # 2. 尝试分支下载
    urls.extend([
        f"https://github.com/{RIME_ICE_REPO}/archive/refs/heads/main.zip",
        f"https://github.com/{RIME_ICE_REPO}/archive/refs/heads/master.zip",
        f"https://codeload.github.com/{RIME_ICE_REPO}/zip/refs/heads/main",
    ])
    
    return urls

def get_desktop_path():
    """获取桌面路径"""
    home = Path.home()
    desktop = home / "Desktop"
    if not desktop.exists():
        desktop = home / "桌面"
    return desktop

def download_file(url, dest_path, chunk_size=8192):
    """下载文件并显示进度"""
    print(f"正在下载: {url}")
    print(f"保存到: {dest_path}")
    
    try:
        response = requests.get(url, stream=True, timeout=30)
        response.raise_for_status()
    except requests.exceptions.RequestException as e:
        raise Exception(f"下载失败: {e}")
    
    total_size = int(response.headers.get('content-length', 0))
    downloaded = 0
    
    with open(dest_path, 'wb') as f:
        for chunk in response.iter_content(chunk_size=chunk_size):
            if chunk:
                f.write(chunk)
                downloaded += len(chunk)
                if total_size > 0:
                    percent = (downloaded / total_size) * 100
                    print(f"\r  进度: {percent:.1f}% ({downloaded / 1024 / 1024:.1f} MB / {total_size / 1024 / 1024:.1f} MB)", end='', flush=True)
    
    print()  # 换行
    print(f"✓ 下载完成")

def extract_zip(zip_path, extract_to):
    """解压 ZIP 文件"""
    print(f"\n正在解压: {zip_path.name}")
    with zipfile.ZipFile(zip_path, 'r') as zip_ref:
        zip_ref.extractall(extract_to)
    print("✓ 解压完成")

def find_dict_files(directory):
    """查找所有 dict.yaml 文件"""
    dict_files = []
    for pattern in ['**/*.dict.yaml', '**/*.dict.yml']:
        dict_files.extend(directory.glob(pattern))
    return dict_files

def parse_dict_yaml(file_path):
    """解析 Rime dict.yaml 文件，返回词条列表"""
    entries = []
    
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            content = f.read()
        
        # 检查是否包含 import_tables（引用其他词库）
        if 'import_tables:' in content:
            # 这是一个引用文件，需要解析引用的词库
            print(f"  注意: {file_path.name} 包含 import_tables，需要处理引用的词库")
            # 这里可以递归处理，但为了简化，我们主要处理实际的词库文件
        
        # 查找数据部分（在 ... 之后）
        lines = content.split('\n')
        reached_payload = False
        
        for line in lines:
            line = line.strip()
            
            if not reached_payload:
                if line == '...':
                    reached_payload = True
                continue
            
            if not line or line.startswith('#'):
                continue
            
            # 解析词条：格式为 "词\t拼音\t权重" 或 "词\t拼音"
            parts = line.split('\t')
            if len(parts) < 2:
                # 尝试空格分隔
                parts = line.split()
                if len(parts) < 2:
                    continue
            
            word = parts[0].strip()
            code = parts[1].strip()
            weight = int(parts[2].strip()) if len(parts) >= 3 else 0
            
            if word and code:
                entries.append((word, code, weight))
    
    except Exception as e:
        print(f"  警告: 解析 {file_path.name} 时出错: {e}")
    
    return entries

def merge_entries(all_entries):
    """合并词条，相同词条取最大权重"""
    merged = {}
    for word, code, weight in all_entries:
        key = (word, code)
        if key in merged:
            merged[key] = max(merged[key], weight)
        else:
            merged[key] = weight
    
    return [(word, code, weight) for (word, code), weight in merged.items()]

def main():
    print("=" * 60)
    print("rime-ice 词库下载与转换工具")
    print("=" * 60)
    
    # 检查是否提供了本地目录参数
    local_dir = None
    if len(sys.argv) > 1:
        local_dir = Path(sys.argv[1])
        if local_dir.exists() and local_dir.is_dir():
            print(f"\n使用本地目录: {local_dir}")
        else:
            print(f"\n✗ 错误: 指定的本地目录不存在: {local_dir}")
            sys.exit(1)
    
    # 创建临时目录
    temp_dir = Path(tempfile.mkdtemp(prefix="rime_ice_"))
    print(f"\n临时目录: {temp_dir}")
    
    try:
        if local_dir:
            # 使用本地目录
            extract_to = local_dir
            print(f"\n步骤 1: 使用本地目录")
            print("-" * 60)
            print(f"目录: {extract_to}")
        else:
            # 下载 rime-ice
            zip_path = temp_dir / "rime-ice.zip"
            print(f"\n步骤 1: 下载 rime-ice")
            print("-" * 60)
            
            # 尝试多个 URL
            download_success = False
            last_error = None
            download_urls = get_download_urls()
            
            for url in download_urls:
                try:
                    print(f"\n尝试 URL: {url}")
                    download_file(url, zip_path)
                    download_success = True
                    break
                except Exception as e:
                    last_error = e
                    print(f"  ✗ 失败: {e}")
                    if zip_path.exists():
                        zip_path.unlink()  # 删除部分下载的文件
                    continue
            
            if not download_success:
                print(f"\n✗ 所有下载 URL 都失败了")
                print(f"最后错误: {last_error}")
                print(f"\n提示: 您可以手动从以下地址下载 rime-ice:")
                print(f"  https://github.com/{RIME_ICE_REPO}")
                print(f"  下载后解压，然后运行:")
                print(f"  python3 {sys.argv[0]} <解压后的目录路径>")
                sys.exit(1)
            
            # 解压
            print(f"\n步骤 2: 解压文件")
            print("-" * 60)
            extract_to = temp_dir / "extracted"
            extract_to.mkdir(exist_ok=True)
            extract_zip(zip_path, extract_to)
        
        # 查找 rime-ice 目录
        print(f"\n查找 rime-ice 目录...")
        print(f"解压目录: {extract_to}")
        print(f"解压后的内容:")
        items = list(extract_to.iterdir())
        if not items:
            print("  (空目录)")
        else:
            for item in items:
                item_type = "目录" if item.is_dir() else "文件"
                print(f"  - {item.name} ({item_type})")
        
        rime_ice_dir = None
        
        # 策略1: 查找包含 'rime-ice' 或 'rime' 的目录
        for item in extract_to.iterdir():
            if item.is_dir():
                name_lower = item.name.lower()
                if 'rime-ice' in name_lower or ('rime' in name_lower and 'ice' in name_lower):
                    rime_ice_dir = item
                    print(f"\n找到目录 (策略1): {rime_ice_dir.name}")
                    break
        
        # 策略2: 如果只有一个子目录，直接使用它
        if not rime_ice_dir:
            dirs = [item for item in extract_to.iterdir() if item.is_dir()]
            if len(dirs) == 1:
                rime_ice_dir = dirs[0]
                print(f"\n找到目录 (策略2 - 唯一子目录): {rime_ice_dir.name}")
        
        # 策略3: 递归查找包含 dict.yaml 文件的目录
        if not rime_ice_dir:
            print(f"\n尝试策略3: 递归查找包含 dict.yaml 的目录...")
            for root, dirs, files in os.walk(extract_to):
                dict_files = [f for f in files if f.endswith('.dict.yaml') or f.endswith('.dict.yml')]
                if dict_files:
                    rime_ice_dir = Path(root)
                    print(f"找到目录 (策略3 - 包含 {len(dict_files)} 个 dict.yaml 文件): {rime_ice_dir.relative_to(extract_to)}")
                    break
        
        # 策略4: 如果 extract_to 本身包含 dict.yaml，直接使用 extract_to
        if not rime_ice_dir:
            dict_files_in_root = list(extract_to.glob('*.dict.yaml')) + list(extract_to.glob('*.dict.yml'))
            if dict_files_in_root:
                rime_ice_dir = extract_to
                print(f"找到目录 (策略4 - 根目录包含 dict.yaml): {extract_to}")
        
        if not rime_ice_dir:
            print("\n✗ 错误: 无法找到 rime-ice 目录")
            print("\n详细目录结构:")
            def print_tree(path, prefix="", max_depth=3, current_depth=0):
                if current_depth >= max_depth:
                    return
                try:
                    items = sorted(path.iterdir(), key=lambda x: (not x.is_dir(), x.name))
                    for i, item in enumerate(items):
                        is_last = i == len(items) - 1
                        current_prefix = "└── " if is_last else "├── "
                        print(f"{prefix}{current_prefix}{item.name}")
                        if item.is_dir() and current_depth < max_depth - 1:
                            next_prefix = prefix + ("    " if is_last else "│   ")
                            print_tree(item, next_prefix, max_depth, current_depth + 1)
                except PermissionError:
                    pass
            
            print_tree(extract_to)
            print(f"\n提示: 请检查解压后的目录结构")
            print(f"如果目录结构不同，您可以手动指定 rime-ice 目录路径")
            sys.exit(1)
        
        print(f"\n✓ 使用目录: {rime_ice_dir}")
        
        # 查找所有 dict.yaml 文件
        step_num = 3 if not local_dir else 2
        print(f"\n步骤 {step_num}: 查找词库文件")
        print("-" * 60)
        dict_files = find_dict_files(rime_ice_dir)
        
        if not dict_files:
            print("✗ 错误: 未找到任何 dict.yaml 文件")
            sys.exit(1)
        
        print(f"找到 {len(dict_files)} 个词库文件:")
        for f in dict_files[:10]:  # 只显示前10个
            print(f"  - {f.relative_to(rime_ice_dir)}")
        if len(dict_files) > 10:
            print(f"  ... 还有 {len(dict_files) - 10} 个文件")
        
        # 解析所有词库文件
        step_num = 4 if not local_dir else 3
        print(f"\n步骤 {step_num}: 解析词库文件")
        print("-" * 60)
        all_entries = []
        total_files = len(dict_files)
        
        for idx, dict_file in enumerate(dict_files, 1):
            print(f"[{idx}/{total_files}] {dict_file.name}", end=' ... ')
            entries = parse_dict_yaml(dict_file)
            all_entries.extend(entries)
            print(f"{len(entries)} 条词条")
        
        print(f"\n总共收集到 {len(all_entries)} 条词条")
        
        # 合并重复词条
        step_num = 5 if not local_dir else 4
        print(f"\n步骤 {step_num}: 合并重复词条")
        print("-" * 60)
        merged_entries = merge_entries(all_entries)
        print(f"合并后: {len(merged_entries)} 条唯一词条")
        
        # 按权重排序
        step_num = 6 if not local_dir else 5
        print(f"\n步骤 {step_num}: 按权重排序")
        print("-" * 60)
        merged_entries.sort(key=lambda x: x[2], reverse=True)
        print("✓ 排序完成")
        
        # 生成 YAML 文件
        desktop = get_desktop_path()
        output_yaml = desktop / "rime_ice_lexicon.yaml"
        
        step_num = 7 if not local_dir else 6
        print(f"\n步骤 {step_num}: 生成 YAML 文件")
        print("-" * 60)
        print(f"输出文件: {output_yaml}")
        
        with open(output_yaml, 'w', encoding='utf-8') as f:
            f.write("---\n")
            f.write("name: rime_ice_lexicon\n")
            f.write("version: \"1.0\"\n")
            f.write("sort: by_weight\n")
            f.write("...\n\n")
            
            for word, code, weight in merged_entries:
                f.write(f"{word}\t{code}\t{weight}\n")
        
        yaml_size = output_yaml.stat().st_size / 1024 / 1024
        print(f"✓ YAML 文件生成完成: {len(merged_entries)} 条词条, {yaml_size:.2f} MB")
        
        # 转换为 SQLite
        step_num = 8 if not local_dir else 7
        print(f"\n步骤 {step_num}: 转换为 SQLite")
        print("-" * 60)
        
        project_root = Path(__file__).parent.parent
        convert_script = project_root / "Tools" / "convert_rime_dict.swift"
        output_sqlite = project_root / "WTRimeKeyboard" / "Resources" / "rime_lexicon.sqlite"
        
        # 确保输出目录存在
        output_sqlite.parent.mkdir(parents=True, exist_ok=True)
        
        print(f"转换脚本: {convert_script.name}")
        print(f"输入文件: {output_yaml.name}")
        print(f"输出文件: {output_sqlite}")
        
        try:
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
        print(f"\n现在可以在键盘中使用 rime-ice 词库了！")
        print(f"\n注意: 请将 SQLite 文件添加到 Xcode 项目中，并确保在")
        print(f"AppGroupBootstrapper 中正确配置词库路径。")
        
    finally:
        # 清理临时文件
        print(f"\n清理临时文件...")
        if temp_dir.exists():
            shutil.rmtree(temp_dir)
        print("✓ 清理完成")

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
