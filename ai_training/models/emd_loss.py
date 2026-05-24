import torch
import torch.nn as nn

class EMDLoss(nn.Module):
    """
    Earth Mover's Distance (EMD) Custom Loss Module for Ordered Probability Distributions.
    
    The loss calculates the difference between the Cumulative Distribution Functions (CDFs) 
    of the predicted aesthetic score distribution and the ground-truth distribution.
    
    Mathematical formulation:
        EMD(q_hat, q) = ( 1/N * sum_{k=1..N} | CDF_q_hat(k) - CDF_q(k) |^r )^(1/r)
        
    We set r=2 (squared EMD) to severely penalize massive rating shifts in ordinal space
    (e.g., misclassifying a high-quality aesthetic image to a low-quality bin).
    """
    def __init__(self, r=2, reduction='mean'):
        super(EMDLoss, self).__init__()
        self.r = r
        self.reduction = reduction
        
    def forward(self, y_pred, y_true):
        """
        Forward pass for the EMD Loss calculation.
        
        Args:
            y_pred (torch.Tensor): Softmax probability distribution predictions of shape [Batch_Size, N].
            y_true (torch.Tensor): Ground-truth target distribution of shape [Batch_Size, N].
                                   Must sum to 1.0 along the bin dimension.
                                   
        Returns:
            torch.Tensor: Computed scalar EMD loss (if reduction is 'mean' or 'sum').
        """
        # Shape trace: y_pred: [Batch_Size, N], y_true: [Batch_Size, N]
        # where N is the number of ordinal buckets (e.g., 10 for the AVA dataset).
        
        # 1. Compute cumulative sums along the final dimension to derive Cumulative Distribution Functions (CDFs)
        cdf_pred = torch.cumsum(y_pred, dim=-1)
        # Shape trace: [Batch_Size, N] -> [Batch_Size, N] (CDF monotonically increases to 1.0)
        
        cdf_true = torch.cumsum(y_true, dim=-1)
        # Shape trace: [Batch_Size, N] -> [Batch_Size, N]
        
        # 2. Compute absolute difference between predicted and actual CDFs
        abs_diff = torch.abs(cdf_pred - cdf_true)
        # Shape trace: [Batch_Size, N] -> [Batch_Size, N]
        
        # 3. Raise the difference to the power of r (specifically r=2)
        powered_diff = torch.pow(abs_diff, self.r)
        # Shape trace: [Batch_Size, N] -> [Batch_Size, N]
        
        # 4. Compute the mean along the ordinal buckets dimension (1/N coefficient)
        mean_diff = torch.mean(powered_diff, dim=-1)
        # Shape trace: [Batch_Size, N] -> [Batch_Size]
        
        # 5. Apply the r-th root to the final average distance mapping
        eps = 1e-7 # Prevent division-by-zero gradients near zero differences
        emd_per_sample = torch.pow(mean_diff + eps, 1.0 / self.r)
        # Shape trace: [Batch_Size] -> [Batch_Size]
        
        # 6. Apply target tensor reduction
        if self.reduction == 'mean':
            return torch.mean(emd_per_sample)
        elif self.reduction == 'sum':
            return torch.sum(emd_per_sample)
        else:
            return emd_per_sample

if __name__ == "__main__":
    # Diagnostic instantiation and backpropagation tracking test
    print("Testing EMD Loss Module (r=2)...")
    loss_fn = EMDLoss(r=2, reduction='mean')
    
    # Mock data: Batch of 2 samples, 10 rating bins each
    # Ensure they are valid probabilities (sum to 1.0)
    y_pred = torch.softmax(torch.randn(2, 10, requires_grad=True), dim=-1)
    y_true = torch.softmax(torch.randn(2, 10), dim=-1)
    
    loss = loss_fn(y_pred, y_true)
    print(f"y_pred:  {y_pred.detach().numpy().round(3)}")
    print(f"y_true:  {y_true.numpy().round(3)}")
    print(f"Calculated EMD Loss: {loss.item():.6f}")
    
    # Validate autograd backpropagation tracking
    loss.backward()
    print("Grad calculations successful! y_pred.grad is populated:")
    print(y_pred.grad.numpy().round(4))
    
    assert y_pred.grad is not None, "Error: Backward pass failed, gradient is not populated."
    print("EMD Loss verification passed successfully!")
