# 腾讯云COS客户端

这是一个简单易用的腾讯云对象存储（COS）Python客户端，支持文件上传并返回访问URL。

## 功能特性

- ✅ 支持文件上传到腾讯云COS
- ✅ 自动返回文件访问URL
- ✅ 支持自定义远程文件名
- ✅ 支持指定文件MIME类型
- ✅ 自动添加时间戳避免文件名冲突
- ✅ 完整的错误处理和日志记录
- ✅ 支持文件存在性检查

## 安装依赖

```bash
pip install cos-python-sdk-v5 python-dotenv
```

## 配置

1. 在项目根目录创建 `.env` 文件：

```env
# 腾讯云COS配置
SECRET_ID=你的SecretId
SECRET_KEY=你的SecretKey
REGION=ap-beijing
BUCKET_NAME=你的存储桶名称
```

2. 获取配置信息：
   - `SECRET_ID` 和 `SECRET_KEY`：在[腾讯云访问管理控制台](https://console.cloud.tencent.com/cam/capi)获取
   - `REGION`：存储桶所在地域，如 `ap-beijing`、`ap-shanghai` 等
   - `BUCKET_NAME`：存储桶名称，格式为 `BucketName-APPID`

## 基本使用

### 1. 简单上传文件

```python
from cos_client import COSClient

# 创建客户端
cos_client = COSClient()

# 上传文件
result = cos_client.upload_file('/path/to/your/file.txt')

if result['success']:
    print(f"上传成功！文件URL: {result['url']}")
    print(f"ETag: {result['etag']}")
    print(f"远程文件名: {result['key']}")
else:
    print(f"上传失败: {result['error']}")
```

### 2. 自定义文件名和类型

```python
result = cos_client.upload_file(
    local_file_path='/path/to/file.pdf',
    remote_key='documents/my_document.pdf',  # 自定义远程文件名
    content_type='application/pdf'           # 指定MIME类型
)
```

### 3. 批量上传

```python
files = ['/path/file1.txt', '/path/file2.jpg', '/path/file3.pdf']
urls = []

for file_path in files:
    result = cos_client.upload_file(file_path)
    if result['success']:
        urls.append(result['url'])
        print(f"✅ {file_path} -> {result['url']}")
    else:
        print(f"❌ {file_path} 上传失败: {result['error']}")
```

### 4. 检查文件是否存在

```python
# 检查文件是否存在
if cos_client.check_file_exists('my_file.txt'):
    print("文件存在")
    url = cos_client.get_file_url('my_file.txt')
    print(f"文件URL: {url}")
else:
    print("文件不存在")
```

## 返回值说明

上传成功时返回：
```python
{
    'success': True,
    'url': 'https://bucket-name.cos.region.myqcloud.com/file_name',
    'etag': '"文件的ETag值"',
    'key': '远程文件名'
}
```

上传失败时返回：
```python
{
    'success': False,
    'error': '错误信息描述'
}
```

## 测试

运行测试脚本验证配置和功能：

```bash
# 基本功能测试
python test_cos_client.py

# 使用示例
python cos_usage_example.py
```

## 注意事项

1. **安全性**：请不要将 `.env` 文件提交到版本控制系统
2. **权限**：确保你的腾讯云账号有COS的读写权限
3. **存储桶**：存储桶必须已经创建，客户端不会自动创建存储桶
4. **文件名**：上传的文件会自动添加时间戳前缀避免重名
5. **访问权限**：如果需要公开访问，请在COS控制台设置存储桶的访问权限

## 错误处理

客户端包含完整的错误处理机制：

- 文件不存在检查
- 网络连接错误处理
- COS服务错误处理
- 参数验证
- 详细的错误日志

## 示例文件

- `cos_client.py` - 主要的COS客户端类
- `test_cos_client.py` - 功能测试脚本
- `cos_usage_example.py` - 使用示例脚本

## 支持的文件类型

支持所有类型的文件上传，包括但不限于：
- 文档：PDF、DOC、TXT、MD等
- 图片：JPG、PNG、GIF、SVG等
- 视频：MP4、AVI、MOV等
- 压缩包：ZIP、RAR、TAR等
- 其他任意格式的文件

---

🎉 现在你可以轻松地将文件上传到腾讯云COS并获取访问URL了！