#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
增强版AI分类器 - 支持多种模型
兼容原有功能 + 新增DeepDanbooru二次元识别
"""
import sys
import os
import json
import time
import numpy as np
from PIL import Image

# 抑制TensorFlow日志输出
os.environ['TF_CPP_MIN_LOG_LEVEL'] = '2'  # 只显示ERROR和FATAL
os.environ['TF_ENABLE_ONEDNN_OPTS'] = '0'  # 关闭oneDNN优化信息

import tensorflow as tf
from pathlib import Path

# 进一步抑制TensorFlow日志
tf.get_logger().setLevel('ERROR')

class EnhancedAIClassifier:
    def __init__(self):
        self.app_dir = Path(sys.argv[0]).parent if hasattr(sys, 'argv') and len(sys.argv) > 0 else Path.cwd()
        self.models_dir = self.app_dir / "models"
        print(f"应用目录: {self.app_dir}")
        print(f"模型目录: {self.models_dir}")

    def classify_original(self, image_path):
        """原有的分类功能 - 使用ImageNet预训练模型"""
        try:
            print("🤖 开始通用物体识别...")

            # 加载ImageNet预训练模型
            print("🔄 加载MobileNetV2模型...")
            model = tf.keras.applications.MobileNetV2(
                weights='imagenet',
                include_top=True,
                input_shape=(224, 224, 3)
            )
            print("✅ 模型加载成功")

            # 预处理图像
            image = Image.open(image_path)
            if image.mode != 'RGB':
                image = image.convert('RGB')

            # ImageNet使用224x224
            image = image.resize((224, 224), Image.Resampling.LANCZOS)
            image_array = np.array(image, dtype=np.float32)

            # MobileNetV2预处理
            image_array = tf.keras.applications.mobilenet_v2.preprocess_input(image_array)
            image_array = np.expand_dims(image_array, axis=0)

            print("🤖 开始AI推理...")
            # 模型推理
            start_time = time.time()
            predictions = model.predict(image_array, verbose=0)
            processing_time = time.time() - start_time

            # 解码预测结果
            decoded_predictions = tf.keras.applications.mobilenet_v2.decode_predictions(
                predictions, top=5
            )[0]

            # 简洁输出
            labels = [label.replace('_', ' ') for _, label, _ in decoded_predictions]
            return "通用识别: " + ", ".join(labels)

        except Exception as e:
            return f"通用识别错误: {str(e)}"

    def classify_anime(self, image_path):
        """二次元风格识别"""
        try:
            print("🎨 开始二次元风格识别...")

            # 检查DeepDanbooru模型文件
            deepdanbooru_dir = self.models_dir / "deepdanbooru"
            model_path = deepdanbooru_dir / "model-resnet_custom_v3.h5"
            tags_path = deepdanbooru_dir / "tags.txt"

            if not model_path.exists():
                return f"❌ DeepDanbooru模型文件不存在: {model_path}"

            if not tags_path.exists():
                return f"❌ 标签文件不存在: {tags_path}"

            print(f"✅ 找到模型文件: {model_path}")
            print(f"✅ 找到标签文件: {tags_path}")

            # 加载标签
            with open(tags_path, 'r', encoding='utf-8') as f:
                tags = [line.strip() for line in f.readlines()]
            print(f"✅ 加载了 {len(tags)} 个标签")

            # 加载模型
            print("🔄 加载DeepDanbooru模型...")
            model = tf.keras.models.load_model(str(model_path), compile=False)
            print("✅ 模型加载成功")

            # 预处理图像
            image = Image.open(image_path)
            if image.mode != 'RGB':
                image = image.convert('RGB')

            # DeepDanbooru通常使用512x512
            image = image.resize((512, 512), Image.Resampling.LANCZOS)
            image_array = np.array(image, dtype=np.float32)
            image_array = image_array / 255.0  # 归一化
            image_array = np.expand_dims(image_array, axis=0)

            print("🤖 开始AI推理...")
            # 模型推理
            start_time = time.time()
            predictions = model.predict(image_array, verbose=0)
            processing_time = time.time() - start_time

            # 解析结果
            scores = predictions[0] if len(predictions.shape) > 1 else predictions
            threshold = 0.3  # 置信度阈值

            results = []
            for i, score in enumerate(scores):
                if i < len(tags) and score >= threshold:
                    results.append({
                        "tag": tags[i],
                        "confidence": float(score)
                    })

            # 按置信度排序
            results.sort(key=lambda x: x["confidence"], reverse=True)
            results = results[:15]  # 取前15个

            # 简洁输出
            if results:
                tag_names = [result["tag"] for result in results]
                return "二次元标签: " + ", ".join(tag_names)
            else:
                return "未识别到任何二次元标签"

        except Exception as e:
            return f"❌ 二次元识别失败: {str(e)}"

def main():
    if len(sys.argv) < 3:
        print("用法: python enhanced_ai_classifier.py <图片路径> <模式>")
        print("模式: original | anime")
        sys.exit(1)

    image_path = sys.argv[1]
    mode = sys.argv[2]

    # 处理file://协议的路径
    if image_path.startswith("file:///"):
        image_path = image_path[8:]  # 移除file:///
        import urllib.parse
        image_path = urllib.parse.unquote(image_path)
    elif image_path.startswith("file://"):
        image_path = image_path[7:]  # 移除file://
        import urllib.parse
        image_path = urllib.parse.unquote(image_path)

    print(f"处理后的图片路径: {image_path}")

    if not os.path.exists(image_path):
        print(f"图片不存在: {image_path}")
        sys.exit(1)

    classifier = EnhancedAIClassifier()

    if mode == "anime":
        result = classifier.classify_anime(image_path)
    elif mode == "original":
        result = classifier.classify_original(image_path)
    else:
        result = f"未知模式: {mode}，支持的模式: original, anime"

    print(result)

if __name__ == "__main__":
    main()
