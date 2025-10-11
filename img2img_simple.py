#!/usr/bin/env python3
"""
简化版 Qwen Image Edit
直接读取文件，生成到指定目录
"""

import sys
import json
import torch
from PIL import Image
from diffusers import QwenImageEditPipeline
import os

def main():
    # 读取命令行参数
    if len(sys.argv) < 4:
        print("Usage: python img2img_simple.py <input_image> <prompt> <output_image>")
        sys.exit(1)

    input_path = sys.argv[1]
    prompt = sys.argv[2]
    output_path = sys.argv[3]

    print(f"输入图片: {input_path}")
    print(f"提示词: {prompt}")
    print(f"输出路径: {output_path}")

    # 检查输入文件
    if not os.path.exists(input_path):
        print(f"错误: 输入文件不存在: {input_path}")
        sys.exit(1)

    # 加载图片
    print("加载图片...")
    image = Image.open(input_path).convert('RGB')
    print(f"图片尺寸: {image.size}")

    # 检测设备
    if torch.cuda.is_available():
        device = "cuda"
        torch_dtype = torch.bfloat16
    elif torch.backends.mps.is_available():
        device = "mps"
        torch_dtype = torch.float32
    else:
        device = "cpu"
        torch_dtype = torch.float32

    print(f"使用设备: {device}")

    # 加载模型（使用本地路径）
    model_path = "/Users/xcl/rime/qwen-image-edit"
    print(f"加载本地模型: {model_path}")
    pipeline = QwenImageEditPipeline.from_pretrained(
        model_path,
        torch_dtype=torch_dtype,
        local_files_only=True
    )
    pipeline = pipeline.to(device)
    pipeline.set_progress_bar_config(disable=False)
    print("模型加载完成")

    # 生成
    print("开始生成...")
    with torch.inference_mode():
        output = pipeline(
            image=image,
            prompt=prompt,
            negative_prompt=" ",
            num_inference_steps=30,
            true_cfg_scale=4.0,
            guidance_scale=1.0,
            generator=torch.Generator(device=device).manual_seed(42),
            num_images_per_prompt=1
        )
        result_image = output.images[0]

    # 保存结果
    print(f"保存结果到: {output_path}")
    result_image.save(output_path)
    print("完成!")

if __name__ == '__main__':
    try:
        main()
    except Exception as e:
        print(f"错误: {str(e)}")
        import traceback
        traceback.print_exc()
        sys.exit(1)
