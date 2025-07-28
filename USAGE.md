# PDF MCP服务器使用指南

## 快速开始

### 环境配置

1. **复制环境变量示例文件:**
```bash
cp .env.example .env
```

2. **配置环境变量:**
编辑 `.env` 文件，根据需要修改配置：

```bash
# 服务器配置
MCP_PORT=8000                    # MCP服务器端口
MCP_HOST=127.0.0.1              # MCP服务器主机地址

# 日志配置
LOG_LEVEL=INFO                   # 日志级别 (DEBUG, INFO, WARNING, ERROR)

# PDF处理配置
MAX_FILE_SIZE_MB=100             # 最大文件大小限制 (MB)
MAX_PAGES_PER_PDF=1000           # 单个PDF最大页数限制

# 图像输出配置
DEFAULT_DPI=150                  # 默认图像DPI
DEFAULT_IMAGE_FORMAT=PNG         # 默认图像格式 (PNG, JPEG)
```

### 1. 安装依赖

```bash
# 安装Python依赖
pip install -r requirements.txt
```

### 2. 启动服务器

#### 标准模式 (stdio)
```bash
# 使用启动脚本
./start_server.sh

# 或直接运行
python src/pdf_mcp_server.py
```

#### SSE模式 (Server-Sent Events)
```bash
# 使用SSE启动脚本
./start_server_sse.sh

# 或直接运行
python src/pdf_mcp_server.py --sse
```

**SSE模式特点:**
- 运行在HTTP服务器上（端口由 `MCP_PORT` 环境变量配置）
- 支持Server-Sent Events协议
- 可通过HTTP接口访问
- 适合Web应用集成

### 3. 测试功能

```bash
# 运行测试脚本（需要test.pdf文件）
python test_server.py
```

## MCP工具详细说明

### pdf_to_images

将PDF文件转换为图片并返回指定页面的base64编码。

**参数:**
- `pdf_path` (string): PDF文件的完整路径
- `page_number` (int, 可选): 要转换的页码，从1开始，默认为1
- `dpi` (int, 可选): 图片分辨率，默认为200

**返回值:**
```json
{
  "pdf_name": "文件名.pdf",
  "total_pages": 10,
  "current_page": 1,
  "has_next_page": true,
  "image_base64": "iVBORw0KGgoAAAANSUhEUgAA..."
}
```

**使用示例:**
```python
# 转换第1页，使用默认分辨率
result = pdf_to_images("/path/to/document.pdf")

# 转换第3页，使用高分辨率
result = pdf_to_images("/path/to/document.pdf", page_number=3, dpi=300)
```

### extract_pdf_content

使用markitdown库提取PDF的全部文本内容。

**参数:**
- `pdf_path` (string): PDF文件的完整路径

**返回值:**
```json
{
  "content": "PDF的文本内容...",
  "metadata": {
    "title": "文档标题",
    "author": "作者",
    "subject": "主题",
    "creator": "创建者",
    "producer": "生成器",
    "creation_date": "创建日期",
    "modification_date": "修改日期",
    "total_pages": 10,
    "file_name": "document.pdf",
    "file_size": 1024000
  }
}
```

**使用示例:**
```python
result = extract_pdf_content("/path/to/document.pdf")
print(result["content"])  # 打印文本内容
print(result["metadata"]["total_pages"])  # 打印总页数
```

### get_pdf_info

获取PDF文件的基本信息和元数据。

**参数:**
- `pdf_path` (string): PDF文件的完整路径

**返回值:**
```json
{
  "file_name": "document.pdf",
  "file_size": 1024000,
  "total_pages": 10,
  "title": "文档标题",
  "author": "作者",
  "creation_date": "D:20231201120000+00'00'",
  "modification_date": "D:20231201120000+00'00'"
}
```



## 错误处理

所有工具都包含错误处理机制：

- **文件不存在**: 返回包含错误信息的结果
- **页码超出范围**: 返回错误信息和有效范围
- **文件格式错误**: 返回格式错误信息
- **权限问题**: 返回权限错误信息

## 性能优化建议

1. **图片分辨率**: 根据需要调整DPI，高分辨率会增加处理时间和内存使用
2. **大文件处理**: 对于大型PDF文件，建议分页处理而不是一次性提取所有内容
3. **缓存**: 考虑实现结果缓存以提高重复请求的性能

## 故障排除

### 常见问题

1. **ImportError: No module named 'fitz'**
   ```bash
   pip install PyMuPDF
   ```

2. **ImportError: No module named 'markitdown'**
   ```bash
   pip install markitdown
   ```

3. **权限错误**
   - 确保PDF文件有读取权限
   - 确保Python进程有访问文件的权限

4. **内存不足**
   - 降低DPI设置
   - 分批处理大文件

### 调试模式

在开发环境中，可以启用详细的错误日志：

```python
import logging
logging.basicConfig(level=logging.DEBUG)
```

## 扩展功能

可以考虑添加的功能：

1. **批量处理**: 一次处理多个PDF文件
2. **OCR支持**: 对扫描版PDF进行文字识别
3. **格式转换**: 支持更多输出格式（JPEG、TIFF等）
4. **水印添加**: 为生成的图片添加水印
5. **页面范围**: 支持指定页面范围进行批量转换