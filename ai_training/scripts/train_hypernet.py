import os
import sys
import argparse
import numpy as np
import torch
import torch.nn as nn
import torch.optim as optim
from torch.utils.data import TensorDataset, DataLoader

# Resolve project path to import models properly
current_dir = os.path.dirname(os.path.abspath(__file__))
project_root = os.path.dirname(current_dir)
sys.path.append(project_root)

from models.attribute_net import AttributeNet
from models.hyper_aesthetic import HyperNetwork, AestheticNet
# Try standard import, fallback to package style if needed
try:
    from models.emd_loss import EMDLoss
except ImportError:
    try:
        from models.emd_loss.emd_loss import EMDLoss
    except ImportError:
        # Fallback when running from scripts folder directly
        sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
        from models.emd_loss import EMDLoss


def load_cached_features(feature_file):
    """
    Loads features and multi-task labels from HDF5 cache or Pickle cache.
    Returns PyTorch Tensors.
    """
    if not os.path.exists(feature_file):
        print(f"Warning: Cache file '{feature_file}' not found.")
        return None
        
    print(f"Loading cached feature vectors from '{feature_file}'...")
    try:
        import h5py
        with h5py.File(feature_file, 'r') as h5f:
            features = torch.tensor(np.array(h5f['features']), dtype=torch.float32)
            style_labels = torch.tensor(np.array(h5f['style_labels']), dtype=torch.long)
            composition_labels = torch.tensor(np.array(h5f['composition_labels']), dtype=torch.float32)
            aesthetic_labels = torch.tensor(np.array(h5f['aesthetic_labels']), dtype=torch.float32)
        print("HDF5 feature vector loading complete.")
        return features, style_labels, composition_labels, aesthetic_labels
    except Exception as e:
        print(f"HDF5 read failed ({e}). Attempting pickle loading...")
        try:
            import pickle
            with open(feature_file, 'rb') as f:
                data = pickle.load(f)
            features = torch.tensor(data['features'], dtype=torch.float32)
            # Handle filename and string array types if necessary
            style_labels = torch.tensor(data['style_labels'], dtype=torch.long)
            composition_labels = torch.tensor(data['composition_labels'], dtype=torch.float32)
            aesthetic_labels = torch.tensor(data['aesthetic_labels'], dtype=torch.float32)
            print("Pickle feature vector loading complete.")
            return features, style_labels, composition_labels, aesthetic_labels
        except Exception as ex:
            print(f"Error: Failed to load feature file ({ex}).")
            return None


def generate_colab_mock_tensors(num_samples=128):
    """
    Google Colab & test runner entry point.
    Generates mock tensors of feature cache to enable instant, out-of-the-box pipeline runs.
    """
    print(f"Initializing {num_samples} synthetic tensors for instant Google Colab/local test...")
    
    # 1. 1264-D MLSP backbone scene embeddings
    features = torch.randn(num_samples, 1264, dtype=torch.float32)
    # Shape trace: [num_samples, 1264]
    
    # 2. Mutually exclusive style labels (20 classes)
    style_labels = torch.randint(0, 20, (num_samples,), dtype=torch.long)
    # Shape trace: [num_samples]
    
    # 3. Multi-label composition tags (9 classes, non-mutually exclusive)
    composition_labels = torch.randint(0, 2, (num_samples, 9), dtype=torch.float32)
    # Shape trace: [num_samples, 9]
    
    # 4. Ordinal aesthetic distribution targets (10 AVA rating bins)
    # Generated using Dirichlet or normalized exponential distribution to mimic rating density
    raw_ratings = torch.exp(torch.randn(num_samples, 10))
    aesthetic_labels = raw_ratings / raw_ratings.sum(dim=-1, keepdim=True)
    # Shape trace: [num_samples, 10] (Every row sums to 1.0)
    
    print("Synthetic mock tensors initialized successfully.")
    return features, style_labels, composition_labels, aesthetic_labels


def train_pipeline(feature_file, batch_size, epochs_phase1, epochs_phase2, device):
    """
    Dual-Phase Joint Aesthetic Training Pipeline.
    """
    # 1. Acquire datasets (either load from cached binary files or generate synthetic fallbacks)
    data = load_cached_features(feature_file)
    if data is None:
        print("Feature cache not available. Falling back to synthetic mock data generator.")
        features, style_labels, comp_labels, aesthetic_labels = generate_colab_mock_tensors()
    else:
        features, style_labels, comp_labels, aesthetic_labels = data
        
    dataset = TensorDataset(features, style_labels, comp_labels, aesthetic_labels)
    loader = DataLoader(dataset, batch_size=batch_size, shuffle=True)
    
    print(f"Data source ready. Total sample size: {len(dataset)}")
    
    # 2. Instantiate all model architectures
    attribute_net = AttributeNet(input_dim=1264, embed_dim=512, num_style=20, num_composition=9).to(device)
    hyper_net = HyperNetwork(embed_dim=512, bottleneck_dim=16).to(device)
    aesthetic_net = AestheticNet().to(device)
    
    # ----------------------------------------------------
    # PHASE 1: Attribute Learning (Multi-Task Supervision)
    # ----------------------------------------------------
    print("\n" + "="*50)
    print("PHASE 1: TRAINING ATTRIBUTENET (MULTI-TASK REPRESENTATION)")
    print("="*50)
    
    style_loss_fn = nn.CrossEntropyLoss()
    comp_loss_fn = nn.BCEWithLogitsLoss()
    
    optimizer_phase1 = optim.Adam(attribute_net.parameters(), lr=1e-3, weight_decay=1e-5)
    
    attribute_net.train()
    for epoch in range(epochs_phase1):
        epoch_loss = 0.0
        style_losses = 0.0
        comp_losses = 0.0
        
        for step, (feat, style_tgt, comp_tgt, _) in enumerate(loader):
            feat, style_tgt, comp_tgt = feat.to(device), style_tgt.to(device), comp_tgt.to(device)
            # Shape trace: feat: [B, 1264], style_tgt: [B], comp_tgt: [B, 9]
            
            optimizer_phase1.zero_grad()
            
            # Forward pass: shape trace: [B, 1264] -> style_log: [B, 20], comp_log: [B, 9], attr_emb: [B, 512]
            style_logits, comp_logits, _ = attribute_net(feat)
            
            # Compute multi-task losses
            style_loss = style_loss_fn(style_logits, style_tgt) # FlickrStyle CE
            comp_loss = comp_loss_fn(comp_logits, comp_tgt)     # KU-PCP BCE
            
            # Combined Loss Equation: L_attr = 1.0 * L_style + 10.0 * L_composition
            alpha_v, alpha_c = 1.0, 10.0
            total_loss = alpha_v * style_loss + alpha_c * comp_loss
            
            total_loss.backward()
            optimizer_phase1.step()
            
            epoch_loss += total_loss.item()
            style_losses += style_loss.item()
            comp_losses += comp_loss.item()
            
        avg_loss = epoch_loss / len(loader)
        avg_style = style_losses / len(loader)
        avg_comp = comp_losses / len(loader)
        print(f"Epoch [{epoch+1:02d}/{epochs_phase1:02d}] - Loss: {avg_loss:.4f} (Style: {avg_style:.4f}, Comp: {avg_comp:.4f})")
        
    # Freeze AttributeNet permanently on convergence of Phase 1
    print("Phase 1 complete! Freezing AttributeNet permanently.")
    for param in attribute_net.parameters():
        param.requires_grad = False
    attribute_net.eval()
    
    # ----------------------------------------------------
    # PHASE 2: Aesthetic Optimization (Hypernetwork Joint Optimization)
    # ----------------------------------------------------
    print("\n" + "="*50)
    print("PHASE 2: TRAINING HYPERNETWORK (DYNAMIC AESTHETIC GRADING)")
    print("="*50)
    
    emd_loss_fn = EMDLoss(r=2, reduction='mean')
    optimizer_phase2 = optim.Adam(hyper_net.parameters(), lr=5e-4, weight_decay=1e-5)
    
    hyper_net.train()
    for epoch in range(epochs_phase2):
        epoch_loss = 0.0
        
        for step, (feat, _, _, aes_tgt) in enumerate(loader):
            feat, aes_tgt = feat.to(device), aes_tgt.to(device)
            # Shape trace: feat: [B, 1264], aes_tgt: [B, 10]
            
            optimizer_phase2.zero_grad()
            
            # 1. Compute attribute embedding using frozen AttributeNet (No Grads tracked for AttributeNet)
            with torch.no_grad():
                _, _, attribute_embeddings = attribute_net(feat)
                # Shape trace: [B, 1264] -> [B, 512]
                
            # 2. Forward pass through Hypernetwork to dynamically predict downstream weights and biases
            weights_dict = hyper_net(attribute_embeddings)
            # Shapes dynamically mapped per block inside Hypernetwork
            
            # 3. Dynamic evaluation pass through AestheticNet
            aesthetic_preds = aesthetic_net(feat, weights_dict)
            # Shape trace: feat: [B, 1264], weights: dynamic -> predictions: [B, 10]
            
            # 4. Custom Earth Mover's Distance calculation
            loss = emd_loss_fn(aesthetic_preds, aes_tgt)
            
            loss.backward()
            optimizer_phase2.step()
            
            epoch_loss += loss.item()
            
        avg_loss = epoch_loss / len(loader)
        print(f"Epoch [{epoch+1:02d}/{epochs_phase2:02d}] - EMD Loss: {avg_loss:.6f}")
        
    print("\nJoint aesthetic and compositional training workflow finished successfully.")
    
    # Return trained instances for downstream tasks or ONNX serialization
    return attribute_net, hyper_net, aesthetic_net


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="X-Aesthetic Joint Multi-Task Hypernetwork Training Pipeline.")
    parser.add_argument('--feature_file', type=str, default='mlsp_features.h5', help="Path to cached feature HDF5 file")
    parser.add_argument('--batch_size', type=int, default=8, help="Batch size for training")
    parser.add_argument('--epochs_p1', type=int, default=3, help="Training epochs for AttributeNet (Phase 1)")
    parser.add_argument('--epochs_p2', type=int, default=5, help="Training epochs for HyperNetwork (Phase 2)")
    parser.add_argument('--device', type=str, default='auto', help="Target device (cpu or cuda)")
    
    args = parser.parse_args()
    
    if args.device == 'auto':
        target_device = torch.device('cuda' if torch.cuda.is_available() else 'cpu')
    else:
        target_device = torch.device(args.device)
        
    print(f"Running joint training pipeline on: {target_device}")
    
    train_pipeline(
        feature_file=args.feature_file,
        batch_size=args.batch_size,
        epochs_phase1=args.epochs_p1,
        epochs_phase2=args.epochs_p2,
        device=target_device
    )
