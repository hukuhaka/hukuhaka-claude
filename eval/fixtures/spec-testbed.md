# Project Spec
> Prescriptive — do not modify without explicit approval

## 1. Overview & Goals
Monocular depth estimation using Vision Transformers.

## 2. Architecture Decisions
Python 3, PyTorch, DINOv2 backbone. Gradio for web demo (app.py).

## 3. Directory Structure
depth_anything_v2/ (core model), metric_depth/ (metric depth estimation), assets/ (sample images)

## 4. Interface Contracts
depth_anything_v2/dpt.py:DepthAnythingV2 — main model class, forward(x) returns depth map tensor

## 5. Component Contracts
run.py — single image inference, run_video.py — video inference, app.py — Gradio web demo

## 6. Naming Contracts
(To be defined)

## 7. Configuration Rules
requirements.txt for dependencies. Model configs via constructor args (encoder, features, out_channels).

## 8. Contract Tests
(To be defined)

## 9. Definition of Done
(To be defined)
