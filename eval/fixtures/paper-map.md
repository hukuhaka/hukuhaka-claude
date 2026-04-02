# Project Map
> Depth Anything V2

## Entry Points

- [app.py](app.py): Gradio web UI for depth estimation demo
- [run.py](run.py): CLI batch inference on images
- [run_video.py](run_video.py): CLI video depth estimation
- [depth_anything_v2/dpt.py](depth_anything_v2/dpt.py): DPT decoder head (core model)
- [depth_anything_v2/dinov2.py](depth_anything_v2/dinov2.py): DINOv2 backbone encoder

## Data Flow

Input (image/video) → DINOv2 encoder (dinov2.py) → DPT decoder (dpt.py) → depth map → visualization (app.py/run.py)

## Components

- `depth_anything_v2/`: Core model — DPT head, DINOv2 backbone, encoder-decoder architecture
- `depth_anything_v2/dinov2_layers/`: Transformer building blocks — attention, MLP, patch embed, block
- `metric_depth/`: Metric depth variant — absolute depth estimation (meters)
- `src/ui/`: React frontend — auth components, login/register pages
- `tests/`: Test suite
- `assets/`: Demo images and examples

## Structure

```
app.py, run.py, run_video.py          # Entry points
depth_anything_v2/                     # Core model
  dpt.py, dinov2.py                    # Main architecture
  dinov2_layers/                       # Transformer layers
    attention.py, block.py, mlp.py     # Building blocks
metric_depth/                          # Metric depth variant
src/ui/                                # React frontend
```
