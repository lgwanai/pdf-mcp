#!/usr/bin/env python3
"""
PDF MCP Server
基于FastMCP框架的PDF处理服务器
"""

import asyncio
import io
import os
import sys
import tempfile
from pathlib import Path
from typing import Any, Dict, Optional

import fitz  # PyMuPDF
from fastmcp import FastMCP
from markitdown import MarkItDown
from PIL import Image
from dotenv import load_dotenv

# 添加当前目录到sys.path以便导入cos_client
sys.path.append(os.path.dirname(os.path.abspath(__file__)))
from cos_client import COSClient

# 加载环境变量
load_dotenv()

# 配置类
class Config:
    def __init__(self):
        self.mcp_port = int(os.getenv('MCP_PORT', 8000))
        self.mcp_host = os.getenv('MCP_HOST', '127.0.0.1')
        self.log_level = os.getenv('LOG_LEVEL', 'INFO')
        self.max_file_size_mb = int(os.getenv('MAX_FILE_SIZE_MB', 100))
        self.max_pages_per_pdf = int(os.getenv('MAX_PAGES_PER_PDF', 1000))
        self.default_dpi = int(os.getenv('DEFAULT_DPI', 150))
        self.default_image_format = os.getenv('DEFAULT_IMAGE_FORMAT', 'PNG')

# 创建配置实例
config = Config()

# 创建FastMCP实例
mcp = FastMCP("PDF MCP Server", port=config.mcp_port)


@mcp.tool()
def pdf_to_images(
    pdf_path: str,
    page_number: int = 1,
    dpi: int = 200
) -> Dict[str, Any]:
    """
    将PDF转换为图片并上传到COS，返回指定页面的图片URL
    
    Args:
        pdf_path: PDF文件路径
        page_number: 页码（从1开始）
        dpi: 图片分辨率，默认200
    
    Returns:
        包含PDF信息和图片URL的字典
    """
    temp_image_path = None
    try:
        # 检查文件是否存在
        if not os.path.exists(pdf_path):
            raise FileNotFoundError(f"PDF文件不存在: {pdf_path}")
        
        # 打开PDF文档
        pdf_document = fitz.open(pdf_path)
        total_pages = len(pdf_document)
        
        # 验证页码
        if page_number < 1 or page_number > total_pages:
            raise ValueError(f"页码超出范围: {page_number}，总页数: {total_pages}")
        
        # 获取指定页面（PyMuPDF使用0基索引）
        page = pdf_document.load_page(page_number - 1)
        
        # 设置渲染矩阵（控制分辨率）
        zoom = dpi / 72.0  # 72是PDF的默认DPI
        mat = fitz.Matrix(zoom, zoom)
        
        # 渲染页面为图片
        pix = page.get_pixmap(matrix=mat)
        
        # 转换为PIL Image并保存到临时文件
        img_data = pix.tobytes("png")
        img = Image.open(io.BytesIO(img_data))
        
        # 创建临时文件
        pdf_name = Path(pdf_path).stem
        # 替换文件名中的空格和特殊字符，避免上传到COS时出现问题
        import re
        # 保留字母、数字、中文字符、下划线和连字符，其他字符替换为下划线
        safe_pdf_name = re.sub(r'[^\w\u4e00-\u9fff-]', '_', pdf_name)
        # 去除连续的下划线
        safe_pdf_name = re.sub(r'_+', '_', safe_pdf_name)
        # 去除开头和结尾的下划线
        safe_pdf_name = safe_pdf_name.strip('_')
        with tempfile.NamedTemporaryFile(suffix=f'_{safe_pdf_name}_page_{page_number}.png', delete=False) as temp_file:
            temp_image_path = temp_file.name
            img.save(temp_image_path, format='PNG')
        
        # 关闭文档
        pdf_document.close()
        
        # 上传到COS
        cos_client = COSClient()
        upload_result = cos_client.upload_file(
            local_file_path=temp_image_path,
            remote_key=f"pdf_images/{safe_pdf_name}_page_{page_number}.png",
            content_type='image/png'
        )
        
        if not upload_result['success']:
            raise Exception(f"上传图片到COS失败: {upload_result['error']}")
        
        # 返回结果
        return {
            "pdf_name": Path(pdf_path).name,
            "total_pages": total_pages,
            "current_page": page_number,
            "has_next_page": page_number < total_pages,
            "image_url": upload_result['url']
        }
        
    except Exception as e:
        return {
            "error": f"处理PDF时发生错误: {str(e)}",
            "pdf_name": Path(pdf_path).name if os.path.exists(pdf_path) else "未知",
            "total_pages": 0,
            "current_page": 0,
            "has_next_page": False,
            "image_url": ""
        }
    finally:
        # 清理临时文件
        if temp_image_path and os.path.exists(temp_image_path):
            try:
                os.unlink(temp_image_path)
            except:
                pass  # 忽略删除临时文件的错误


@mcp.tool()
def extract_pdf_content(pdf_path: str) -> Dict[str, Any]:
    """
    使用markitdown提取PDF文本内容
    
    Args:
        pdf_path: PDF文件路径
    
    Returns:
        包含PDF内容和元数据的字典
    """
    try:
        # 检查文件是否存在
        if not os.path.exists(pdf_path):
            raise FileNotFoundError(f"PDF文件不存在: {pdf_path}")
        
        # 使用markitdown提取内容
        markitdown = MarkItDown()
        result = markitdown.convert(pdf_path)
        
        # 获取PDF元数据
        pdf_document = fitz.open(pdf_path)
        metadata = pdf_document.metadata
        total_pages = len(pdf_document)
        pdf_document.close()
        
        return {
            "content": result.text_content,
            "metadata": {
                "title": metadata.get("title", ""),
                "author": metadata.get("author", ""),
                "subject": metadata.get("subject", ""),
                "creator": metadata.get("creator", ""),
                "producer": metadata.get("producer", ""),
                "creation_date": metadata.get("creationDate", ""),
                "modification_date": metadata.get("modDate", ""),
                "total_pages": total_pages,
                "file_name": Path(pdf_path).name,
                "file_size": os.path.getsize(pdf_path)
            }
        }
        
    except Exception as e:
        return {
            "error": f"提取PDF内容时发生错误: {str(e)}",
            "content": "",
            "metadata": {}
        }


@mcp.tool()
def get_pdf_info(pdf_path: str) -> Dict[str, Any]:
    """
    获取PDF基本信息
    
    Args:
        pdf_path: PDF文件路径
    
    Returns:
        PDF基本信息字典
    """
    try:
        if not os.path.exists(pdf_path):
            raise FileNotFoundError(f"PDF文件不存在: {pdf_path}")
        
        pdf_document = fitz.open(pdf_path)
        metadata = pdf_document.metadata
        total_pages = len(pdf_document)
        pdf_document.close()
        
        return {
            "file_name": Path(pdf_path).name,
            "file_size": os.path.getsize(pdf_path),
            "total_pages": total_pages,
            "title": metadata.get("title", ""),
            "author": metadata.get("author", ""),
            "creation_date": metadata.get("creationDate", ""),
            "modification_date": metadata.get("modDate", "")
        }
        
    except Exception as e:
        return {
            "error": f"获取PDF信息时发生错误: {str(e)}"
        }


if __name__ == "__main__":
    # 运行MCP服务器，使用SSE模式
    import sys
    
    # 检查命令行参数
    if len(sys.argv) > 1 and sys.argv[1] == "--sse":
        # SSE模式
        mcp.run(transport="sse")
    else:
        # 默认stdio模式
        mcp.run()