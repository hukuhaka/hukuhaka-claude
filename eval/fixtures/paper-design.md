# Design
> Depth Anything V2

## Tech Stack

- **Python 3.11**: Backend (PyTorch, Gradio, OpenCV)
- **TypeScript/React**: Frontend auth UI (src/ui/)
- **PyTorch**: Deep learning framework for depth estimation
- **Gradio**: Web demo interface
- **DINOv2**: Vision transformer backbone (self-supervised)

## Architecture

- Encoder-decoder: DINOv2 backbone → DPT decoder head → depth map
- Model variants: Small (24.8M), Base (97.5M), Large (335.3M), Giant (1.3B)
- Metric depth: optional absolute depth estimation in meters (metric_depth/)
- Frontend: React SPA for auth (login/register), separate from Gradio demo

## Patterns

- Feature pyramid: multi-scale features from DINOv2 intermediate layers
- Reassemble blocks: project + resize transformer features to spatial maps
- Fusion blocks: progressively upsample and merge multi-scale features
- Head: final convolution layers for depth prediction

## Key Decisions

- DINOv2 over ImageNet pretrained: stronger monocular depth priors from self-supervised training
- DPT over simple decoder: better fine-grained detail via multi-scale fusion
- Gradio over custom web: fast prototyping, built-in image slider widget
- Synthetic data training: MiDaS + large-scale pseudo-labeled data for robustness
