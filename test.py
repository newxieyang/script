def version_to_tuple(version):
    """将版本号字符串转换为整数元组，以便比较"""
    return tuple(int(x) for x in version.split('.'))

def find_closest_version(versions, target):
    """找出数组中与目标版本号数值上最接近的字符串"""
    target_tuple = version_to_tuple(target)
    min_diff = float('inf')
    closest_version = None
    differences = []  # 存储所有版本号的差异以便调试
    
    # 比较目标版本号与数组中每个版本号
    for version in versions:
        version_tuple = version_to_tuple(version)
        # 计算版本号的“距离”（逐段差的绝对值之和）
        diff = sum(abs(a - b) for a, b in zip(version_tuple, target_tuple))
        differences.append((version, diff))
        if diff < min_diff:
            min_diff = diff
            closest_version = version
    
    # 打印所有差异以便调试
    print("所有版本号与目标版本号的差异：")
    for version, diff in sorted(differences, key=lambda x: x[1]):
        print(f"版本号: {version}, 差值: {diff}")
    
    return closest_version, min_diff

# 输入的版本号数组和目标版本号
versions = ['1.0.51.66', '1.0.53.3', '1.0.58.27', '1.0.58.29', '1.0.58.33', 
            '1.0.58.36', '1.0.58.37', '1.0.59.1']
target = '1.0.53.47'

# 找出最接近的版本号
closest_version, diff = find_closest_version(versions, target)

print(f"\n目标版本号: {target}")
print(f"最接近的版本号: {closest_version}，差值: {diff}")