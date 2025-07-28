# PDF MCP Server

基于Python FastMCP框架构建的PDF处理MCP服务器。

## 功能特性

1. **PDF转图片**: 将PDF文件分割为图片，上传到腾讯云COS并返回指定页面的图片URL
2. **PDF内容提取**: 使用markitdown读取PDF全部文本内容

## 快速开始

### 环境配置

1. 复制环境变量示例文件：
```bash
cp .env.example .env
```

2. 根据需要修改 `.env` 文件中的配置：
```bash
# 服务器配置
MCP_PORT=8000
MCP_HOST=127.0.0.1

# 日志级别
LOG_LEVEL=INFO

# PDF处理配置
MAX_FILE_SIZE_MB=100
MAX_PAGES_PER_PDF=1000

# 图像输出配置
DEFAULT_DPI=150
DEFAULT_IMAGE_FORMAT=PNG

# 腾讯云COS配置（PDF转图片功能必需）
SECRET_ID=your_secret_id_here
SECRET_KEY=your_secret_key_here
REGION=ap-beijing
BUCKET_NAME=your_bucket_name_here
```

### 安装依赖

```bash
pip install -r requirements.txt
```

### 腾讯云COS配置

PDF转图片功能需要腾讯云COS服务支持，请按以下步骤配置：

1. 登录[腾讯云控制台](https://console.cloud.tencent.com/)
2. 开通对象存储COS服务
3. 创建存储桶（Bucket）
4. 获取API密钥：
   - 访问[API密钥管理](https://console.cloud.tencent.com/cam/capi)
   - 创建密钥，获取SecretId和SecretKey
5. 在`.env`文件中配置相关参数

**注意**: 请确保COS存储桶具有公共读权限，以便生成的图片URL可以被访问。

### 运行服务

**使用管理脚本（推荐）:**

**Linux/macOS:**
```bash
# 启动服务器（SSE模式）
./manage_server.sh start

# 查看服务状态
./manage_server.sh status

# 查看日志
./manage_server.sh logs

# 停止服务器
./manage_server.sh stop

# 重启服务器
./manage_server.sh restart
```

**Windows:**
```cmd
# 启动服务器（SSE模式）
manage_server.bat start

# 查看服务状态
manage_server.bat status

# 查看日志
manage_server.bat logs

# 停止服务器
manage_server.bat stop

# 重启服务器
manage_server.bat restart
```

**直接运行:**
```bash
# 标准模式 (stdio)
python3 src/pdf_mcp_server.py

# SSE模式 (Server-Sent Events)
python3 src/pdf_mcp_server.py --sse
```

**说明:**
- 管理脚本默认以SSE模式启动服务器，支持HTTP接口访问
- SSE模式运行在HTTP服务器上，端口由环境变量 `MCP_PORT` 配置（默认8000）
- 管理脚本提供完整的服务生命周期管理，包括进程监控、日志管理等功能
- 服务器日志保存在 `server.log` 文件中

## MCP工具

### pdf_to_images
将PDF转换为图片并上传到腾讯云COS，返回指定页面的图片URL

参数:
- `pdf_path`: PDF文件路径
- `page_number`: 页码（从1开始）
- `dpi`: 图片分辨率（默认200）

返回:
```json
{
  "pdf_name": "文件名",
  "total_pages": 总页数,
  "current_page": 当前页码,
  "has_next_page": 是否有下一页,
  "image_url": "上传到COS的图片URL"
}
```

### extract_pdf_content
提取PDF文本内容

参数:
- `pdf_path`: PDF文件路径

返回:
```json
{
  "content": "PDF文本内容",
  "metadata": "文档元数据"
}
```