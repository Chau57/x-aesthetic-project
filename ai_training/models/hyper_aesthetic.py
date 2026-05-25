import torch
import torch.nn as nn
import torch.nn.functional as F

class HyperNetBlock(nn.Module):
    """
    HyperNet Block (HB) serving a single target layer of AestheticNet.
    
    To avoid parameter explosion, this block applies low-rank bottleneck compression:
    1. Input: Normalized 512-D attribute embedding.
    2. Bottleneck: Compresses 512-D down to dimension d=16 via nn.Linear + ReLU.
    3. Projection Heads: Dual parallel linear heads output:
       - Flat weight matrix: Dimension [Batch_Size, out_features * in_features]
       - Flat bias vector: Dimension [Batch_Size, out_features]
    """
    def __init__(self, in_features=512, bottleneck_dim=16, out_features_y=512, in_features_x=1264):
        super(HyperNetBlock, self).__init__()
        self.out_features_y = out_features_y
        self.in_features_x = in_features_x
        
        # Shared bottleneck layer to compress 512-D representation to 16-D
        self.bottleneck = nn.Linear(in_features, bottleneck_dim)
        self.relu = nn.ReLU()
        
        # Parallel parameter generation heads
        self.weight_proj = nn.Linear(bottleneck_dim, out_features_y * in_features_x)
        self.bias_proj = nn.Linear(bottleneck_dim, out_features_y)
        
    def forward(self, e_norm):
        """
        Forward pass for HyperNetBlock.
        
        Args:
            e_norm (torch.Tensor): L2-normalized attribute embedding of shape [Batch_Size, 512].
            
        Returns:
            tuple:
                - w (torch.Tensor): Re-shaped weight matrix tensor of shape [Batch_Size, out_features_y, in_features_x].
                - b (torch.Tensor): Re-shaped bias vector tensor of shape [Batch_Size, out_features_y].
        """
        # Shape trace: [Batch_Size, 512]
        
        # 1. Bottleneck compression
        h = self.bottleneck(e_norm)
        # Shape trace: [Batch_Size, 512] -> [Batch_Size, 16]
        
        h = self.relu(h)
        # Shape trace: [Batch_Size, 16] -> [Batch_Size, 16]
        
        # 2. Parallel linear projections for weight matrix and bias vector
        flat_w = self.weight_proj(h)
        # Shape trace: [Batch_Size, 16] -> [Batch_Size, out_features_y * in_features_x]
        
        flat_b = self.bias_proj(h)
        # Shape trace: [Batch_Size, 16] -> [Batch_Size, out_features_y]
        
        # 3. Reshape dynamic parameters to support batch multiplication (torch.bmm)
        w = flat_w.view(-1, self.out_features_y, self.in_features_x)
        # Shape trace: [Batch_Size, out_features_y * in_features_x] -> [Batch_Size, out_features_y, in_features_x]
        
        b = flat_b.view(-1, self.out_features_y)
        # Shape trace: [Batch_Size, out_features_y] -> [Batch_Size, out_features_y]
        
        return w, b


class HyperNetwork(nn.Module):
    """
    HyperNetwork coordinating dynamic parameter updates for the target AestheticNet.
    
    Constructs individual HyperNet Blocks for all 5 layers of AestheticNet:
    - Layer 1: 1264 -> 512
    - Layer 2: 512 -> 256
    - Layer 3: 256 -> 256
    - Layer 4: 256 -> 64
    - Layer 5: 64 -> 10
    """
    def __init__(self, embed_dim=512, bottleneck_dim=16):
        super(HyperNetwork, self).__init__()
        
        # Initialize blocks for each of the 5 sequential target layers
        self.hb1 = HyperNetBlock(embed_dim, bottleneck_dim, 512, 1264)
        self.hb2 = HyperNetBlock(embed_dim, bottleneck_dim, 256, 512)
        self.hb3 = HyperNetBlock(embed_dim, bottleneck_dim, 256, 256)
        self.hb4 = HyperNetBlock(embed_dim, bottleneck_dim, 64, 256)
        self.hb5 = HyperNetBlock(embed_dim, bottleneck_dim, 10, 64)
        
    def forward(self, e_s):
        """
        Generates dynamic weights and biases dictionary from raw attribute embeddings.
        
        Args:
            e_s (torch.Tensor): Shared representation output of AttributeNet of shape [Batch_Size, 512].
            
        Returns:
            dict: Mapping of target layer names to generated weight and bias tuples.
        """
        # Shape trace: [Batch_Size, 512]
        
        # 1. Apply L2 normalization to establish spherical metric uniformity
        e_norm = F.normalize(e_s, p=2, dim=-1)
        # Shape trace: [Batch_Size, 512] -> [Batch_Size, 512]
        
        # 2. Run normalized embedding through individual block generators
        w1, b1 = self.hb1(e_norm) # w1: [B, 512, 1264], b1: [B, 512]
        w2, b2 = self.hb2(e_norm) # w2: [B, 256, 512],  b2: [B, 256]
        w3, b3 = self.hb3(e_norm) # w3: [B, 256, 256],  b3: [B, 256]
        w4, b4 = self.hb4(e_norm) # w4: [B, 64, 256],   b4: [B, 64]
        w5, b5 = self.hb5(e_norm) # w5: [B, 10, 64],    b5: [B, 10]
        
        return {
            'layer1': (w1, b1),
            'layer2': (w2, b2),
            'layer3': (w3, b3),
            'layer4': (w4, b4),
            'layer5': (w5, b5)
        }


class AestheticNet(nn.Module):
    """
    AestheticNet: Target Evaluation Network.
    
    Contains no persistent nn.Parameter variables. Its architecture is statically designed
    as 5 linear layers: 1264 -> 512 -> 256 -> 256 -> 64 -> 10.
    
    At runtime, it computes activations dynamically by mapping flat input tensors through
    custom Batch Matrix Multiplication (bmm) using parameters predicted by the HyperNetwork.
    """
    def __init__(self):
        super(AestheticNet, self).__init__()
        # Statically parameter-free architecture
        
    def forward(self, x, weights_dict):
        """
        Forward pass for AestheticNet using dynamic runtime parameters.
        
        Args:
            x (torch.Tensor): Extracted backbone MLSP features of shape [Batch_Size, 1264].
            weights_dict (dict): Runtime weight and bias tensors generated by HyperNetwork.
            
        Returns:
            torch.Tensor: Normalized probability distribution over 10 rating bins [Batch_Size, 10].
        """
        # Shape trace: x: [Batch_Size, 1264]
        
        # --- Layer 1: 1264 -> 512 ---
        w1, b1 = weights_dict['layer1'] # w1: [B, 512, 1264], b1: [B, 512]
        # x.unsqueeze(-1) shape: [Batch_Size, 1264, 1]
        # torch.bmm(w1, x.unsqueeze(-1)) shape: [Batch_Size, 512, 1]
        h1 = torch.bmm(w1, x.unsqueeze(-1)).squeeze(-1) + b1
        # Shape trace: [Batch_Size, 512]
        h1 = F.relu(h1)
        
        # --- Layer 2: 512 -> 256 ---
        w2, b2 = weights_dict['layer2'] # w2: [B, 256, 512], b2: [B, 256]
        h2 = torch.bmm(w2, h1.unsqueeze(-1)).squeeze(-1) + b2
        # Shape trace: [Batch_Size, 256]
        h2 = F.relu(h2)
        
        # --- Layer 3: 256 -> 256 ---
        w3, b3 = weights_dict['layer3'] # w3: [B, 256, 256], b3: [B, 256]
        h3 = torch.bmm(w3, h2.unsqueeze(-1)).squeeze(-1) + b3
        # Shape trace: [Batch_Size, 256]
        h3 = F.relu(h3)
        
        # --- Layer 4: 256 -> 64 ---
        w4, b4 = weights_dict['layer4'] # w4: [B, 64, 256], b4: [B, 64]
        h4 = torch.bmm(w4, h3.unsqueeze(-1)).squeeze(-1) + b4
        # Shape trace: [Batch_Size, 64]
        h4 = F.relu(h4)
        
        # --- Layer 5: 64 -> 10 ---
        w5, b5 = weights_dict['layer5'] # w5: [B, 10, 64], b5: [B, 10]
        h5 = torch.bmm(w5, h4.unsqueeze(-1)).squeeze(-1) + b5
        # Shape trace: [Batch_Size, 10]
        
        # 10 rating bins for AVA dataset, normalized via Softmax
        out = F.softmax(h5, dim=-1)
        # Shape trace: [Batch_Size, 10]
        
        return out


if __name__ == "__main__":
    # Diagnostic instantiation and dynamic network graph validation block
    print("Testing HyperNetwork and Dynamic AestheticNet coupling...")
    
    # 1. Instantiate modules
    hyper_net = HyperNetwork(embed_dim=512, bottleneck_dim=16)
    aesthetic_net = AestheticNet()
    
    # 2. Setup mock feature vector and attribute embeddings
    batch_size = 3
    dummy_mlsp = torch.randn(batch_size, 1264)       # [3, 1264] MLSP scene feature
    dummy_attr_embed = torch.randn(batch_size, 512)   # [3, 512] attribute embedding from AttributeNet
    
    # 3. Dynamic weight generation
    dynamic_weights = hyper_net(dummy_attr_embed)
    print("Successfully generated dynamic weights dictionary! Summary of shapes:")
    for layer_name, (w, b) in dynamic_weights.items():
         print(f"  {layer_name:7s} | Weight shape: {list(w.shape)} | Bias shape: {list(b.shape)}")
         
    # 4. Downstream dynamic forward pass
    preds = aesthetic_net(dummy_mlsp, dynamic_weights)
    print(f"Prediction output shape: {list(preds.shape)}") # Should be [3, 10]
    
    # Assert probability distribution constraints (sum to 1.0 along dim=-1)
    sums = preds.sum(dim=-1)
    print(f"Row probabilities sum verification: {sums.detach().numpy().round(4)}")
    
    assert preds.shape == (batch_size, 10), "Error: Output shape is incorrect."
    assert torch.allclose(sums, torch.ones(batch_size)), "Error: Softmax normalization verification failed."
    
    print("HyperNetwork and AestheticNet coupling verified successfully!")
