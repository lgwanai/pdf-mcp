#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
腾讯云COS客户端
实现文件上传并返回访问URL的功能
"""

import os
import sys
import logging
from datetime import datetime
from dotenv import load_dotenv
from qcloud_cos import CosConfig
from qcloud_cos import CosS3Client
from qcloud_cos.cos_exception import CosServiceError, CosClientError

# 加载环境变量
load_dotenv()

class COSClient:
    """腾讯云COS客户端类"""
    
    def __init__(self, bucket_name=None):
        """
        初始化COS客户端
        
        Args:
            bucket_name (str): 存储桶名称，格式为 BucketName-APPID
        """
        # 从环境变量获取配置
        self.secret_id = os.getenv('SECRET_ID')
        self.secret_key = os.getenv('SECRET_KEY')
        self.region = os.getenv('REGION', 'ap-beijing')
        self.bucket_name = bucket_name or os.getenv('BUCKET_NAME')
        
        # 验证必要参数
        if not self.secret_id or not self.secret_key:
            raise ValueError("SECRET_ID 和 SECRET_KEY 必须在环境变量中设置")
        
        if not self.bucket_name:
            raise ValueError("BUCKET_NAME 必须在环境变量中设置或通过参数传入")
        
        # 初始化COS配置
        self.config = CosConfig(
            Region=self.region,
            SecretId=self.secret_id,
            SecretKey=self.secret_key,
            Token=None,  # 使用永久密钥，不需要token
            Domain=None  # 使用默认域名
        )
        
        # 创建COS客户端
        self.client = CosS3Client(self.config)
        
        # 设置日志
        logging.basicConfig(level=logging.INFO)
        self.logger = logging.getLogger(__name__)
    
    def upload_file(self, local_file_path, remote_key=None, content_type=None):
        """
        上传文件到COS并返回访问URL
        
        Args:
            local_file_path (str): 本地文件的绝对路径
            remote_key (str): 远程文件名，如果不指定则使用本地文件名
            content_type (str): 文件MIME类型，如果不指定则自动推断
        
        Returns:
            dict: 包含上传结果和访问URL的字典
                {
                    'success': bool,
                    'url': str,
                    'etag': str,
                    'key': str,
                    'error': str  # 仅在失败时存在
                }
        """
        try:
            # 验证文件是否存在
            if not os.path.exists(local_file_path):
                return {
                    'success': False,
                    'error': f'文件不存在: {local_file_path}'
                }
            
            # 如果没有指定远程文件名，使用本地文件名
            if not remote_key:
                remote_key = os.path.basename(local_file_path)
            
            # 添加时间戳前缀避免文件名冲突
            timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
            remote_key = f"{timestamp}_{remote_key}"
            
            self.logger.info(f"开始上传文件: {local_file_path} -> {remote_key}")
            
            # 准备上传参数
            upload_params = {
                'Bucket': self.bucket_name,
                'LocalFilePath': local_file_path,
                'Key': remote_key,
                'PartSize': 10,  # 分块大小，单位MB
                'MAXThread': 10,  # 最大线程数
            }
            
            # 如果指定了content_type，添加到参数中
            if content_type:
                upload_params['ContentType'] = content_type
            
            # 使用高级上传接口
            response = self.client.upload_file(**upload_params)
            
            # 构造访问URL
            url = self._build_url(remote_key)
            
            result = {
                'success': True,
                'url': url,
                'etag': response.get('ETag', ''),
                'key': remote_key
            }
            
            self.logger.info(f"文件上传成功: {url}")
            return result
            
        except CosServiceError as e:
            error_msg = f"COS服务错误: {e.get_error_msg()}"
            self.logger.error(error_msg)
            return {
                'success': False,
                'error': error_msg
            }
        except CosClientError as e:
            error_msg = f"COS客户端错误: {str(e)}"
            self.logger.error(error_msg)
            return {
                'success': False,
                'error': error_msg
            }
        except Exception as e:
            error_msg = f"未知错误: {str(e)}"
            self.logger.error(error_msg)
            return {
                'success': False,
                'error': error_msg
            }
    
    def _build_url(self, key):
        """
        构造文件的访问URL
        
        Args:
            key (str): 文件的远程键名
        
        Returns:
            str: 文件的访问URL
        """
        # COS的标准访问URL格式
        return f"https://{self.bucket_name}.cos.{self.region}.myqcloud.com/{key}"
    
    def get_file_url(self, key):
        """
        获取已上传文件的访问URL
        
        Args:
            key (str): 文件的远程键名
        
        Returns:
            str: 文件的访问URL
        """
        return self._build_url(key)
    
    def check_file_exists(self, key):
        """
        检查文件是否存在
        
        Args:
            key (str): 文件的远程键名
        
        Returns:
            bool: 文件是否存在
        """
        try:
            self.client.head_object(Bucket=self.bucket_name, Key=key)
            return True
        except CosServiceError:
            return False


def main():
    """测试函数"""
    try:
        # 创建COS客户端
        cos_client = COSClient()
        
        # 测试文件路径（这里需要一个实际存在的文件）
        test_file = '/Users/wuliang/workspace/pdf-mcp/README.md'
        
        if not os.path.exists(test_file):
            print(f"测试文件不存在: {test_file}")
            print("请修改test_file变量为一个实际存在的文件路径")
            return
        
        print(f"正在上传文件: {test_file}")
        
        # 上传文件
        result = cos_client.upload_file(test_file)
        
        if result['success']:
            print("\n上传成功!")
            print(f"文件URL: {result['url']}")
            print(f"ETag: {result['etag']}")
            print(f"远程文件名: {result['key']}")
        else:
            print(f"\n上传失败: {result['error']}")
    
    except Exception as e:
        print(f"测试过程中发生错误: {str(e)}")


if __name__ == '__main__':
    main()