import os
import sys
import argparse
import pickle
import numpy as np
from PIL import Image
import torch
from torch.utils.data import Dataset, DataLoader
from torchvision import transforms

# Resolve project path to import models properly
current_dir = os.path.dirname(os.path.abspath(__file__))
project_root = os.path.dirname(current_dir)
sys.path.append(project_root)

from models.mlsp_backbone import MLSP_EfficientNetB4

class AestheticImageDataset(Dataset):
    """
    Production-ready PyTorch Dataset for loading aesthetic raw images.
    Applies standard ImageNet normalization and resizes to 224x224.
    """
    def __init__(self, data_dir, transform=None):
        self.data_dir = data_dir
        self.transform = transform
        
        # Filter for standard image formats
        valid_extensions = ('.png', '.jpg', '.jpeg', '.webp', '.bmp')
        if os.path.exists(data_dir):
            self.filenames = [
                f for f in os.listdir(data_dir) 
                if f.lower().endswith(valid_extensions)
            ]
        else:
            self.filenames = []
            
    def __len__(self):
        return len(self.filenames)
        
    def __getitem__(self, idx):
        filename = self.filenames[idx]
        img_path = os.path.join(self.data_dir, filename)
        
        try:
            image = Image.open(img_path).convert('RGB')
        except Exception as e:
            # Fallback to an empty/black image if file is corrupted
            print(f"Warning: Failed to load {filename} ({e}). Substituting black canvas.")
            image = Image.new('RGB', (224, 224))
            
        if self.transform:
            image = self.transform(image)
            # Shape trace: [3, H, W] -> [3, 224, 224]
            
        return image, filename


def generate_synthetic_images(target_dir, count=10):
    """
    Generates synthetic dummy images for out-of-the-box local testing.
    """
    os.makedirs(target_dir, exist_ok=True)
    print(f"Creating {count} synthetic test images in '{target_dir}'...")
    for idx in range(count):
        # Create a random RGB color image
        arr = np.random.randint(0, 256, (224, 224, 3), dtype=np.uint8)
        img = Image.fromarray(arr)
        img.save(os.path.join(target_dir, f"mock_image_{idx:03d}.jpg"))
    print("Synthetic test images created successfully.")


def extract_features(data_dir, output_file, batch_size, device):
    """
    Runs feature extraction loop on image directory and caches 1264-D vectors.
    """
    print(f"Setting up feature extraction...")
    print(f"  Source directory: {data_dir}")
    print(f"  Target cache:     {output_file}")
    print(f"  Device:           {device}")
    
    # Define standard transforms matching PyTorch ImageNet standards
    transform = transforms.Compose([
        transforms.Resize((224, 224)),
        transforms.ToTensor(),
        transforms.Normalize(
            mean=[0.485, 0.456, 0.406], 
            std=[0.229, 0.224, 0.225]
        )
    ])
    
    dataset = AestheticImageDataset(data_dir, transform=transform)
    
    if len(dataset) == 0:
        print("Error: Target directory is empty or does not exist!")
        return False
        
    loader = DataLoader(
        dataset, 
        batch_size=batch_size, 
        shuffle=False, 
        num_workers=0
    )
    
    # Instantiate MLSP Extractor
    model = MLSP_EfficientNetB4()
    model.to(device)
    model.eval()
    
    cached_features = []
    cached_filenames = []
    
    print(f"Beginning feature extraction on {len(dataset)} images...")
    with torch.no_grad():
        for batch_idx, (images, filenames) in enumerate(loader):
            # Input Shape trace: [Batch_Size, 3, 224, 224]
            images = images.to(device)
            
            # Forward pass: shape trace: [Batch_Size, 3, 224, 224] -> [Batch_Size, 1264]
            features = model(images)
            
            cached_features.append(features.cpu().numpy())
            cached_filenames.extend(filenames)
            
            print(f"  Processed batch {batch_idx + 1}/{len(loader)} ({(batch_idx + 1) * batch_size} images)")
            
    # Concatenate all batches into a single numpy matrix
    all_features = np.vstack(cached_features)
    # Shape trace: [Total_Images, 1264]
    
    # Generate mock labels for multi-task aesthetic and compositional attributes
    # In production, these are loaded from annotations (e.g. FlickrStyle and KU-PCP labels)
    num_samples = len(cached_filenames)
    
    # 20 FlickrStyle classes (represented as mutually-exclusive integer index)
    style_labels = np.random.randint(0, 20, size=(num_samples,), dtype=np.int64)
    
    # 9 KU-PCP composition labels (represented as multi-label binary float values 0.0 or 1.0)
    composition_labels = np.random.choice([0.0, 1.0], size=(num_samples, 9)).astype(np.float32)
    
    # 10 AVA score rating bins (represented as Softmax probability distribution summing to 1.0)
    raw_ratings = np.random.exponential(scale=1.0, size=(num_samples, 10)).astype(np.float32)
    aesthetic_labels = raw_ratings / raw_ratings.sum(axis=1, keepdims=True)
    
    # Write directly to disk
    # We attempt using HDF5 first (as specified by the h5py blueprint).
    # If h5py is not installed or errors, we fall back to a standard Python pickle binary format.
    try:
        import h5py
        print("Writing features using HDF5 container...")
        with h5py.File(output_file, 'w') as h5f:
            h5f.create_dataset('features', data=all_features)
            h5f.create_dataset('filenames', data=np.array(cached_filenames, dtype='S'))
            h5f.create_dataset('style_labels', data=style_labels)
            h5f.create_dataset('composition_labels', data=composition_labels)
            h5f.create_dataset('aesthetic_labels', data=aesthetic_labels)
        print("HDF5 feature cache written successfully!")
    except ImportError:
        print("h5py not installed. Falling back to Python pickle format...")
        cache_data = {
            'features': all_features,
            'filenames': cached_filenames,
            'style_labels': style_labels,
            'composition_labels': composition_labels,
            'aesthetic_labels': aesthetic_labels
        }
        with open(output_file, 'wb') as f:
            pickle.dump(cache_data, f, protocol=pickle.HIGHEST_PROTOCOL)
        print("Pickle feature cache written successfully!")
        
    return True


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Cache MLSP feature embeddings to protect server RAM.")
    parser.add_argument('--data_dir', type=str, default='dataset/images', help="Path to raw image directory")
    parser.add_argument('--output_file', type=str, default='mlsp_features.h5', help="Output cache file path")
    parser.add_argument('--batch_size', type=int, default=4, help="Batch size for feature extractor")
    parser.add_argument('--device', type=str, default='auto', help="Device to execute backbone on")
    parser.add_argument('--generate_mock', action='store_true', default=True, help="Auto-generate synthetic mock images for local testing")
    
    args = parser.parse_args()
    
    # Auto-detect target execution hardware
    if args.device == 'auto':
        target_device = torch.device('cuda' if torch.cuda.is_available() else 'cpu')
    else:
        target_device = torch.device(args.device)
        
    # Check if image folder is missing and generate mock data if flag is enabled
    if not os.path.exists(args.data_dir) or len(os.listdir(args.data_dir)) == 0:
        if args.generate_mock:
            generate_synthetic_images(args.data_dir, count=8)
        else:
            print(f"Error: Target directory '{args.data_dir}' is empty or missing. Enable --generate_mock.")
            sys.exit(1)
            
    # Run the feature caching script
    success = extract_features(
        data_dir=args.data_dir,
        output_file=args.output_file,
        batch_size=args.batch_size,
        device=target_device
    )
    
    if success:
        print("Feature extraction pipeline execution finished successfully.")
    else:
        print("Feature extraction pipeline failed.")
