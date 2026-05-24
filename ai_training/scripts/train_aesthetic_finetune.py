import os
import sys
import argparse
import numpy as np
import torch
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
        from models.emd_loss import EMDLoss
    except ImportError:
        sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
        from models.emd_loss import EMDLoss


def _normalize_distribution(labels, eps=1e-8):
    labels = np.clip(labels, 0.0, None)
    sums = labels.sum(axis=1, keepdims=True)
    if np.any(sums < eps):
        raise ValueError("Found distribution rows with near-zero sums.")
    return labels / sums


def _load_aesthetic_cache(cache_path, num_bins):
    if not os.path.exists(cache_path):
        raise FileNotFoundError(f"Cache file not found: {cache_path}")

    features = None
    labels = None

    try:
        import h5py
        with h5py.File(cache_path, "r") as h5f:
            features = np.array(h5f["features"], dtype=np.float32)
            labels = np.array(h5f["aesthetic_labels"], dtype=np.float32)
    except Exception:
        import pickle
        with open(cache_path, "rb") as f:
            data = pickle.load(f)
        features = np.array(data["features"], dtype=np.float32)
        labels = np.array(data["aesthetic_labels"], dtype=np.float32)

    if labels.ndim != 2 or labels.shape[1] != num_bins:
        raise ValueError(f"Expected aesthetic_labels shape [N, {num_bins}]. Got {labels.shape}.")

    if not np.allclose(labels.sum(axis=1), 1.0, atol=1e-3):
        labels = _normalize_distribution(labels)

    features_tensor = torch.tensor(features, dtype=torch.float32)
    labels_tensor = torch.tensor(labels, dtype=torch.float32)

    return features_tensor, labels_tensor


def _build_loader(features, labels, batch_size, shuffle=True):
    dataset = TensorDataset(features, labels)
    return DataLoader(dataset, batch_size=batch_size, shuffle=shuffle)


def _load_attribute_net(checkpoint_path, device):
    model = AttributeNet(input_dim=1264, embed_dim=512, num_style=20, num_composition=9).to(device)
    if not checkpoint_path:
        print("Warning: attribute checkpoint not provided. Using random initialization.")
        return model

    if not os.path.exists(checkpoint_path):
        raise FileNotFoundError(f"Attribute checkpoint not found: {checkpoint_path}")

    ckpt = torch.load(checkpoint_path, map_location=device)
    state_dict = ckpt.get("attribute_net", ckpt)
    model.load_state_dict(state_dict)
    print(f"Loaded AttributeNet weights from: {checkpoint_path}")
    return model


def _train_aesthetic_phase(
    features,
    labels,
    attribute_net,
    hyper_net,
    aesthetic_net,
    device,
    epochs,
    batch_size,
    lr,
    weight_decay=1e-5,
):
    data_loader = _build_loader(features, labels, batch_size, shuffle=True)
    emd_loss_fn = EMDLoss(r=2, reduction="mean")
    optimizer = optim.Adam(hyper_net.parameters(), lr=lr, weight_decay=weight_decay)

    attribute_net.eval()
    hyper_net.train()

    for epoch in range(epochs):
        epoch_loss = 0.0
        for feat, aes_tgt in data_loader:
            feat = feat.to(device)
            aes_tgt = aes_tgt.to(device)

            optimizer.zero_grad()
            with torch.no_grad():
                _, _, attr_embed = attribute_net(feat)

            weights_dict = hyper_net(attr_embed)
            preds = aesthetic_net(feat, weights_dict)
            loss = emd_loss_fn(preds, aes_tgt)

            loss.backward()
            optimizer.step()

            epoch_loss += loss.item()

        avg_loss = epoch_loss / len(data_loader)
        print(f"Epoch [{epoch + 1:02d}/{epochs:02d}] - EMD Loss: {avg_loss:.6f}")


def _save_checkpoint(output_path, hyper_net, meta):
    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    torch.save({"hyper_net": hyper_net.state_dict(), "meta": meta}, output_path)
    print(f"Saved checkpoint: {output_path}")


def main():
    parser = argparse.ArgumentParser(
        description="Pretrain on AVA then fine-tune on AADB using EMD distribution loss."
    )
    parser.add_argument("--ava_cache", type=str, required=True, help="HDF5/Pickle cache for AVA")
    parser.add_argument("--aadb_cache", type=str, required=True, help="HDF5/Pickle cache for AADB")
    parser.add_argument("--attribute_ckpt", type=str, default="", help="AttributeNet checkpoint path")
    parser.add_argument("--out_dir", type=str, default="outputs", help="Output directory for checkpoints")
    parser.add_argument("--batch_size", type=int, default=32, help="Batch size for training")
    parser.add_argument("--epochs_pretrain", type=int, default=5, help="Epochs for AVA pretrain")
    parser.add_argument("--epochs_finetune", type=int, default=3, help="Epochs for AADB fine-tune")
    parser.add_argument("--lr_pretrain", type=float, default=5e-4, help="Learning rate for AVA pretrain")
    parser.add_argument("--lr_finetune", type=float, default=1e-4, help="Learning rate for AADB fine-tune")
    parser.add_argument("--num_bins", type=int, default=10, help="Number of rating bins")
    parser.add_argument("--device", type=str, default="auto", help="Target device (cpu or cuda)")

    args = parser.parse_args()

    if args.device == "auto":
        device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    else:
        device = torch.device(args.device)

    print(f"Running AVA -> AADB pipeline on: {device}")

    attribute_net = _load_attribute_net(args.attribute_ckpt, device)
    for param in attribute_net.parameters():
        param.requires_grad = False

    hyper_net = HyperNetwork(embed_dim=512, bottleneck_dim=16).to(device)
    aesthetic_net = AestheticNet().to(device)

    print("Loading AVA cache...")
    ava_features, ava_labels = _load_aesthetic_cache(args.ava_cache, args.num_bins)
    print(f"AVA samples: {ava_features.shape[0]}")

    print("\nPretraining on AVA...")
    _train_aesthetic_phase(
        ava_features,
        ava_labels,
        attribute_net,
        hyper_net,
        aesthetic_net,
        device,
        args.epochs_pretrain,
        args.batch_size,
        args.lr_pretrain,
    )

    pretrain_ckpt = os.path.join(args.out_dir, "hypernet_pretrained_ava.pt")
    _save_checkpoint(
        pretrain_ckpt,
        hyper_net,
        {
            "stage": "pretrain",
            "dataset": "AVA",
            "num_bins": args.num_bins,
            "epochs": args.epochs_pretrain,
            "lr": args.lr_pretrain,
        },
    )

    print("\nLoading AADB cache...")
    aadb_features, aadb_labels = _load_aesthetic_cache(args.aadb_cache, args.num_bins)
    print(f"AADB samples: {aadb_features.shape[0]}")

    print("\nFine-tuning on AADB...")
    _train_aesthetic_phase(
        aadb_features,
        aadb_labels,
        attribute_net,
        hyper_net,
        aesthetic_net,
        device,
        args.epochs_finetune,
        args.batch_size,
        args.lr_finetune,
    )

    finetune_ckpt = os.path.join(args.out_dir, "hypernet_finetuned_aadb.pt")
    _save_checkpoint(
        finetune_ckpt,
        hyper_net,
        {
            "stage": "finetune",
            "dataset": "AADB",
            "num_bins": args.num_bins,
            "epochs": args.epochs_finetune,
            "lr": args.lr_finetune,
        },
    )


if __name__ == "__main__":
    main()
