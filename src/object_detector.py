#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
目标检测脚本
支持多种检测模型：YOLO、SSD、MobileNet等
"""

import sys
import os
import numpy as np
import cv2
import time
from datetime import datetime

class ObjectDetector:
    def __init__(self, model_type="yolo", confidence_threshold=0.5):
        self.model_type = model_type.lower()
        self.confidence_threshold = confidence_threshold
        self.net = None
        self.classes = None
        self.colors = None
        self.output_layers = None

        # 初始化模型
        self._initialize_model()

    def _initialize_model(self):
        """初始化检测模型"""
        try:
            if self.model_type == "yolo":
                self._load_yolo_model()
            elif self.model_type == "ssd":
                self._load_ssd_model()
            elif self.model_type == "mobilenet":
                self._load_mobilenet_model()
            else:
                # 如果没有找到模型，使用模拟检测
                self._use_mock_detection()
        except Exception as e:
            print(f"模型加载失败，使用模拟检测: {e}")
            self._use_mock_detection()

    def _load_yolo_model(self):
        """加载YOLO模型"""
        # 获取脚本所在目录，确保路径正确
        script_dir = os.path.dirname(os.path.abspath(__file__))
        models_dir = os.path.join(script_dir, "models")

        # 尝试加载YOLOv4模型文件
        config_path = os.path.join(models_dir, "yolov4.cfg")
        weights_path = os.path.join(models_dir, "yolov4.weights")
        names_path = os.path.join(models_dir, "coco.names")

        # 调试信息：打印路径和文件存在状态
        print(f"调试：脚本目录 = {script_dir}", file=sys.stderr)
        print(f"调试：模型目录 = {models_dir}", file=sys.stderr)
        print(f"调试：config文件存在 = {os.path.exists(config_path)}", file=sys.stderr)
        print(f"调试：weights文件存在 = {os.path.exists(weights_path)}", file=sys.stderr)
        print(f"调试：names文件存在 = {os.path.exists(names_path)}", file=sys.stderr)

        if os.path.exists(weights_path) and os.path.exists(config_path):
            self.net = cv2.dnn.readNet(weights_path, config_path)
            layer_names = self.net.getLayerNames()
            # self.output_layers = [layer_names[i[0] - 1] for i in self.net.getUnconnectedOutLayers()]
            unconnected_layers = self.net.getUnconnectedOutLayers()
            self.output_layers = [layer_names[i - 1] for i in unconnected_layers.flatten()]
            # 加载类别名称
            if os.path.exists(names_path):
                with open(names_path, 'r') as f:
                    self.classes = [line.strip() for line in f.readlines()]
            else:
                self.classes = [f"class_{i}" for i in range(80)]  # COCO数据集有80个类别

            # 生成随机颜色
            self.colors = np.random.uniform(0, 255, size=(len(self.classes), 3))
            print("✅ YOLO模型加载成功")
        else:
            raise FileNotFoundError(f"YOLO模型文件未找到:\n  Config: {config_path}\n  Weights: {weights_path}")

    def _load_ssd_model(self):
        """加载SSD MobileNet模型"""
        script_dir = os.path.dirname(os.path.abspath(__file__))
        models_dir = os.path.join(script_dir, "models")

        config_path = os.path.join(models_dir, "ssd_mobilenet_v2", "ssd_mobilenet_v2_coco.pbtxt")
        weights_path = os.path.join(models_dir, "ssd_mobilenet_v2", "frozen_inference_graph.pb")
        print(f"调试：SSD config路径 = {config_path}", file=sys.stderr)
        print(f"调试：SSD weights路径 = {weights_path}", file=sys.stderr)
        print(f"调试：SSD config存在 = {os.path.exists(config_path)}", file=sys.stderr)
        print(f"调试：SSD weights存在 = {os.path.exists(weights_path)}", file=sys.stderr)

        if os.path.exists(weights_path) and os.path.exists(config_path):
            self.net = cv2.dnn.readNetFromTensorflow(weights_path, config_path)
            # COCO数据集的80个类别
            self.classes = [
                "person", "bicycle", "car", "motorcycle", "airplane", "bus", "train", "truck", "boat",
                "traffic light", "fire hydrant", "stop sign", "parking meter", "bench", "bird", "cat",
                "dog", "horse", "sheep", "cow", "elephant", "bear", "zebra", "giraffe", "backpack",
                "umbrella", "handbag", "tie", "suitcase", "frisbee", "skis", "snowboard", "sports ball",
                "kite", "baseball bat", "baseball glove", "skateboard", "surfboard", "tennis racket",
                "bottle", "wine glass", "cup", "fork", "knife", "spoon", "bowl", "banana", "apple",
                "sandwich", "orange", "broccoli", "carrot", "hot dog", "pizza", "donut", "cake",
                "chair", "couch", "potted plant", "bed", "dining table", "toilet", "tv", "laptop",
                "mouse", "remote", "keyboard", "cell phone", "microwave", "oven", "toaster", "sink",
                "refrigerator", "book", "clock", "vase", "scissors", "teddy bear", "hair drier", "toothbrush"
            ]
            self.colors = np.random.uniform(0, 255, size=(len(self.classes), 3))
            print("✅ SSD MobileNet模型加载成功")
        else:
            raise FileNotFoundError(f"SSD模型文件未找到:\n  Config: {config_path}\n  Weights: {weights_path}")

    def _load_mobilenet_model(self):
        """加载MobileNet模型"""
        # 使用OpenCV提供的预训练模型
        script_dir = os.path.dirname(os.path.abspath(__file__))
        models_dir = os.path.join(script_dir, "models")

        config_path = os.path.join(models_dir, "mobilenet.cfg")
        weights_path = os.path.join(models_dir, "mobilenet.weights")

        print(f"调试：MobileNet config存在 = {os.path.exists(config_path)}", file=sys.stderr)
        print(f"调试：MobileNet weights存在 = {os.path.exists(weights_path)}", file=sys.stderr)

        try:
            # 这里可以下载OpenCV提供的预训练模型
            if os.path.exists(weights_path) and os.path.exists(config_path):
                self.net = cv2.dnn.readNetFromDarknet(config_path, weights_path)
                self.classes = ["person", "car", "bicycle", "dog", "cat", "chair", "table", "bottle", "book", "phone"]
                self.colors = np.random.uniform(0, 255, size=(len(self.classes), 3))
                print("✅ MobileNet模型加载成功")
            else:
                raise FileNotFoundError(f"MobileNet模型文件未找到:\n  Config: {config_path}\n  Weights: {weights_path}")
        except Exception as e:
            raise FileNotFoundError(f"MobileNet模型加载失败: {str(e)}")

    def _use_mock_detection(self):
        """使用模拟检测（当没有真实模型时）"""
        self.net = None
        self.classes = ["person", "car", "bicycle", "dog", "cat", "chair", "table", "bottle", "book", "phone",
                       "laptop", "mouse", "keyboard", "cell phone", "clock", "vase", "scissors", "teddy bear"]
        self.colors = np.random.uniform(0, 255, size=(len(self.classes), 3))
        print("⚠️  使用模拟目标检测")

    def detect_objects(self, image_path):
        """检测图像中的目标"""
        start_time = time.time()

        # 读取图像
        image = cv2.imread(image_path)
        if image is None:
            return self._format_error_result(f"无法读取图像: {image_path}")

        height, width, channels = image.shape

        if self.net is None:
            # 使用模拟检测
            return self._mock_detection(image, width, height, start_time)
        else:
            # 使用真实模型检测
            return self._real_detection(image, width, height, start_time)

    def _mock_detection(self, image, width, height, start_time):
        """模拟目标检测"""
        time.sleep(0.5)  # 模拟处理时间

        # 生成一些随机的检测结果
        detections = []

        # 模拟检测到的物体
        mock_objects = [
            {"class": "person", "confidence": 0.89, "box": [50, 50, 200, 300]},
            {"class": "chair", "confidence": 0.76, "box": [300, 200, 150, 180]},
            {"class": "table", "confidence": 0.65, "box": [100, 400, 250, 100]},
        ]

        # 调整边界框使其在图像范围内
        for obj in mock_objects:
            x, y, w, h = obj["box"]
            if x + w <= width and y + h <= height:
                detections.append(obj)

        processing_time = time.time() - start_time
        return self._format_detection_result(detections, width, height, processing_time, "模拟检测")

    def _real_detection(self, image, width, height, start_time):
        """真实模型检测"""
        try:
            # 预处理图像
            blob = cv2.dnn.blobFromImage(image, 0.00392, (416, 416), (0, 0, 0), True, crop=False)
            self.net.setInput(blob)

            # 运行推理
            if self.model_type == "yolo":
                outputs = self.net.forward(self.output_layers)
                detections = self._process_yolo_outputs(outputs, width, height)
            else:
                outputs = self.net.forward()
                detections = self._process_ssd_outputs(outputs, width, height)

            processing_time = time.time() - start_time
            return self._format_detection_result(detections, width, height, processing_time, self.model_type.upper())

        except Exception as e:
            return self._format_error_result(f"检测过程错误: {str(e)}")

    def _process_yolo_outputs(self, outputs, width, height):
        """处理YOLO模型输出"""
        boxes = []
        confidences = []
        class_ids = []

        for output in outputs:
            for detection in output:
                scores = detection[5:]
                class_id = np.argmax(scores)
                confidence = scores[class_id]

                if confidence > self.confidence_threshold:
                    center_x = int(detection[0] * width)
                    center_y = int(detection[1] * height)
                    w = int(detection[2] * width)
                    h = int(detection[3] * height)

                    x = int(center_x - w / 2)
                    y = int(center_y - h / 2)

                    boxes.append([x, y, w, h])
                    confidences.append(float(confidence))
                    class_ids.append(class_id)

        # 非极大值抑制
        indexes = cv2.dnn.NMSBoxes(boxes, confidences, self.confidence_threshold, 0.4)

        detections = []
        if len(indexes) > 0:
            for i in indexes.flatten():
                x, y, w, h = boxes[i]
                class_name = self.classes[class_ids[i]] if class_ids[i] < len(self.classes) else f"class_{class_ids[i]}"
                detections.append({
                    "class": class_name,
                    "confidence": confidences[i],
                    "box": [x, y, w, h]
                })

        return detections

    def _process_ssd_outputs(self, outputs, width, height):
        """处理SSD模型输出"""
        detections = []

        for detection in outputs[0, 0, :, :]:
            confidence = detection[2]
            if confidence > self.confidence_threshold:
                class_id = int(detection[1])

                x1 = int(detection[3] * width)
                y1 = int(detection[4] * height)
                x2 = int(detection[5] * width)
                y2 = int(detection[6] * height)

                class_name = self.classes[class_id] if class_id < len(self.classes) else f"class_{class_id}"
                detections.append({
                    "class": class_name,
                    "confidence": confidence,
                    "box": [x1, y1, x2 - x1, y2 - y1]
                })

        return detections

    def _format_detection_result(self, detections, width, height, processing_time, model_name):
        """格式化检测结果"""
        result = f"=== {model_name} 目标检测结果 ===\n\n"
        result += f"图像尺寸: {width} x {height}\n"
        result += f"处理时间: {processing_time:.2f}秒\n"
        result += f"置信度阈值: {self.confidence_threshold}\n"
        result += f"检测时间: {datetime.now().strftime('%H:%M:%S')}\n\n"

        if not detections:
            result += "❌ 未检测到任何目标\n"
        else:
            result += f"✅ 检测到 {len(detections)} 个目标:\n\n"

            # 按置信度排序
            detections.sort(key=lambda x: x["confidence"], reverse=True)

            for i, det in enumerate(detections, 1):
                class_name = det["class"]
                confidence = det["confidence"]
                x, y, w, h = det["box"]

                result += f"{i}. 🎯 {class_name}\n"
                result += f"   置信度: {confidence:.1%}\n"
                result += f"   位置: ({x}, {y})\n"
                result += f"   大小: {w} x {h}\n\n"

        return result

    def _format_error_result(self, error_message):
        """格式化错误结果"""
        result = f"=== 目标检测错误 ===\n\n"
        result += f"错误信息: {error_message}\n"
        result += f"时间: {datetime.now().strftime('%H:%M:%S')}\n"
        return result

def main():
    if len(sys.argv) < 2:
        print("用法: python object_detector.py <图片路径> [置信度阈值] [模型类型]")
        sys.exit(1)

    image_path = sys.argv[1]
    confidence = float(sys.argv[2]) if len(sys.argv) > 2 else 0.5
    model_type = sys.argv[3] if len(sys.argv) > 3 else "yolo"

    if not os.path.exists(image_path):
        print(f"图片不存在: {image_path}")
        sys.exit(1)

    # 创建检测器并运行检测
    detector = ObjectDetector(model_type, confidence)
    result = detector.detect_objects(image_path)
    print(result)

if __name__ == "__main__":
    main()
