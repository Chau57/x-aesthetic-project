import os
import sys
import argparse
import torch
import torch.nn as nn

# Resolve project path to import models properly
current_dir = os.path.dirname(os.path.abspath(__file__))
project_root = os.path.dirname(current_dir)
sys.path.append(project_root)

from models.attribute_net import AttributeNet
from models.hyper_aesthetic import HyperNetwork, AestheticNet

class UnifiedAestheticPipeline(nn.Module):
    """
    Stitches AttributeNet, HyperNetwork, and AestheticNet into a single, unified 
    inference graph. This wrapper enables end-to-end tracing and compilation.
    """
    def __init__(self, attribute_net, hyper_net, aesthetic_net):
        super(UnifiedAestheticPipeline, self).__init__()
        self.attribute_net = attribute_net
        self.hyper_net = hyper_net
        self.aesthetic_net = aesthetic_net
        
    def forward(self, mlsp_features):
        """
        End-to-end forward pass.
        
        Args:
            mlsp_features (torch.Tensor): Frozen MLSP backbone representation of shape [Batch_Size, 1264].
            
        Returns:
            torch.Tensor: Aesthetic probability scores distribution of shape [Batch_Size, 10].
        """
        # Shape trace: [Batch_Size, 1264]
        
        # 1. Pass through AttributeNet to extract the 512-D attribute embedding layer
        _, _, attr_embed = self.attribute_net(mlsp_features)
        # Shape trace: [Batch_Size, 1264] -> [Batch_Size, 512]
        
        # 2. Feed embedding into HyperNetwork to dynamically generate linear parameters
        weights_dict = self.hyper_net(attr_embed)
        # Tensors within weights_dict are generated dynamically based on L2-normalized embeddings
        
        # 3. Grade the image context-adaptively in AestheticNet
        out = self.aesthetic_net(mlsp_features, weights_dict)
        # Shape trace: [Batch_Size, 1264] -> [Batch_Size, 10]
        
        return out


def export_aesthetic_pipeline(onnx_path, device):
    """
    Stitches model architectures, traces the pipeline graph, and serializes to ONNX format.
    """
    print("\n" + "="*50)
    print("PART 1: ONNX EXPORT - AESTHETIC EVALUATION PIPELINE")
    print("="*50)
    
    # 1. Instantiate the target networks
    print("Instantiating PyTorch model layers...")
    attribute_net = AttributeNet(input_dim=1264, embed_dim=512, num_style=20, num_composition=9).to(device)
    hyper_net = HyperNetwork(embed_dim=512, bottleneck_dim=16).to(device)
    aesthetic_net = AestheticNet().to(device)
    
    # Put all layers in evaluation mode
    attribute_net.eval()
    hyper_net.eval()
    aesthetic_net.eval()
    
    # 2. Stitch modules into a single, cohesive PyTorch graph
    pipeline = UnifiedAestheticPipeline(attribute_net, hyper_net, aesthetic_net).to(device)
    pipeline.eval() # Set entire unified pipeline module to evaluation mode
    
    # 3. Create dummy tracing input representing a single MLSP scene feature
    dummy_input = torch.randn(1, 1264, dtype=torch.float32).to(device)
    # Shape trace: [1, 1264]
    
    print(f"Exporting unified aesthetic pipeline graph to '{onnx_path}'...")
    try:
        torch.onnx.export(
            pipeline,
            dummy_input,
            onnx_path,
            export_params=True,
            opset_version=18, # Opset 18 prevents version conversion warnings/errors
            do_constant_folding=True,
            input_names=['mlsp_features'],
            output_names=['aesthetic_scores'],
            dynamic_axes={
                'mlsp_features': {0: 'batch_size'},
                'aesthetic_scores': {0: 'batch_size'}
            }
        )
        print("ONNX graph tracing and serialization completed successfully!")
    except Exception as e:
        print(f"Error: ONNX serialization failed: {e}")
        return False
        
    return True


def export_yolov8_segmentation():
    """
    PART 2: Compiles YOLOv8-Nano Segmentation model directly to TFLite (Float16/Post-Training Quantization).
    """
    print("\n" + "="*50)
    print("PART 2: TFLITE COMPILATION - YOLOv8 SEGMENTER FOR GHOST SILHOUETTES")
    print("="*50)
    
    try:
        from ultralytics import YOLO
        print("Fetching pre-trained 'yolov8n-seg.pt' model...")
        
        # Load the pre-trained nano segmenter
        model = YOLO("yolov8n-seg.pt")
        
        # Export the model using built-in ultralytics export compiler
        # half=True invokes Float16 Post-Training Quantization to minimize edge weight size
        print("Starting TFLite PTQ compilation (FP16)...")
        tflite_path = model.export(format='tflite', half=True)
        
        print(f"YOLOv8-Seg compiled successfully! Asset located at: {tflite_path}")
        return True
    except ImportError:
        print("Warning: 'ultralytics' framework is not installed in the current environment.")
        print("To complete YOLOv8-seg export, please run: pip install ultralytics")
        return False
    except Exception as e:
        print(f"Error: YOLOv8 compilation failed: {e}")
        return False


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Export X-Aesthetic model assets for Edge device compilation.")
    parser.add_argument('--onnx_path', type=str, default='aesthetic_net.onnx', help="Output path for the serialized aesthetic ONNX model")
    parser.add_argument('--device', type=str, default='cpu', help="Target device (cpu or cuda)")
    parser.add_argument('--skip_yolo', action='store_true', help="Skip exporting YOLOv8 segmenter model")
    
    args = parser.parse_args()
    
    target_device = torch.device(args.device)
    
    # 1. Run Part 1: Aesthetic pipeline ONNX export
    success_aesthetic = export_aesthetic_pipeline(args.onnx_path, target_device)
    
    # 2. Run Part 2: YOLOv8 segmentation export
    success_yolo = True
    if not args.skip_yolo:
        success_yolo = export_yolov8_segmentation()
        
    print("\n" + "="*50)
    print("EXPORT STATUS REPORT")
    print("="*50)
    print(f"Aesthetic Pipeline ONNX Export:   {'SUCCESS' if success_aesthetic else 'FAILED'}")
    print(f"YOLOv8 Segmentation TFLite:       {'SUCCESS' if success_yolo else 'SKIPPED/FAILED'}")
    print("="*50)
