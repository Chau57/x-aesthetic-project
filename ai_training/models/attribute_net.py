import torch
import torch.nn as nn

class AttributeNet(nn.Module):
    """
    AttributeNet: Multi-Task Multi-Layer Perceptron (MLP) for Aesthetic Attribute Estimation.
    
    Accepts a 1264-D Multi-Level Spatially Pooled (MLSP) vector, maps it to a 512-D shared 
    representation layer (acting as an Attribute Embedding layer), and splits into two 
    specialized classification heads:
    
    1. Style Head (Branch A): Projects embedding to 20 logits representing mutually-exclusive 
       style classes (FlickrStyle dataset).
    2. Composition Head (Branch B): Projects embedding to 9 logits representing non-mutually 
       exclusive compositional rules (KU-PCP dataset).
    """
    def __init__(self, input_dim=1264, embed_dim=512, num_style=20, num_composition=9):
        super(AttributeNet, self).__init__()
        
        # 1. Shared Feature Representation layer
        self.shared_linear = nn.Linear(input_dim, embed_dim)
        self.shared_relu = nn.ReLU()
        
        # 2. Branch A: FlickrStyle Classification Head (Mutually Exclusive Style Categories)
        self.style_head = nn.Linear(embed_dim, num_style)
        
        # 3. Branch B: KU-PCP Multi-Label Composition Head (Structural/Composition Rules)
        self.composition_head = nn.Linear(embed_dim, num_composition)
        
    def forward(self, x):
        """
        Forward pass for AttributeNet.
        
        Args:
            x (torch.Tensor): MLSP embedding tensor of shape [Batch_Size, 1264].
            
        Returns:
            tuple: A tuple containing:
                - style_logits (torch.Tensor): Style class logit scores of shape [Batch_Size, 20].
                - composition_logits (torch.Tensor): Composition class logit scores of shape [Batch_Size, 9].
                - attribute_embedding (torch.Tensor): Exponentiable/normalizable intermediate 512-D feature vector.
        """
        # Shape trace: [Batch_Size, 1264]
        
        # 1. Map input to shared 512-D attribute embedding space
        x_shared = self.shared_linear(x)
        # Shape trace: [Batch_Size, 1264] -> [Batch_Size, 512]
        
        attribute_embedding = self.shared_relu(x_shared)
        # Shape trace: [Batch_Size, 512] -> [Batch_Size, 512] (Exposed as es)
        
        # 2. Multi-Task Classification Branches
        style_logits = self.style_head(attribute_embedding)
        # Shape trace: [Batch_Size, 512] -> [Batch_Size, 20]
        
        composition_logits = self.composition_head(attribute_embedding)
        # Shape trace: [Batch_Size, 512] -> [Batch_Size, 9]
        
        return style_logits, composition_logits, attribute_embedding

if __name__ == "__main__":
    # Diagnostic instantiation and shape verification block
    print("Testing AttributeNet MLP architecture...")
    model = AttributeNet(input_dim=1264, embed_dim=512, num_style=20, num_composition=9)
    
    # Input tensor representing a batch of 4 MLSP feature vectors
    dummy_input = torch.randn(4, 1264) # Shape: [4, 1264]
    
    style_logits, comp_logits, attr_embed = model(dummy_input)
    
    print(f"Input shape:                {list(dummy_input.shape)}")
    print(f"Style Logits shape:         {list(style_logits.shape)}")   # Expected: [4, 20]
    print(f"Composition Logits shape:   {list(comp_logits.shape)}")   # Expected: [4, 9]
    print(f"Attribute Embedding shape:  {list(attr_embed.shape)}")    # Expected: [4, 512]
    
    assert style_logits.shape == (4, 20), "Error: Style logits shape mismatch."
    assert comp_logits.shape == (4, 9), "Error: Composition logits shape mismatch."
    assert attr_embed.shape == (4, 512), "Error: Attribute embedding shape mismatch."
    
    print("AttributeNet verification passed successfully!")
