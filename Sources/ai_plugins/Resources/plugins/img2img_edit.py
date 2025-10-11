#!/usr/bin/env python3
"""
Qwen Image Edit CLI
Command-line tool for image-to-image editing using Qwen-Image-Edit-2509 model
"""

import os
import sys
import json
import base64
import io
import torch
from PIL import Image
from diffusers import QwenImageEditPlusPipeline

def base64_to_image(base64_str):
    """Convert base64 string to PIL Image"""
    image_data = base64.b64decode(base64_str)
    image = Image.open(io.BytesIO(image_data))
    return image.convert('RGB')

def image_to_base64(image):
    """Convert PIL Image to base64 string"""
    buffer = io.BytesIO()
    image.save(buffer, format='PNG')
    base64_str = base64.b64encode(buffer.getvalue()).decode('utf-8')
    return base64_str

def main():
    # Read input from stdin with debug info
    print(json.dumps({'status': 'starting', 'python_version': sys.version}), flush=True, file=sys.stderr)

    try:
        input_text = sys.stdin.read()
        print(json.dumps({'status': 'input_read', 'length': len(input_text)}), flush=True, file=sys.stderr)

        input_data = json.loads(input_text)
        print(json.dumps({'status': 'json_parsed', 'keys': list(input_data.keys())}), flush=True, file=sys.stderr)
    except json.JSONDecodeError as e:
        error_result = {'status': 'error', 'error': f'JSON parse error: {str(e)}'}
        print(json.dumps(error_result), flush=True)
        sys.exit(1)
    except Exception as e:
        error_result = {'status': 'error', 'error': f'Input read error: {str(e)}'}
        print(json.dumps(error_result), flush=True)
        sys.exit(1)

    # Parse parameters
    images_base64 = input_data['images']
    prompt = input_data['prompt']
    negative_prompt = input_data.get('negative_prompt', ' ')
    num_inference_steps = input_data.get('num_inference_steps', 40)
    true_cfg_scale = input_data.get('true_cfg_scale', 4.0)
    guidance_scale = input_data.get('guidance_scale', 1.0)
    seed = input_data.get('seed', -1)

    print(json.dumps({'status': 'params_parsed', 'num_images': len(images_base64)}), flush=True, file=sys.stderr)

    # Print progress
    print(json.dumps({'status': 'loading_model'}), flush=True)

    # Determine device and dtype
    try:
        if torch.cuda.is_available():
            device = "cuda"
            torch_dtype = torch.bfloat16
        elif torch.backends.mps.is_available():
            device = "mps"
            torch_dtype = torch.float32
        else:
            device = "cpu"
            torch_dtype = torch.float32

        print(json.dumps({'status': 'device_selected', 'device': device}), flush=True, file=sys.stderr)

        # Load pipeline
        pipeline = QwenImageEditPlusPipeline.from_pretrained(
            "Qwen/Qwen-Image-Edit-2509",
            torch_dtype=torch_dtype
        )
        print(json.dumps({'status': 'pipeline_loaded'}), flush=True, file=sys.stderr)

        pipeline = pipeline.to(device)
        pipeline.set_progress_bar_config(disable=True)

        print(json.dumps({'status': 'model_loaded', 'device': device}), flush=True)
    except Exception as e:
        error_result = {'status': 'error', 'error': f'Model loading error: {str(e)}'}
        print(json.dumps(error_result), flush=True)
        sys.exit(1)

    # Convert base64 to images
    print(json.dumps({'status': 'processing_images'}), flush=True)
    try:
        input_images = [base64_to_image(img_b64) for img_b64 in images_base64]
        print(json.dumps({'status': 'images_decoded', 'count': len(input_images)}), flush=True, file=sys.stderr)
    except Exception as e:
        error_result = {'status': 'error', 'error': f'Image decode error: {str(e)}'}
        print(json.dumps(error_result), flush=True)
        sys.exit(1)

    # Setup generator
    if seed < 0:
        seed = torch.randint(0, 2**32 - 1, (1,)).item()
    generator = torch.Generator(device=device).manual_seed(seed)

    # Prepare inputs
    inputs = {
        "image": input_images if len(input_images) > 1 else input_images[0],
        "prompt": prompt,
        "negative_prompt": negative_prompt,
        "num_inference_steps": num_inference_steps,
        "true_cfg_scale": true_cfg_scale,
        "guidance_scale": guidance_scale,
        "generator": generator,
        "num_images_per_prompt": 1,
    }

    # Generate
    print(json.dumps({'status': 'generating', 'steps': num_inference_steps}), flush=True)

    with torch.inference_mode():
        output = pipeline(**inputs)
        output_image = output.images[0]

    # Convert to base64
    print(json.dumps({'status': 'encoding_result'}), flush=True)
    result_base64 = image_to_base64(output_image)

    # Output result
    result = {
        'status': 'complete',
        'image': result_base64,
        'metadata': {
            'prompt': prompt,
            'num_images': len(input_images),
            'steps': num_inference_steps,
            'seed': seed,
            'cfg_scale': true_cfg_scale,
            'guidance_scale': guidance_scale
        }
    }

    print(json.dumps(result), flush=True)

if __name__ == '__main__':
    try:
        main()
    except Exception as e:
        error_result = {
            'status': 'error',
            'error': str(e)
        }
        print(json.dumps(error_result), flush=True)
        sys.exit(1)
