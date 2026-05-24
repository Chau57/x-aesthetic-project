import torch
import torch.nn as nn
import torchvision.models as models

class MLSP_EfficientNetB4(nn.Module):
    """
    Multi-Level Spatially Pooled (MLSP) feature extractor using a frozen EfficientNet-B4 backbone.
    
    This module extracts intermediate feature maps from the final 5 MBConv blocks of EfficientNet-B4
    (specifically at flat block indices 15, 21, 25, 29, and 31), applies Global Average Pooling (GAP)
    on each to remove spatial resolution dependencies, and concatenates them along the channel dimension.
    
    Resulting output is a high-fidelity scene embedding of dimension 1264.
    """
    def __init__(self):
        super(MLSP_EfficientNetB4, self).__init__()
        
        # Load pre-trained EfficientNet-B4
        # We check for the modern weights argument first to avoid deprecation warnings,
        # falling back to pretrained=True if running on older torchvision versions.
        try:
            from torchvision.models import EfficientNet_B4_Weights
            self.backbone = models.efficientnet_b4(weights=EfficientNet_B4_Weights.DEFAULT)
        except (ImportError, AttributeError):
            self.backbone = models.efficientnet_b4(pretrained=True)
            
        # Freeze all parameters of the backbone model completely
        for param in self.backbone.parameters():
            param.requires_grad = False
            
        # The backbone 'features' is a sequential module containing the stem and MBConv stages.
        # Index 0: Conv2dNormActivation (Stem)
        # Indices 1 to 7: MBConv Stages containing stacked MBConv blocks
        self.stem = self.backbone.features[0]
        
        # Extract all individual MBConv blocks from stages 1 to 7 to flatten the architecture
        self.blocks = nn.ModuleList()
        for stage in self.backbone.features[1:8]:
            for block in stage:
                self.blocks.append(block)
                
        # Number of flattened MBConv blocks is 32 (indices 0 to 31).
        # We hook and capture outputs precisely at indices: 15, 21, 25, 29, 31.
        self.target_block_indices = [15, 21, 25, 29, 31]
        
        # Global Average Pooling to eliminate spatial dependencies (aspect ratio, crop width/height)
        self.gap = nn.AdaptiveAvgPool2d(1)
        
        # Re-ensure all parameters are frozen and gradient computation is bypassed
        for param in self.parameters():
            param.requires_grad = False
            
    def forward(self, x):
        """
        Forward pass for MLSP Feature Extractor.
        
        Args:
            x (torch.Tensor): Raw image tensor of shape [Batch_Size, 3, H, W], typically resized to 224x224.
            
        Returns:
            torch.Tensor: Flat multi-level pooled embedding of shape [Batch_Size, 1264].
        """
        # Shape trace: [Batch_Size, 3, H, W] -> e.g., [Batch_Size, 3, 224, 224]
        
        # 1. Forward pass through the initial stem layer
        x = self.stem(x)
        # Shape trace: [Batch_Size, 3, 224, 224] -> [Batch_Size, 48, 112, 112]
        
        pooled_outputs = []
        
        # 2. Iterate through all 32 flattened MBConv blocks
        for i, block in enumerate(self.blocks):
            x = block(x)
            
            # Hook the feature maps of specified blocks
            if i in self.target_block_indices:
                # Features captured at specific layers:
                # Index 15 (Stage 4, block 6)   - Shape: [Batch_Size, 112, H_15, W_15]
                # Index 21 (Stage 5, block 6)   - Shape: [Batch_Size, 160, H_21, W_21]
                # Index 25 (Stage 6, block 4)   - Shape: [Batch_Size, 272, H_25, W_25]
                # Index 29 (Stage 6, block 8)   - Shape: [Batch_Size, 272, H_29, W_29]
                # Index 31 (Stage 7, block 2)   - Shape: [Batch_Size, 448, H_31, W_31]
                
                pooled = self.gap(x) 
                # Shape trace: [Batch_Size, C_i, H_i, W_i] -> [Batch_Size, C_i, 1, 1]
                
                pooled = torch.flatten(pooled, start_dim=1)
                # Shape trace: [Batch_Size, C_i, 1, 1] -> [Batch_Size, C_i]
                
                pooled_outputs.append(pooled)
                
        # 3. Concatenate all pooled feature vectors along the channel dimension (dim=1)
        # Channels: 112 + 160 + 272 + 272 + 448 = 1264
        flat_features = torch.cat(pooled_outputs, dim=1)
        # Shape trace: List of [[B, 112], [B, 160], [B, 272], [B, 272], [B, 448]] -> [Batch_Size, 1264]
        
        return flat_features

if __name__ == "__main__":
    # Diagnostic instantiation and shape verification block
    print("Testing MLSP_EfficientNetB4 feature extraction...")
    model = MLSP_EfficientNetB4()
    
    # Input tensor representing a batch of 2 RGB images of size 224x224
    dummy_input = torch.randn(2, 3, 224, 224) # Shape: [2, 3, 224, 224]
    
    with torch.no_grad():
        output = model(dummy_input)
        
    print(f"Input shape:  {list(dummy_input.shape)}")
    print(f"Output shape: {list(output.shape)}") # Should be [2, 1264]
    assert output.shape == (2, 1264), f"Error: Output shape is {output.shape}, expected (2, 1264)"
    print("MLSP Backbone verification passed successfully!")
